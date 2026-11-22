# Changelog

## Unreleased — next round (0.3.0+)

Work in progress: implementing the next-round features specified in
[docs/next-round-design.md](docs/next-round-design.md). Entries are added per
feature as they land, in tier order (Tier 1 → 0.3.0, Tier 2 → 0.4.0,
Tier 3 → 0.5.0+).

### `--specs-from <file>` (Tier 1)

Read B specs from a file (one per line; `#` comments and blank lines ignored)
instead of positional args — `tprompt --specs-from deploy.txt`. Mutually
exclusive with B positionals; combines with C (stdin is then the scripted-B
answer pipe or the interactive tty). A missing, unreadable, or spec-free file
is a hard error (exit 1), distinct from `--load`'s silent no-op. No internal
record change (a new B-spec source, not a per-spec attribute). Tests:
`t/19-specs-from.sh` (9 assertions); full suite 19 files green.

### `--trim` / `--no-trim` + C `trim=` (Tier 1)

Trim leading/trailing whitespace (spaces and tabs) from answers. Default is
**on** for non-secrets and **off** for secrets (a secret with trailing spaces
is a real case); `--no-trim` preserves whitespace, `--trim` makes the default
explicit. A C `trim=0`/`trim=1` key overrides per spec. Trimming runs after the
read and before validation (and before ANSI stripping).

This is a behavior change from 0.2.0, which did not trim — `--no-trim` restores
the old behavior. The internal spec record grew from six to seven fields
(`name`, `prompt`, `default`, `values`, `secret`, `multi`, `trim`); `--print-spec`
now prints seven columns. The `--trim`/`--no-trim` flag is passed to the tmux
popup inner process via the re-entry command. Tests: `t/20-trim.sh`
(11 assertions); `t/19-specs-from.sh` updated for the 7-column print-spec;
full suite 20 files green.

### `required` — `!` prefix / C `required=1` (Tier 1)

A leading `!` on the name (B) or the C `required=1` key marks a field as
required: an empty answer is an error, distinct from having a default. `!`
combines with `*` (secret) in either order (`*!pw`, `!*pw`); both prefixes are
stripped from the output key. Scripted mode writes
`TPROMPT_ERROR: required field '<name>' is empty` and exits non-zero with no
stdout; interactive mode cancels on an empty answer (re-prompted up to `--retry`
times once that lands). The default is **not** applied to a required field on an
empty answer — required demands a real value. Checked after trim, before
`--validate`. Internal spec record grows 7 → 8 fields (+ `required`);
`--print-spec` now prints eight columns. Tests: `t/21-required.sh`
(19 assertions); `t/19`/`t/20` print-spec checks made column-robust; full suite
21 files green.

### `--validate` / B `qr:` / C `validate=` + `validate-error=` (Tier 1)

Reject answers that do not match a POSIX ERE. `--validate <regex>` (global)
applies to every free-text input; a per-spec regex comes from a B `qr:`-prefixed
field at **any** position (position-independent — the parser splits on `|` and
treats any field beginning with `qr:` as the regex, filling name/prompt/default/
values from the rest in order) or a C `validate=<regex>` key. The regex is
matched against the final value (after env expansion, default fallback, trim).
A mismatch is an error in scripted mode
(`TPROMPT_ERROR:invalid: does not match <pattern>`) and a cancel in interactive
mode. `--validate-error <msg>` / C `validate-error=<msg>` overrides the message.
Checked after `required`. Values-list picks are exempt from the global
`--validate` (valid by construction) unless a per-spec `qr:`/`validate=`
constrains them — then the picked value is also checked; a spec may carry both
a values list and a regex. The B positional parser is now awk-based (to scan
all `|`-fields for `qr:`). Internal spec record grows 8 → 10 fields (+ `validate`,
`validate-error`); `--print-spec` prints ten columns; `--validate`/`--validate-error`
are passed to the popup inner process. Tests: `t/22-validate.sh`
(19 assertions); full suite 22 files green.

### `--retry` / C `retry=` (Tier 1)

