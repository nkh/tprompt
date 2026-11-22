# tprompt — working document: secret input, color, multi-value

> **Status:** planning + in-progress. This document records what I understood
> from the request, the current state of `tprompt`, exactly what I am going to
> change, the open decisions, and thirty suggestions for making the utility more
> usable. It is the companion to the code change; the manpage, DESIGN.md,
> README, and CHANGELOG are updated alongside.

## 1. What I understood

Three changes to `tprompt`, each stated then restated in my own words so the
intent is unambiguous:

1. **Secret (hidden) input.** Today every input is echoed as the user types it.
   For secrets (passwords, tokens) the entry must be hidden. The trigger is a
   marker in the spec: a leading `*` as the first character of the **name**
   tells tprompt "this input is secret, do not echo what I type." The `*` is
   stripped, so the output key is the bare name (`password=...`, not
   `*password=...`).

2. **Color.** Add a `--color` option that colorizes two things in the prompt
   display: the variable **name** (the prompt label) and the **default value**
   (the `[default]` hint). Separately, the **values list** may itself contain
   ANSI color codes (so a caller can color-code the choices shown in the
   picker); those codes must be **stripped before the result is printed**, so
   the output `name=value` is always plain text even if the choices were
   colored in the UI.

3. **Multiple values.** An input may accept more than one value. Without tmux
   the user can answer with the values themselves, e.g. `a,b,d`; with tmux
   (fzf) the user can select several entries and tprompt outputs them joined,
   e.g. `a,b,d`. The separator between joined values is **user-definable**
   (`--sep`, default `,`).

Plus a fourth deliverable: this working document, with thirty usability
suggestions at the end.

## 2. Current state of tprompt (baseline)

`tprompt` 0.1.0 is a single POSIX `sh` + `awk` script (342 lines), standalone,
tmux-optional, fzf-optional. Test baseline: **15 files, all green.**

- **Two spec forms:** B (positional `name|prompt|default[|values]`, repeatable)
  and C (stdin `key=value` lines, blank-line separated; keys `name`, `prompt`,
  `default`, `values`, `default-env`, `values-env`).
- **Internal record:** four fields, ASCII Unit Separator (`\x1f`) delimited:
  `name`, `prompt`, `default`, `values`. Env (`$VAR`/`${VAR}`) is expanded at
  normalize time so the tmux-popup inner process sees the caller's environment.
- **Modes:** interactive (stdin is a tty, or `--interactive`) vs. scripted
  (stdin is a pipe, or `--scripted`). Render: `--in-shell` (default) vs.
  `--popup` (tmux `display-popup`, re-entering `tprompt --internal-collect`).
- **Picker:** for a values-list input, `fzf` (default if installed), `numbered`
  (a numbered list to stderr, one index read from stdin), or an external
  command. Single selection only.
- **Output:** one `name=value` line per input, in order, on stdout. Cancel (Esc
  in fzf, EOF/Ctrl-D, malformed spec) → exit non-zero, no stdout. Prompts and
  the numbered list go to **stderr** to keep stdout clean.
- **Popup re-entry:** the outer process normalizes specs into a file, invokes
  `tprompt --picker <p> --internal-collect <specfile> <resfile>` inside the
  popup; the inner collects into a result file; the outer interprets it
  (`M==N` and no `TPROMPT_ERROR:` → success).

The seams I will touch: the spec parsers (B + C), the internal record format,
`tp_collect` (the loop that prompts/reads), `tp_read_value`, `tp_pick_value`,
`tp_pick_numbered`, the option loop, the popup re-entry command, and
`--print-spec`.

## 3. What I am going to change

### 3.1 Secret input — `*` prefix on the name

**Syntax.** A leading `*` on the name marks the input as secret. The `*` is
stripped; the output key is the bare name.

- B form: `'*password|Password:'` → name `password`, secret.
- C form: `name=*password` (the value of the `name=` key starts with `*`), or
  the explicit key `secret=1`. Both set the flag; the `*` is stripped.

**Behavior.**

- The typed characters are not echoed. POSIX `read` has no `-s`, so hiding is
  done with `stty -echo` before the read and `stty echo` after (with an EXIT
  trap to re-enable echo if the read is interrupted). This is portable across
  dash/ash/bash.
- The default is **not shown** in the prompt for a secret (showing
  `[s3cr3t]` would leak it). The prompt is just `Password: `. If the user
  enters an empty line, the default is used silently.
- The **output is still cleartext** `password=s3cr3t`. tprompt hides *entry*,
  not the captured value — the caller reads the value into a variable and does
  what it needs with it. Masking the output would make the value unusable.

**Edge cases.** `stty -echo` fails if stdin is not a terminal (scripted mode);
in that case tprompt falls back to a normal read (scripted secrets read the
answer line verbatim from stdin — the same as any scripted input). A secret
with a values list is unusual but legal: the picker still shows the choices
(the choices are not the secret), and the selected value is output cleartext.

