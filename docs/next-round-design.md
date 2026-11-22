# tprompt — Next-Round Feature Design Proposal (v3, post-review-2)

- **Base version:** tprompt 0.2.0
- **Scope:** 15 feature specifications + a readline-wrappers research section
- **Date:** November 22, 2026
- **Status:** design document — no implementation

This is the third pass. It applies three corrections from the second review and a readability overhaul throughout. The corrections are: the `qr:` regex is detected by prefix at any position (not fixed to the fourth field); `--preview` is a per-spec C key, not a global flag; and the §4 rlwrap recommendations are accepted. Every section's prose has also been broken into short paragraphs and bullet lists so a human can read it.

---

## 1. Introduction and scope

This document specifies the next round of tprompt features. Each kept feature is expanded into four parts — **Explanation**, **Examples / use cases**, **Command line**, and **Design proposal** — covering syntax, precedence, edge cases, and portability. No code is written in this round; this is the spec the next implementation pass will build from.

The base is tprompt 0.2.0. It already provides:

- the two spec forms (B positional and C stdin);
- the six-field internal record (name, prompt, default, values, secret, multi);
- the picker tiers (fzf, numbered, external);
- the render modes (in-shell, popup);
- environment expansion.

The three 0.2.0 features are already in place: secret input via a leading `*` on the name, the `--color` on/off/auto switch with a hardcoded bold-cyan label and dim-yellow default, and multi-value selection with `--multi` and `--sep`. Every feature below extends that base.

## 2. How to read this document

Each feature is a numbered subsection with four labeled parts. The **Command line** part is a fenced block showing the option in context, including the B positional form and the C stdin form where they differ. The **Design proposal** states the syntax precisely, then the order of operations, the edge cases, and any portability caveat.

A few conventions worth knowing up front:

- **B form** is the terse positional form: `name|prompt|default[|values]`, with prefix markers on the name (`*` secret, `!` required, `@` editor) and prefix-detected fields (`qr:` for a regex, `pv:` for a preview command).
- **C form** is the multi-line stdin form, one `key=value` per line, used when a field needs shell-special characters or per-spec options the B form cannot carry.
- **Precedence** for the value, in order: a typed or scripted answer wins; then the loaded value (from `--load`); then the spec `default` (which already includes env expansion).

Section 3 records the review decisions so the change history is visible. Section 4 is the readline-wrappers research and feeds the `--history` design in §11.1. Section 12 lists the features rejected in review, with rationale; section 13 lists what stays deferred.

## 3. Review decisions

This is the third pass. The v1→v2 decisions (six removals, five refinements, one research addition) stand and are recorded in the table below. The v2→v3 changes from the second review are three corrections plus the readability overhaul.

**v2 → v3 changes:**

- **`qr:` regex is position-independent (§6.1).** It is detected by prefix at any field position, not fixed to the fourth field. A spec can now carry both a values list and a regex.
- **`preview` is a per-spec attribute (§7.1), not a global flag.** It is only relevant to a values-list input, so it belongs on the spec. It is set in the B form with a `pv:`-prefixed command (position-independent, parallel to `qr:`) and in the C form with a `preview=<cmd>` key.
- **§4 rlwrap recommendations accepted.** The fzf-primary + rlwrap-optional plan is confirmed for `--history` (§11.1).
- **Readability overhaul.** Every Explanation and Design proposal has been broken into short paragraphs and bullet lists.

**v1 → v2 decisions (stand):**

| v1 feature | Decision | Change |
|---|---|---|
| Color (configurable) | Kept | — |
| `--validate <regex>` | Refined | + per-entry B-form regex via `qr:` prefix |
| `required=1` | Kept | — |
| `type=number` with `min`/`max` | **Removed** | "regexp is enough" |
| `--retry <n>` | Kept | composition shrinks to `--validate` + `required` |
| `--confirm` + `--mask-char` | **Removed** | "caller prompts twice and compares" |
| `--sort` / `--no-sort` | **Removed** | "caller sorts the list" |
| `default-first` | **Removed** | "caller puts default first" |
| `--preview <cmd>` | Kept | (v3: per-spec B `pv:` / C `preview=`, not a global flag) |
| `--header` / `--header-file` | Kept | — |
| `--json` output | Kept | — |
| `--save` / `--load` | Refined | missing-load no-op; missing-save create; non-writable-save error |
| `--timeout <s>` | Kept | — |
| `--dry-run` | **Removed** | — |
| `--specs-from <file>` | Kept | — |
| `--editor` spec type | Refined | B form via `@`; default can be a `file:` path |
| `--multiline` | Kept | — |
| `--width` / `--height` | Kept | — |
| `--trim` / `--no-trim` | Kept | drop the `type` reference |
| `--history <file>` | Refined | manual Ctrl-R; fzf primary, rlwrap optional |
| `if-empty=<value>` | **Removed** | — |
| (new) readline-wrappers research | **Added** | §4 |

## 4. Readline wrappers — research

This section answers the review's opening request: investigate rlwrap and list other readline wrappers or readline-like libraries that could enhance tprompt's UX, then recommend a fit.