Re-prompt up to N times on a `required` or `--validate` failure before canceling
(default 0 = fail fast, matching 0.2.0). `--retry 3` allows up to three
re-prompts; on the next failure the run cancels with no stdout. The counter is
per-input and resets between inputs. Each retry prints
`invalid: <reason>; try again (n left)` on stderr. A C `retry=<n>` key overrides
the global value per spec. Scripted mode ignores `--retry` (no re-prompt loop
over a pipe) with a stderr notice. Applies to interactive free-text inputs only
(values-list picks are one-shot). `tp_collect`'s interactive free-text path is
now a retry loop; the required + validate checks are factored into a new
`tp_check_val` helper (sets `TP_REASON`). Internal spec record grows 10 → 11
fields (+ `retry`); `--print-spec` prints eleven columns; `--retry` is passed to
the popup inner process. **Tier 1 (0.3.0) is now complete.** Tests:
`t/23-retry.sh` (15 assertions); full suite 23 files green.

### `--header` / `--header-file` (Tier 2, 0.4.0)

A banner printed to stderr once at the top of the run, before the first prompt.
`--header <text>` takes the banner inline; `--header-file <path>` reads it from a
file (multi-line supported). The two are mutually exclusive; a missing or
unreadable `--header-file` is a hard error. When `--color` is on the banner is
colored with the label color. For the fzf picker the banner is also passed as
fzf's `--header`. The banner is passed to the tmux popup inner process. No
internal record change (a global display option). Tests: `t/24-header.sh`
(10 assertions); full suite 24 files green.

### `--width` / `--height` / `--auto-size` (Tier 2, 0.4.0)

Set the tmux `display-popup` dimensions: `--width <n>` (default 80, characters),
`--height <n>` (default 20, lines). `--auto-size` computes both from the specs
(max prompt+default+longest-value width + padding; input count + 6 for height),
capped at the terminal (`tput cols`/`tput lines`, fallback 80×24). In-shell mode
ignores these (no popup). No internal record change. Tests: `t/25-width-height.sh`
(8 assertions — parsing + validation; the dimensional effect is only observable
inside a tmux popup); full suite 25 files green.

### `--json` / `--json-array` (Tier 2, 0.4.0)