### 3.2 Color — `--color[=mode]` + ANSI stripping on output

**Option.** `--color[=always|auto|never]`. Bare `--color` = `always`. Default
`auto`: color when stderr is a tty and `NO_COLOR` is unset. (Mirrors tum's
`--color` semantics, for consistency across the tool family.)

**What gets colored (display only, stderr).**

- The **prompt label** (the name/prompt): bold cyan (`\033[1;36m…\033[0m`).
- The **default hint** `[default]`: dim yellow (`\033[2;33m…\033[0m`).
- A secret's prompt label is colored the same; its default is not shown.

**Values list with ANSI.** A `values` list may carry ANSI codes, e.g.
`red,$'\033[31m'stop$'\033[0m',green,go`. These are **rendered** in the picker:

- fzf: invoked with `--ansi` so it renders the codes in the list and **strips
  them from its own output** automatically.
- numbered: the items are printed to stderr with their codes intact, so the
  terminal renders them.
- external `<cmd>`: the items are piped through as-is; the command renders them.

**ANSI stripped before output.** Regardless of the picker, the final value is
run through an ANSI-stripping filter (an `awk` one-liner removing CSI sequences
`\033\[[0-9;]*[A-Za-z]`) before it is joined and printed as `name=value`. This
is a safety net for the numbered/external paths and for any value that carries
codes the picker did not strip. The output is always plain text.

**`--print-spec`** also gains a `--color`-aware mode: when color is on, the
tab-separated field labels are colored; the values are shown raw (so a caller
can see the embedded ANSI). When color is off, plain as today.

### 3.3 Multiple values — `--multi`, `--sep`, and `multi=1`

**Markers.**

- Global flag `--multi`: every values-list input becomes multi-select.
- Per-spec (C form only, since B is terse): the key `multi=1` marks one input
  as multi. (B specs rely on the global `--multi` flag for multi-select.)
- A free-text input (no values list) is unaffected by `--multi` — the user
  already types whatever they want; multi is about *constrained choice*.

**Separator.** `--sep <char>` (default `,`). Used to join multi-selected values
in the output: `name=a,b,d`. The separator is a single argument; multi-char
separators are accepted (e.g. `--sep '; '`).

**Behavior by path.**

- **Interactive + fzf:** `fzf --multi --ansi --prompt=…`. The user Tabs to
  select several; fzf emits each selected line on its own line; tprompt joins
  them with the separator → `name=a,b,d`.
- **Interactive + numbered (no fzf):** the numbered list is printed to stderr;
  the prompt asks for a comma-separated selection. Each token is either an
  index (a number in range → the value at that index) or a literal value
  (taken verbatim). The resolved values are joined with the separator. So the
  user can type `1,3,5` (indices) **or** `a,b,d` (values) — matching the
  request "without tmux the user can answer `a,b,d`".
- **Scripted (B, stdin pipe):** one answer line is read verbatim and output
  as-is. The user pipes `a,b,d`; tprompt prints `name=a,b,d`. No UI; the
  separator is the user's own.

**Edge cases.** A value that itself contains the separator is an error of the
caller (documented, not enforced — the join is unambiguous only if values do
not contain the separator). An empty multi-selection (the user picks nothing)
falls back to the default, or cancels if there is no default — same rule as
single-select.

### 3.4 Internal record format — four fields → six

The normalized record gains two boolean fields. New format (still `\x1f`-delimited):

```
name \x1f prompt \x1f default \x1f values \x1f secret \x1f multi
```

`secret` and `multi` are `1` or `0`, set at normalize time:

- `secret`: from the `*` name prefix (B and C) or `secret=1` (C).
- `multi`: from `multi=1` (C) or the global `--multi` flag (applied to every
  record at normalize time, so the popup inner process does not need the flag
  re-passed).

`--print-spec` prints six tab-separated columns. The popup re-entry command
gains `--sep` and `--color` (display/output concerns used at collect time);
`--multi` is not re-passed because it is already encoded in the records.

### 3.5 Option-loop additions

New options consumed in leading position (before the specs):

- `--color[=always|auto|never]`
- `--multi`
- `--sep <char>` / `--sep=<char>`
- `--separator` as a long alias of `--sep`

No existing option changes; the existing 15 tests stay green.

## 4. Open decisions (and what I chose)

| Decision | Choice | Why |
| --- | --- | --- |
| Secret marker | `*` prefix on name (B + C), plus `secret=1` key in C | Matches the request exactly; the C key is for explicit callers. |
| How to hide entry | `stty -echo` + trap, not `read -s` | `read -s` is not POSIX; `stty` is. |
| Show default for secrets? | No | Showing `[s3cr3t]` leaks it. |
| Mask the output? | No | The caller needs the cleartext value. |
| Color default mode | `auto` (tty + no `NO_COLOR`) | Consistent with tum. |
| Color the values list? | Render in picker; strip on output | The request: "stripped before outputting the result." |
| Multi marker | global `--multi` + C `multi=1` | Simplest that covers B and C; no terse B multi syntax. |
| Default separator | `,` | The request's example. |
| Numbered multi input | indices or values, comma-separated | Lets the user type `a,b,d` literally, as requested. |
| Record format | 6 fields, booleans at the end | Backwards-compatible read (old 4-field readers ignore the trailing fields). |