### 4.1 What rlwrap is

rlwrap is a wrapper that uses the GNU Readline library to add comfortable line editing, persistent history, and completion to any command's keyboard input. It runs the specified command in a pseudo-terminal and intercepts user input to provide readline's editing — cursor movement, word kill, bracketed paste — plus persistent history with Up/Down recall, Ctrl-R reverse incremental search, and filename completion.

The options that matter for tprompt:

- `-H, --history-filename FILE` — persist history to a file.
- `-s, --histsize N` — cap the list (default 300).
- `--history-no-dupes N` — skip consecutive duplicates.
- `--remember` — append new input to the history file on exit.

Because rlwrap pty-wraps the command, it works regardless of the shell the wrapped command is written in. It is an external binary, not a shell builtin — which is exactly what makes it attractive for a POSIX-shell tool like tprompt.

Sources: [rlwrap on GitHub (hanslub42/rlwrap)](https://github.com/hanslub42/rlwrap), [rlwrap(1) manual](https://man.archlinux.org/man/rlwrap.1.en), [rlwrap — Vishnu Bharathi](https://vishnubharathi.codes/blog/rlwrap), [rlwrap on oracle-base](https://oracle-base.com/articles/linux/rlwrap).

### 4.2 Why wrapping tprompt whole does not fit

The obvious idea is `rlwrap tprompt ...`. It does not map cleanly, for one reason: rlwrap maintains a single history stream for the whole wrapped session.

tprompt prompts for many distinct fields — host, port, env, and so on. A single shared history means Up-arrow on the "port" prompt would recall the "host" answer. rlwrap has no notion of segmenting history by prompt, so the per-field recall the user expects is lost. tprompt's own per-field history (the `--history` design in §11.1) is the right segmentation, and wrapping the whole command throws it away.

### 4.3 How rlwrap could fit: as a backend for a single read

Instead of wrapping the whole command, tprompt can shell out to rlwrap for one free-text input at a time. tprompt spawns `rlwrap -H <field-history-file> -s 100 --history-no-dupes 1 --remember` around a small `sh -c` that prints tprompt's prompt, reads one line, and prints the value back for tprompt to capture.

This delegates line editing, Ctrl-R, Up/Down, and persisted history to rlwrap for that one field. tprompt controls the history file, so segmentation stays per-field. It works under any POSIX shell (rlwrap is external) and sidesteps the bash-only `read -e` problem.

The cost is a new optional runtime dependency and a process spawn per input. That is why it is the secondary path, not the primary one.

### 4.4 The wider landscape

Beyond rlwrap, the tools fall into three groups.

**Readline wrappers** (wrap a command's stdin):

- `rlwrap` — the canonical wrapper; described above.
- `ledit` — an older OCaml-based wrapper with similar goals; less actively maintained.
- `PyRlwrap` — a minimal Python clone; barely maintained.

**Shell-history search tools** (replace the shell's own Ctrl-R; not wrappers for arbitrary commands):

- `fzf` — a fuzzy finder whose key-bindings replace the shell's Ctrl-R with a fuzzy history picker. tprompt already depends on fzf for value-lists.
- `atuin` — SQLite-backed shell history that replaces Ctrl-R and syncs across machines.
- `mcfly` — a full-screen Ctrl-R replacement that ranks by recency and working directory.
- `hstr` (`hh`) — a history "suggest box" ranked by frequency.
- `Suvadu` — a newer entrant in the same space.

These hook the shell's command-line history, not a script's `read` calls, so they cannot serve tprompt's per-field prompts directly — but they illustrate the recall UX tprompt could emulate. Source: ["Better Shell History Search" discussion on Hacker News](https://news.ycombinator.com/item?id=43476793).

**Readline-alternative libraries** (embedded in a program; not usable from a POSIX shell):

- GNU readline — the library rlwrap and bash `read -e` use.
- libedit — the BSD-licensed readline-compatible alternative.
- [linenoise](https://github.com/antirez/linenoise) — a minimal, self-contained C alternative used by Redis and MongoDB; single and multi-line editing with history.
- linenoise-ng — a fork adding UTF-8 and Windows support.
- prompt-toolkit — a full-featured Python readline replacement (syntax highlighting, completion, history) used by IPython and pgcli.
- reedline — the Rust line editor behind nushell.
- ble.sh — a bash-only line editor adding syntax highlighting and richer history.

Embedding any of these would require rewriting tprompt in C, Python, Rust, or bash. They do not fit a POSIX-shell tool and are listed for completeness only.

### 4.5 Recommendation for tprompt (accepted)

Two viable paths, in priority order. Both are accepted for the `--history` design in §11.1.

**fzf-based history picker — primary, zero new dependency.**

tprompt already requires fzf for value-lists, so reuse it for history recall. On Ctrl-R during a free-text input, tprompt opens a fzf list over that field's history entries; the user fuzzy-searches and picks; the picked value fills the input line.

This matches the review's "Ctrl-R like the bash history" request, uses tprompt's existing picker architecture, adds no new dependency, and keeps per-field segmentation by feeding fzf only that field's slice of the history file. It is the recommended default.

**rlwrap as an optional backend — secondary, opt-in.**

For callers who want full readline editing — cursor movement, word kill, bracketed paste — in addition to history recall, tprompt can shell out to `rlwrap -H <file>` for a free-text input when rlwrap is present. It is opt-in via `--history-mode rlwrap` (or auto-detected) and degrades to plain `read` when rlwrap is absent.

It is secondary because fzf already covers the recall use case the review asked for, and adding a runtime dependency for editing niceties is a caller's call.

Rejected: atuin, mcfly, hstr, and Suvadu hook the shell's command history and cannot serve a script's per-field `read`. Rejected: linenoise, libedit, prompt-toolkit, reedline, ble.sh, and GNU readline as a library would require rewriting tprompt in another language.

## 5. Color — configurable label and default colors

**Explanation.**

tprompt 0.2.0 introduced `--color[=always|auto|never]` with two hardcoded colors: the prompt label in bold cyan and the default hint in dim yellow. Those fixed choices do not fit every terminal theme, every field type, or every user's contrast needs.

This feature makes both colors configurable from the command line. A caller can match a dark or light theme, color-code a critical field, or raise contrast for accessibility — all without touching tprompt's source. The on/off/auto switch from 0.2.0 stays; this adds the ability to choose which colors the switch turns on.

**Examples / use cases.**

- Match a dark theme where cyan reads as blue: set the label to bold blue and the default to dim white.
- Color-code a destructive-action field red via a per-spec key, so the prompt label itself signals caution before the user types.

**Command line.** Global options set the colors, `--theme` bundles them, and the C form allows per-spec override:

```sh
tprompt --color --label-color "bold blue" --default-color "dim white" 'host|h|localhost'
tprompt --theme dark 'host|h|localhost'
# C form, per-spec label color
name=action
prompt=confirm destroy
label-color=red
```

**Design proposal.**

A color spec accepts either a named color (black, red, green, yellow, blue, magenta, cyan, white) with an optional style prefix (bold, dim, underline, combinable as `bold red`), or a raw SGR code string such as `1;31`.

Three new options:

- `--label-color <spec>` — sets the prompt label color.
- `--default-color <spec>` — sets the default-hint color.
- `--theme <name>` — bundles label, default, and list colors; themes are `default`, `dark`, `light`, `high-contrast`.

The existing `--color[=mode]` switch remains the on/off/auto gate. `auto` still means on when stderr is a tty and `NO_COLOR` is unset. Per-spec coloring is added as C `label-color=<spec>` and `default-color=<spec>` keys; the B form stays terse and relies on the global options.

Defaults remain bold-cyan label and dim-yellow default, so existing scripts see no change unless they opt in. The ANSI-strip-on-output behavior from 0.2.0 is unchanged: a values list may carry ANSI for display, but the output `name=value` is always plain text.

## 6. Input validation

### 6.1 `--validate <regex>` (with per-entry B-form `qr:` prefix)

**Explanation.**

Reject input that does not match a regular expression. In interactive mode the user is re-prompted; in scripted mode the input is an error. This is the building block for must-be-a-port, must-be-a-slug, must-be-an-email — without tprompt having to know any of those domains.

The regex can be passed in three ways:

- **Globally**, with `--validate <regex>` applied to every free-text input.
- **Per-entry in the B form**, with a `qr:`-prefixed regex detected by prefix at any field position (see Design proposal).
- **Per-spec in the C form**, with a `validate=<regex>` key. This is the recommended path for regexes containing pipe, question mark, or shell-special characters, because the C value is read from stdin and avoids shell quoting.

**Examples / use cases.**

- Two numeric inputs, one global rule: `--validate '^[0-9]+$'` covers both a port and a replica count.
- A hostname field with a per-entry regex in the B form, no C needed: `'host|target host|localhost|qr:^[a-z][a-z0-9-]{2,30}$'`.

**Command line.**

```sh
# global, applies to every free-text input
tprompt --validate '^[0-9]+$' 'port|port|22' 'replicas|replicas|3'
# qr: in the values slot (no values list)
tprompt 'host|target host|localhost|qr:^[a-z][a-z0-9-]{2,30}$'
# qr: after a values list (values + regex coexist)
tprompt 'port|port|22|22,80,443,8080|qr:^[0-9]+$'
# C form, per-spec regex (no shell-quoting pain)
name=host
prompt=hostname
default=localhost
validate=^[a-z][a-z0-9-]{2,30}$
```

**Design proposal.**

The `qr:`-prefixed regex is a field detected by prefix, not by position. The parser splits the B spec on `|` and treats any field beginning with `qr:` as the validation regex; the remaining fields fill name, prompt, default, and values in order. So the regex can sit in the values slot when there is no list, or after the values list when there is one — and technically anywhere, though those two placements are the natural ones.

Because the regex is its own prefix-detected field, a spec can carry both a values list and a regex: `'port|port|22|22,80,443,8080|qr:^[0-9]+$'`. When both are present, the input is a picker (the values list) and the picked value is also checked against the regex. This is rarely needed — values are usually pre-constrained — but it is supported.

The `qr:` prefix echoes Perl's regex-quote operator and does not collide with values-list content, because a values list starts with a value, not `qr:`. The regex flavor is POSIX ERE (awk's native regex), matching the rest of tprompt's awk implementation; backreferences and lookahead are not supported.

Order of operations: the check runs after environment expansion and after the default fallback resolves the final value, so the emitted value is what is validated. A companion `--validate-error <msg>` (or C `validate-error=<msg>`) overrides the default `invalid: does not match <pattern>` message.

Edge cases: value-list picks are exempt when no `qr:` is present — a choice from the list is valid by construction. Empty answers are subject to `required` first; if not required and empty, validation is skipped. `--retry` governs how many times an interactive mismatch re-prompts before the run cancels.

### 6.2 `required=1`

**Explanation.**

Today an empty answer falls back to the default or stays empty. `required=1` makes an empty answer an error, distinct from having a default. This is for fields that must have a real value and where no sensible default exists: a project name, an email, a target host the caller cannot guess.

**Examples / use cases.**

- A required hostname with no default: the user cannot just press Enter.
- A required email collected before a deploy proceeds.

**Command line.**

```sh
# B form: '!' prefix marks required (parallel to '*' for secret)
tprompt '!host|target host|' '!email|email|'
# C form
name=host
prompt=target host
required=1
```

**Design proposal.**

A `!` prefix on the name marks a B input as required, parallel to `*` for secret. The prefixes combine, so `*!pw` is secret plus required and `!host` is required. C uses the `required=1` key.

On an empty answer in scripted mode, tprompt writes `TPROMPT_ERROR: required field 'host' is empty` and exits non-zero with no stdout. In interactive mode the user is re-prompted up to `--retry` times, then the run cancels.

`required` is checked before `--validate` — an empty string should not be tested against a pattern. This ordering matters when both are set: a required field that is also validated will report "required" first, not "does not match".

### 6.3 `--retry <n>`

**Explanation.**

Re-prompt up to N times on invalid input before giving up. The invalid inputs that consume a retry are a `--validate` mismatch or a `required` empty. Without `--retry`, one bad answer cancels the run; with it, the user gets a few chances to correct a typo.

**Examples / use cases.**

- A validated hostname with three retries.
- `--retry 0` makes the policy explicit: one shot, fail fast, the current behavior.

**Command line.**

```sh
tprompt --retry 3 --validate '^[a-z]+$' 'host|host|localhost'
# per-spec in C
name=host
validate=^[a-z]+$
retry=3
```

**Design proposal.**

Default is 0 (fail fast, matching 0.2.0). `--retry 3` allows up to three re-prompts; on the fourth failure the run cancels with no stdout. The counter is per-input and resets between inputs.

Each retry prints a stderr hint: `invalid: <reason>; try again (n left)`. A C `retry=<n>` key overrides the global value per spec.

In scripted mode `--retry` has no effect — there is no re-prompt loop over a pipe — and is ignored with a stderr notice if set explicitly. With the v2 removals, `--retry` composes with exactly two checks: `required` and `--validate`. Any of those failing consumes one retry.

## 7. Picker and list UX

### 7.1 `preview=<cmd>` (per-spec: B `pv:` prefix or C `preview=`, fzf only)

**Explanation.**

An fzf `--preview` command for a values list — it shows a preview of each choice as the user moves through the list. This turns a flat pick into a browsable catalog: man pages for a man-picker, host stats for a host picker, file contents for a file picker.

Preview is a per-spec attribute, not a global flag — it is only relevant to a values-list input, so it belongs on the spec. It is set two ways: in the B form with a `pv:`-prefixed command (detected by prefix at any field position, parallel to `qr:`), or in the C form with a `preview=<cmd>` key.

**Examples / use cases.**

- Pick a man page with its summary previewed as you scroll.
- Pick a host with a one-line ping preview for each entry.

**Command line.**

```sh
# B form: pv:-prefixed command, position-independent (parallel to qr:)
tprompt 'manpage|man page||git.1,git-add.1,git-commit.1|pv:man {}'
tprompt 'host|host||host-a,host-b,host-c|pv:ping -c1 -W1 {}'
# C form: preview= key
name=manpage
prompt=man page
values=git.1,git-add.1,git-commit.1
preview=man {}

name=host
prompt=host
values=host-a,host-b,host-c
preview=ping -c1 -W1 {}
```

**Design proposal.**

The `pv:` prefix mirrors the `qr:` convention from §6.1: the parser splits the B spec on `|` and treats any field beginning with `pv:` as the preview command (the text after `pv:`), independent of position. A spec can therefore carry both a values list and a preview — `'manpage|man page||git.1,git-add.1,git-commit.1|pv:man {}'` — and the preview sits wherever the caller finds natural (typically the trailing slot).

`<cmd>` has `{}` substituted with the current item (the fzf convention). The preview is only effective when the picker is fzf; the numbered picker and the external command ignore it, and if fzf is absent the preview is silently ignored.

The command runs in the popup's shell with the caller's environment. A slow command (for example `ping` without a timeout) makes the list sluggish, so the caller should keep it fast — `-W1`, `head -1`, and so on.

### 7.2 `--header <text>` / `--header-file <path>`

**Explanation.**

A banner above the prompts or the list — one line of context for what the inputs are for. Examples: `Deploy config — prod`; `Step 2 of 4: database`; a reminder that Esc cancels.

**Examples / use cases.**

- A one-line banner naming the deploy target.
- A multi-line header from a file (a project banner plus a cancel reminder).

**Command line.**

```sh
tprompt --header "Deploy config — prod" 'host|h|' 'port|p|22'
tprompt --header-file banner.txt 'host|h|' 'port|p|22'
```

**Design proposal.**

The header is printed to stderr once at the top of the run, before the first prompt. For fzf it is passed as `--header`. Multi-line headers are supported — the text or file may contain newlines.

When `--color` is on, the header is colored with the label color. `--header-file` reads the file at startup; a missing file is a hard error. `--header` and `--header-file` are mutually exclusive.

In the tmux popup the header appears at the top of the popup; in-shell it appears before the first prompt.

## 8. Output formats

### 8.1 `--json` output

**Explanation.**

Print results as JSON instead of `name=value` lines. This makes tprompt a direct source for tools that consume JSON — `jq`, a config generator, a CI step that posts to an API — without the caller parsing `name=value` itself.

**Examples / use cases.**

- JSON Lines (the default): one object per input.
- A single JSON array for multiple inputs.

**Command line.**

```sh
tprompt --json 'host|h|localhost' 'port|p|22'
# {"name":"host","value":"localhost"}
# {"name":"port","value":"22"}
tprompt --json --json-array 'host|h|' 'port|p|'
# [{"name":"host","value":"..."},{"name":"port","value":"..."}]
```

**Design proposal.**

`--json` emits JSON Lines (one object per line). `--json-array` emits a single JSON array. Values are JSON-string-escaped — quotes, backslashes, control characters, newlines.

Secrets are included in cleartext, same as the default output; tprompt does not redact. `--json` is mutually exclusive with the default `name=value` format and with `--save` writing (the save file stays `name=value`; JSON is an emit concern).

Multi-values stay a single joined string (`a,b,d`) for consistency with the default output. A future `--json-array-values` could emit `value` as an array, but that is out of scope for this round.

### 8.2 `--save <file>` / `--load <file>`

**Explanation.**

Persist this run's answers to a file, and pre-fill the next run from that file — a lightweight remembered-defaults so a repeated workflow does not require re-typing. The file format is the same `name=value` output tprompt already produces, so the two are round-trippable.

`--save <file>` writes the stdout `name=value` lines to the file after a successful run. The write is atomic (temp file plus rename), so a crash does not corrupt it. `--load <file>` reads a prior `name=value` file; for each name that matches a current spec input, the loaded value becomes the default for that input.

Precedence for the value, in order:

- a typed answer (or a scripted stdin answer) wins;
- then the loaded value;
- then the spec's `default` (which already includes env expansion).

Names in the file not in the current spec are ignored; names in the spec not in the file use the spec default.

**Examples / use cases.**

- A deploy script: save this run's answers, load them next run so the user just hits Enter to confirm.
- A guided setup wizard that remembers between invocations.

**Command line.**

```sh
tprompt --save .tprompt-answers 'host|h|' 'port|p|22'
# next run — file may not exist yet on first run; --load is a silent no-op then
tprompt --load .tprompt-answers 'host|h|' 'port|p|22'
# both: load to pre-fill, then save the updated answers
tprompt --load .tprompt-answers --save .tprompt-answers 'host|h|' 'port|p|22'
```

**Design proposal.**

The file format is `name=value` lines; lines starting with `#` are comments, so a user can annotate. `--load` only pre-fills names that exist in the current spec.

**Secrets.** `--save` refuses to write secret inputs by default — it skips them and prints a stderr warning — because the file is cleartext on disk. `--save-secrets` opts in, and the caller accepts the risk. `--load` of a secret input pre-fills it: the file already contains it cleartext, so loading is consistent. `--save` writes only on a successful run (exit 0); a cancel or error leaves the file untouched.

**File existence and permissions** (per the review):

- A missing file on `--load` is a silent no-op — no error, no pre-fill — so `--load` is safe to use unconditionally even on a first run.
- A missing file on `--save` is created. The parent directory must already exist and be writable; a missing parent directory is a hard error.
- A non-writable file on `--save` (read-only, or permission denied) is a hard error: tprompt writes `TPROMPT_ERROR: cannot write save file '<file>'` to stderr and exits non-zero with no stdout.

This is distinct from `--specs-from` (§9.2), where a missing file is a hard error because the specs are required input, not optional pre-fill.

## 9. Interaction modes

### 9.1 `--timeout <s>`

**Explanation.**

Auto-cancel the whole run after N seconds. Useful when tprompt runs inside a non-interactive supervisor (CI, a watchdog) that must not hang forever waiting for a human.

**Examples / use cases.**

- A CI prompt that should give up after 30 seconds rather than stall the pipeline.
- A 60-second timeout on a deploy confirmation in an automated pipeline with a human approver.

**Command line.**

```sh
tprompt --timeout 30 'approve|approve deploy?|no|yes,no'
tprompt --timeout 0 'host|h|'   # 0 = no timeout (default)
```

**Design proposal.**

A background timer fires after N seconds and cancels the current prompt — it writes a cancel to the result file, exits 1, and produces no stdout.

Implementation in POSIX: a subshell `(sleep N; kill -INT $PPID)`, or a `read -t` fallback where available. `read -t` is a bash/dash extension (dash supports it), so the portable path is the background sleep plus signal. `--timeout 0` means no timeout (the default).

Only meaningful in interactive mode. In scripted mode the timeout would apply to the whole stdin read, which is unusual, so it is ignored there with a stderr notice. A timeout fires as a cancel, not an error: the exit code is 1 and no `TPROMPT_ERROR` marker is written.

### 9.2 `--specs-from <file>`

**Explanation.**

Read B specs from a file (one per line) instead of argv. For long input lists this avoids quoting twenty positional args and keeps the spec in a maintainable file.

**Examples / use cases.**

- A twenty-input onboarding form stored as a file.
- A spec file version-controlled alongside the deploy script that consumes it.

**Command line.**

```sh
tprompt --specs-from form.txt
# form.txt:
# host|target host|
# port|port|22|22,80,443
# *pw|Password:
```

**Design proposal.**

Each non-empty, non-`#` line is a B spec — `name|prompt|default[|values]`, with the values field accepting a `qr:`-prefixed regex per §6.1. Comments and blank lines are ignored.

`--specs-from` is mutually exclusive with B positionals; passing both is an error. It combines with C: `--specs-from` is B-from-file, C is still stdin. The file is read once at startup.

A missing file is a hard error. This is the opposite of `--load`, where a missing file is a silent no-op — `--specs-from` is required input, `--load` is optional pre-fill.

### 9.3 `--editor` spec type (B form via `@`, `file:` default)

**Explanation.**

Open `$EDITOR` on a temp file for a long-form text input, then return the saved buffer. For commit messages, deployment notes, change descriptions — anything longer than a one-line `read`. Per the review, the B form must support it, and the default can be a file path (a template read from disk), not just a literal string.

**Examples / use cases.**

- A commit message collected before a deploy, pre-filled from a template file.
- A deployment note typed fresh (no template).

**Command line.**

```sh
# B form: '@' prefix on the name marks editor-type (parallel to '*' secret, '!' required)
tprompt '@commit_msg|commit message|file:/tmp/commit-template.txt'
tprompt '@note|deployment note|'          # no template, fresh buffer
# C form
name=commit_msg
prompt=commit message
default=file:/tmp/commit-template.txt
type=editor
```

**Design proposal.**

A `@` prefix on the name marks a B input as editor-type, parallel to `*` for secret and `!` for required. The prefixes combine, so `@commit_msg` is editor and `!@host` is required-plus-editor. `@` and `*` are mutually exclusive — an editor displays its buffer, so it cannot be a secret, and combining them is an error. C uses the `type=editor` key.

**The default field.** When the input is editor-type, the default accepts either a literal string (pre-fills the temp file with that text) or a `file:`-prefixed path (reads that file's contents as the template). The `file:` prefix matches the `qr:` convention from §6.1. If a `file:` path does not exist or is not readable, it is a hard error.

**The flow.** tprompt writes a temp file (pre-filled with the default string or the file contents), runs `$EDITOR` on it — falling back to `vi`, then erroring if neither is available — reads the file back, and returns the content with the trailing newline trimmed. `$EDITOR` runs in the caller's environment.

**Multi-line values.** The value may contain newlines, and the caller must handle that: the `name=value` output line will contain embedded newlines (document this), and `--json` escapes them correctly. `--editor` is mutually exclusive with `--multiline` — different mechanisms for the same need: editor is full-screen, multiline is sentinel-based in the prompt.

### 9.4 `--multiline` with a sentinel

**Explanation.**

Read lines until a sentinel line (default a single dot) or EOF, and return the whole block. A lighter alternative to `--editor` — no external program, just keep reading until the user signals done.

**Examples / use cases.**

- A description block terminated by a dot on its own line.
- EOF-terminated (`--sentinel` with an empty value) for a paste-and-Ctrl-D flow.

**Command line.**

```sh
tprompt --multiline 'desc|description|'
tprompt --multiline --sentinel '---' 'desc|description|'
tprompt --multiline --sentinel '' 'desc|description|'   # EOF-terminated
# C form
name=desc
multiline=1
sentinel=.
```

**Design proposal.**

tprompt reads lines until a line equal to the sentinel (default a dot) or EOF. The block — lines joined with newline — is the value; the sentinel itself is not included. Blank lines are part of the block, not a terminator; only the sentinel ends it. `--sentinel` with an empty value means EOF-terminated.

The value may contain newlines (same caller caveat as `--editor`). Numbered and fzf value-lists ignore `--multiline`.

A C `multiline=1` key and `sentinel=<str>` key scope it per spec. In scripted mode, the whole stdin is taken as the block, and the sentinel is still honored if it appears on a line.

## 10. Display and layout

### 10.1 `--width <n>` / `--height <n>`

**Explanation.**

Set the tmux popup dimensions. tprompt 0.2.0 hardcodes 80×20; this lets a caller widen for long values lists or shrink for a one-line prompt, and auto-size to content.

**Examples / use cases.**

- A wide values list: `--width 120 --height 40`.
- Auto-size to the longest prompt plus value.

**Command line.**

```sh
tprompt --popup --width 120 --height 40 'region|r||long-list,...'
tprompt --popup --auto-size 'host|h|localhost'
```

**Design proposal.**

`--width` and `--height` set the tmux `display-popup` `-w` and `-h` (in characters and lines). `--auto-size` computes width as the max of prompt length, default hint, and values width, with padding, capped at the terminal width and height (tmux clamps anyway).

In-shell mode ignores these — there is no popup. Default stays 80×20 unless `--auto-size` is given. Caps prevent a popup larger than the terminal.

### 10.2 `--trim` / `--no-trim`

**Explanation.**

Trim leading and trailing whitespace from answers. Default trim gives cleaner values; `--no-trim` is for inputs where the spaces matter — a password that might end in a space, a pasted value with intentional indentation.

**Examples / use cases.**

- `--no-trim` for a secret that could have trailing spaces.
- Default trim strips accidental leading spaces from a pasted host.

**Command line.**

```sh
tprompt --no-trim '*pw|Password:'
tprompt --trim 'host|h|localhost'   # explicit (default behavior)
# C form
name=pw
secret=1
trim=0
```

**Design proposal.**

Trimming runs after the read and before `required` and `--validate` — the two checks that remain in v2, since `type` was removed. The proposal makes trim default-on for non-secrets and default-off for secrets, because a secret with trailing spaces is a real case.

This is a behavior change from 0.2.0, which does not trim (`IFS= read -r` preserves whitespace). Document it in the changelog, and provide `--no-trim` for callers that rely on preserving whitespace. Trimming uses awk `gsub` on leading and trailing spaces and tabs. A C `trim=0` key overrides per spec.

The alternative — default off, `--trim` opt-in — is safer for backward compatibility. It is noted as a fallback if the breakage from default-on proves disruptive.

## 11. Integration and robustness

### 11.1 `--history <file>` (manual Ctrl-R recall, fzf primary + rlwrap optional)

**Explanation.**

Readline-style history for free-text inputs, with recall started manually by the user (Ctrl-R, like bash) rather than always-on Up/Down. For a host or a branch name the user re-enters, history turns the prompt into a quick-recall field.

The implementation follows the §4 research, which the review accepted: fzf as the primary recall UI (zero new dependency), rlwrap as an optional backend for full readline editing.

**Examples / use cases.**

- A host prompt where Ctrl-R opens a fuzzy picker over prior hosts.
- A branch-name prompt with history across deploys, plus rlwrap for cursor editing when the caller opts in.

**Command line.**

```sh
tprompt --history .tprompt-history 'host|h|'
# opt into the rlwrap backend for full readline editing (rlwrap present)
tprompt --history .tprompt-history --history-mode rlwrap 'host|h|'
tprompt --history .tprompt-history --load .tprompt-answers 'host|h|'
```

**Design proposal.**

History is per free-text input; value-lists do not use it. The file holds prior answers keyed by field name (most-recent-last, deduped, capped — for example 100 entries per field), so segmentation stays clean. This is what avoids the rlwrap-whole-command problem from §4.2.

Recall is manual, per the review: during a free-text input, the user presses Ctrl-R to invoke history recall. There is no always-on Up/Down. Two implementations, in the priority order from §4.5:

**fzf picker — primary, default.**

On Ctrl-R, tprompt opens a fzf list over the current field's history slice. The user fuzzy-searches and picks; the picked value fills the input line for further editing or submission.

This reuses tprompt's existing fzf dependency, adds nothing, and matches the review's "Ctrl-R like the bash history" request. It falls back to "no history" if fzf is absent.

**rlwrap backend — optional, opt-in via `--history-mode rlwrap`.**

tprompt shells out to `rlwrap -H <field-history-file> -s 100 --history-no-dupes 1 --remember` around the read, giving full readline editing (cursor movement, word kill, bracketed paste) plus Ctrl-R and Up/Down, with rlwrap's own history file.

It degrades to plain `read` (no history) if rlwrap is absent, with a stderr notice.

History is appended to the file after each successful free-text answer (on exit 0; a cancel or error does not append). Values with newlines are excluded or escaped — one line per entry.

`--history` composes with `--save` and `--load`; they are different concerns (history is recall UX, save/load is remembered defaults). In scripted mode, Ctrl-R recall is a no-op (input comes from a pipe), but the file is still read for any future interactive run.

## 12. Suggested implementation order

The fifteen features group into three tiers of five. Tier 1 is high value, low effort, and builds directly on the 0.2.0 record and option loop. Tier 2 is medium effort with high value. Tier 3 carries a portability caveat or a larger surface — a new input mode, fzf/rlwrap integration, or signal-based timeout. The table lists every feature with its option, its scope, and its tier.

**Table 2. Feature summary and implementation tiers (v3)**

| Feature | Option | Scope | Tier |
|---|---|---|---|
| Configurable colors | `--label-color` / `--default-color` / `--theme` | global + C per-spec | T2 |
| Regex validation | `--validate` / B `qr:` / C `validate=` | global + per-spec | T1 |
| Required field | `!` prefix / C `required=1` | per-spec | T1 |
| Retry on invalid | `--retry` / C `retry=` | global + per-spec | T1 |
| Preview command | B `pv:` / C `preview=` | per-spec (fzf) | T3 |
| Header banner | `--header` / `--header-file` | global | T2 |
| JSON output | `--json` / `--json-array` | global | T2 |
| Save / load answers | `--save` / `--load` | global | T2 |
| Timeout | `--timeout` | global | T3 |
| Specs from file | `--specs-from` | global | T1 |
| Editor input | B `@` / C `type=editor` + `file:` default | per-spec + global | T3 |
| Multiline input | `--multiline` / C `multiline=` | global + per-spec | T3 |
| Popup dimensions | `--width` / `--height` / `--auto-size` | global (popup) | T2 |
| Trim whitespace | `--trim` / `--no-trim` / C `trim=` | global + per-spec | T1 |
| History | `--history` / `--history-mode` | global (fzf + rlwrap) | T3 |

Tier 1 (five features) ships as 0.3.0 with minimal risk: `required`, `--retry`, `--validate` (including the B-form `qr:` prefix), `--trim`/`--no-trim`, and `--specs-from` all reuse the existing option loop and the six-field record.

Tier 2 (five features) is 0.4.0: configurable color, `--json`, `--save`/`--load`, `--header`, and `--width`/`--height`.

Tier 3 (five features) is 0.5.0 and beyond, where each item needs its own design care: `preview` (B `pv:` / C `preview=`) for fzf integration, `--editor` and `--multiline` for new input modes, `--timeout` for signal handling, and `--history` for the fzf-primary + rlwrap-optional recall from §4.

## 13. Rejected features (from the review)

These six were specified in v1 and explicitly rejected in the review. They are recorded here with the rationale so the decisions are not lost; they are not on the implementation roadmap.

- **`type=number` with `min`/`max`** — rejected: "regexp is enough." Numeric range checks are covered by `--validate '^[0-9]+$'` (and a range-shaped regex where needed). A dedicated numeric type adds surface for no real gain over the regex path.
- **`--confirm` + `--mask-char` for secrets** — rejected: "the caller can ask for a second input and compare the two values." A two-prompt-and-compare flow is a caller concern (two tprompt calls plus a shell `test`), not a tprompt feature. The `--mask-char` per-keystroke masking goes with it; the existing `stty -echo` full-hide for `*` secrets stays.
- **`--sort` / `--no-sort`** — rejected: "the caller can sort the list before passing it to tprompt." Sorting the values list before the `tprompt` invocation is a one-line `sort` in the caller; tprompt does not need the option.
- **`default-first`** — rejected: "the caller can put the default first in the list." The caller orders the values list however they like, default included; tprompt does not need to reorder.
- **`--dry-run`** — rejected. The existing `--print-spec` from 0.2.0 covers the "show the normalized spec" need; a separate "what would be prompted" preview is not worth the surface.
- **`if-empty=<value>`** — rejected. The `default` field already doubles as the empty-substitution (an empty answer falls back to `default`); a separate `if-empty` key decoupling the hint from the substitution adds confusion for no real gain.

## 14. Out of scope for this round

These items from the original backlog are deferred — not rejected, they stay on the backlog for a later round.

- `--env` and `--yaml` output formats (the `name=value` and `--json` forms cover the immediate need).
- `--yesno` boolean input (a values list of `yes,no` plus `required` covers it for now).
- A per-spec `hint=` key (a help line under the prompt) and `--key-help` (an fzf keybinding hint).
- A numbered-picker preview (only fzf gains `preview=` in this round).
- `--save-secrets` encryption (the cleartext refusal plus opt-in is the scope here; encrypting the save file is a later concern).
- A full TUI redraw (the popup and in-shell paths stay as they are; a persistent TUI is a separate project).
- An explicit default marker in the B form (the v1 review's `<<localhost>>` notation — if the `<<>>` was meant as a visible default marker rather than informal emphasis, that is a separate display feature).

Each deferred item is noted so it is not forgotten; the next round can pick from this list or from the remaining suggestions in `docs/working-secret-color-multi.md`.