Emit JSON instead of `name=value`. `--json` produces JSON Lines (one
`{"name":"…","value":"…"}` object per input); `--json-array` produces a single
JSON array on one line (and implies `--json`). Values are JSON-escaped (`"`, `\`,
and `\t`/`\n`/`\r`/`\b`/`\f`); secrets are cleartext; multi-values stay a joined
string. On cancel/error, no JSON is emitted. New `tp_json_emit` helper (awk);
the outer interpreter's success path calls it instead of `cat`-ing the result
file. No internal record change (an output-format concern). Tests:
`t/26-json.sh` (10 assertions); full suite 26 files green.

### Configurable color — `--label-color` / `--default-color` / `--theme` (Tier 2, 0.4.0)

Make the prompt-label and default-hint colors configurable (0.2.0 hardcoded bold
cyan / dim yellow). `--label-color <spec>` and `--default-color <spec>` set them
globally; `--theme <name>` (`default`, `dark`, `light`, `high-contrast`) bundles
both. A spec is a named color with optional styles (`bold red`), or a raw SGR
string (`1;31`). C `label-color=`/`default-color=` keys override per spec. The
on/off `--color` switch still gates everything. New `tp_color_spec` helper
(named→CSI). Internal spec record grows 11 → 13 fields (+ `label-color`,
`default-color`); `--print-spec` prints thirteen columns; the color options are
passed to the popup inner process. Defaults unchanged. Tests: `t/27-color-config.sh`
(10 assertions); full suite 27 files green.

### `--save` / `--load` (Tier 2, 0.4.0) — Tier 2 complete

`--save <file>` writes this run's `name=value` answers to `<file>` on success
(atomic: temp + rename). Secrets are skipped (with a stderr warning) unless
`--save-secrets` is given. `--load <file>` reads a prior `name=value` file
(`#` comments and blank lines ignored) and pre-fills defaults for matching names.
Precedence: typed answer > loaded value > spec `default`. A missing `--load` file
is a silent no-op; a missing parent directory or non-writable `--save` target is a
hard error (exit non-zero, no stdout). `--json` and `--save` are mutually
exclusive (the save file is always `name=value`). New `tp_save` helper (atomic
write + secret filtering cross-referencing the spec's secret flag); `--load`
overrides the spec default field (field 3) in `TP_SPEC` via awk before collect.
No internal record change. Tests: `t/28-save-load.sh` (15 assertions); full suite
28 files green. **Tier 2 (0.4.0) complete: --header, --width/--height, --json,
configurable color, --save/--load.**

### `preview` — B `pv:` prefix / C `preview=` (Tier 3, 0.5.0)

A per-spec fzf `--preview` command. Set via a B `pv:`-prefixed field at **any**
position (parallel to `qr:`, position-independent) or a C `preview=<cmd>` key.
`<cmd>` has `{}` substituted with the current item. Only effective when the
picker is fzf; the numbered picker and external command ignore it, and if fzf is
absent the preview is silently ignored. A spec may carry both a values list and a
preview. Internal spec record grows 13 → 14 fields (+ `preview`); `--print-spec`
prints fourteen columns. Resolves the review's §7.1 correction: preview works for
**both** B and C specs (not C-only). Tests: `t/29-preview.sh` (10 assertions);
full suite 29 files green.

### `--multiline` / `--sentinel` + C `multiline=`/`sentinel=` (Tier 3, 0.5.0)

Read a multi-line block until a sentinel line (default `.`; `--sentinel <s>` sets
it, `--sentinel ''` = EOF-terminated). Blank lines are part of the block; the
sentinel is excluded. C `multiline=1`/`sentinel=` per spec. Values-list inputs
ignore it. The value may contain embedded newlines — `--json` escapes them.

**Result-file protocol change:** records (and `TPROMPT_ERROR:` markers) in the
internal result file are now NUL-terminated instead of newline-terminated, so a
multi-line value does not inflate the line count and break the success/cancel
check. The outer interpreter counts NULs (== spec count) for success, detects
markers via `awk RS=\000`, and emits via `tr \000 \n`; `tp_json_emit` uses
`RS=\000`; `tp_save` converts NUL→\n. Existing single-line behavior is unchanged.
Internal spec record grows 14 → 16 fields (+ `multiline`, `sentinel`);
`--print-spec` prints sixteen columns. Tests: `t/30-multiline.sh` (10
assertions); `t/15-internal-collect.sh` updated for the NUL result file; full
suite 30 files green.

### `--editor` / `file:` default (Tier 3, 0.5.0)

A `file:` prefix on the default (`file:` alone, or `file:<template>`) opens
`$VISUAL`/`$EDITOR` (or `vi`) on a temp file pre-filled with the template; the
saved content (one trailing newline trimmed) is the value. An empty result is
subject to `required`. If no editor is available it is a hard error. In scripted
mode the editor does not open — the template is the value. Multi-line values flow
through the NUL result protocol. No internal record change (detected from the
default prefix at collect time). Bug fixed during this commit: the editor +
multiline interactive branches skipped `tp_check_val`, so `required`/`--validate`
were not enforced for them — added the check to both. Tests: `t/31-editor.sh`
(10 assertions); full suite 31 files green.

### `--timeout` (Tier 3, 0.5.0)

Cancel the run after N seconds. A background `sleep N && kill -ALRM $$` arms a
SIGALRM trap that prints `tprompt: timed out after Ns` on stderr and exits
non-zero with no stdout (cancel semantics). It does not fire if all input arrives
in time (the EXIT trap kills the background sleep). The alarm is armed in
whichever process does the collect — the in-shell outer, or the popup inner (via
the `--timeout` arg on the re-entry command). Signal-based, so a blocked `read`
is interrupted on most systems; on systems where it is not, the timeout cannot
preempt the read (documented limitation). No internal record change. Tests:
`t/32-timeout.sh` (7 assertions — uses `sleep N | tprompt` to hold stdin open);
full suite 32 files green.

### `--history` (Tier 3, 0.5.0) — Tier 3 complete

`--history <file>` keeps a per-name recall file of `name=value` lines. Before
collecting, each input's default is set to the last prior value for its name in
the file (pre-fill via the same awk as `--load`, last-wins). On a successful run,
each input's `name=value` is appended (secrets skipped unless `--save-secrets`,
reusing the `tp_save` filtering). A missing file is a no-op for pre-fill and is
created on append. Full fzf Ctrl-R search across all prior values is deferred —
this MVP recalls the last value per name. No internal record change. Tests:
`t/33-history.sh` (10 assertions); full suite 33 files green. **Tier 3 (0.5.0)
complete: preview, --multiline, --editor, --timeout, --history. All 15
next-round features implemented.**

## 0.2.0 — 2026-11-21

Secret input, color, and multi-value.

- **Secret (hidden) input.** A leading `*` on the name marks the input as
  secret: entry is hidden (`stty -echo`), the default is not shown in the prompt,
  and the `*` is stripped so the output key is the bare name. Works in B
  (`'*pw|Password:'`) and C (`name=*pw` or `secret=1`). Output is still cleartext
  `pw=…` — tprompt hides *entry*, not the captured value.
- **`--color[=always|auto|never]`.** Colorizes the prompt label (bold cyan) and
  the default hint (dim yellow) on stderr. Bare `--color` = `always`; default
  `auto` (on when stderr is a tty and `NO_COLOR` is unset). A `values` list may
  carry ANSI codes — they are rendered in the picker (fzf `--ansi`, or echoed
  raw for the numbered list) and **stripped from the output**, so `name=value`
  is always plain text.
- **Multiple values.** `--multi` makes every values-list input multi-select; C
  gains a per-spec `multi=1` key. Interactive fzf uses `--multi`; the numbered
  picker reads a comma-separated line of indices *or* literal values. Selected
  values are joined with the `--sep <char>` separator (default `,`; multi-char
  separators like `'; '` accepted; `--separator` is a long alias). Scripted mode
  takes the answer line verbatim. So `a,b,d` is the output whether the user
  typed it or selected it.
- Internal spec record grew from 4 fields to 6 (`name`, `prompt`, `default`,
  `values`, `secret`, `multi`); `--print-spec` prints all six. The tmux popup
  re-entry passes `--sep` and (when explicit) `--color`.
- Test suite: 18 files, ~90 assertions, no tmux/fzf required.

## 0.1.0 — 2026-11-19

Initial standalone release.

- Two spec forms: B (positional `name|prompt|default[|values]`) and C (stdin
  `key=value` lines, blank-separated).
- `$VAR` / `${VAR}` environment expansion in `default`, `values`, `prompt`;
  C also has explicit `default-env=` / `values-env=` keys.
- Render modes: `--in-shell` (default), `--new-shell`, `--popup` (tmux
  `display-popup`). `--no-tmux` for silent fallback; dynamic default (popup
  when inside tmux, else in-shell).
- Picker for values-lists: `fzf` (default when installed), `numbered`,
  external `<cmd>`. `--no-fzf` forces numbered.
- Interaction: `--interactive` / `--scripted` (auto from tty-ness). Interactive
  prompts each input in one persistent session; scripted reads answer lines
  (B) or uses defaults (C).
- Output: one `name=value` line per input, in order, on stdout; prompts/numbered
  list on stderr. Cancel and error exit non-zero with no stdout.
- `--internal-collect <specfile> <resfile>` mode for tmux popup re-entry.
- `--print-spec` debug mode (normalize + env-expand, readable output).
- `--help`/`-h`, `--version`/`-V`.
- Test suite: 15 files, ~70 assertions, no tmux/fzf required (`sh t/run.sh`).
- Docs: README, DESIGN, docs/usage, docs/examples, docs/integration, manpage
  (roff + markdown), runnable demo.