## 5. What I will not change (scope)

- The two spec forms (B + C) stay; no third form.
- The picker tiers (fzf / numbered / external) stay.
- The cancel/error/result-file protocol stays.
- Env expansion stays.
- The popup re-entry mechanism stays (only the re-entry command's flags grow).

## 6. Thirty suggestions to make tprompt more usable

Grouped by theme. These are *not* part of this change; they are candidates for
later work, listed here so they are not forgotten.

### Input validation

1. **`--validate <regex>` per spec** — reject input that does not match; re-prompt
   in interactive mode, error in scripted mode.
2. **`required=1` spec key** — empty is an error (distinct from a default).
3. **`type=number` with `min=`/`max=`** — numeric range check; reject `abc` for a
   number field.
4. **`--retry <n>`** — re-prompt up to N times on invalid input before giving up.
5. **`--confirm` for secrets** — prompt twice and require the two entries to
   match (password-setting flow).
6. **`--mask-char <c>`** — the character shown (or not) for hidden entry; default
   none (stty -echo shows nothing), but `*` per-keystroke is a common option.

### Picker / list UX

7. **`--sort` / `--no-sort`** — sort the values list alphabetically, or preserve
   caller order (default preserve).
8. **`default-first`** — move the default to the top of the list and pre-highlight
   it in fzf.
9. **`--preview <cmd>`** — fzf `--preview` for a values list (e.g. preview a man
   page for each `man:` choice).
10. **`--header <text>` / `--header-file <path>`** — a banner above the prompts or
    the list (a one-line context for what the inputs are for).
11. **`--key-help`** — show fzf keybindings (`Tab` to multi-select, `Esc` to
    cancel) the first time a multi picker opens.
12. **`hint=<text>` spec key** — a help line shown under the prompt ("e.g.
    prod-1.example.com").
13. **`placeholder=<text>` spec key** — fzf `--placeholder` for the search box.

### Output formats

14. **`--env` output** — print `export name="value"` lines instead of `name=value`,
    so the caller can `eval` directly.
15. **`--json` output** — print `{"name":"…","value":"…"}` objects, one per line
    (or a single JSON object).
16. **`--yaml` output** — print a YAML mapping.
17. **`--save <file>` / `--load <file>`** — persist answers to a file and pre-fill
    from it next run (a poor person's remembered defaults).
18. **`--shell-var` output** — print `name='value'` single-quoted, safe for
    `eval` even when values contain spaces or special chars.

### Interaction modes

19. **`--timeout <s>`** — auto-cancel the whole run after N seconds (useful in
    non-interactive supervisors).
20. **`--continue-on-cancel` / `--abort-on-cancel`** — policy: continue to the next
    input on cancel (using the default) or abort the whole run. Default abort.
21. **`--dry-run`** — print the normalized spec + what would be prompted, do not
    prompt (for callers to validate their spec).
22. **`--specs-from <file>`** — read B specs from a file (one per line) instead of
    argv, for long input lists.
23. **`--editor` spec type** — open `$EDITOR` for a long-form text input, return
    the saved buffer (commit messages, notes).
24. **`--multiline` with a sentinel** — read until a blank line or `.`; return the
    whole block (descriptions).

### Display / layout

25. **`--width <n>` / `--height <n>`** — popup dimensions (currently hardcoded
    80×20); auto-size to the longest prompt/value.
26. **`--theme dark|light`** — a named color theme that sets the name/default/list
    colors together, instead of `--color` alone.
27. **`--prompt-suffix <s>`** — the suffix after the label (`: ` by default,
    `> ` for fzf, ` → ` for a custom look).
28. **`--trim` / `--no-trim`** — trim leading/trailing whitespace from answers
    (default trim; `--no-trim` for passwords that might be spaces).

### Integration / robustness

29. **`--history <file>`** — readline-style history for free-text inputs
    (Up/Down to recall prior answers); persisted across runs.
30. **Per-spec `if-empty=<value>`** — a value substituted when the answer is
    empty, distinct from `default` (which is a *hint*); lets a caller say
    "empty means `all`" without making `all` the visible default.

---

## 7. Implementation order

1. Extend the record to six fields; update `--print-spec`. (mechanical)
2. Secret input (`*` prefix, `stty -echo`, hide default). + tests.
3. `--color` (label/default coloring; ANSI strip on output). + tests.
4. Multi-value (`--multi`, `--sep`, `multi=1`; fzf `--multi`; numbered
   comma-select). + tests.
5. Manpage, DESIGN.md, README, CHANGELOG.
6. Full suite green; commit; zip.
