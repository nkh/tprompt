# tprompt — working document: next-round features (0.3.0+)

> **Status:** in-progress. Companion to
> [next-round-design.md](next-round-design.md). Records the baseline, the
> record-schema evolution, and per-feature implementation notes as each feature
> lands. The manpage, DESIGN.md, README, CHANGELOG, and docs/usage.md are
> updated alongside each feature.

## 1. Baseline (0.2.0)

Single POSIX `sh` + `awk` script (494 lines), standalone, tmux-optional,
fzf-optional. Internal record: six `\x1f`-delimited fields — `name`, `prompt`,
`default`, `values`, `secret`, `multi` (env-expanded at normalize time). Test
suite: 18 files, all green (`sh t/run.sh`). See [../DESIGN.md](../DESIGN.md)
and [working-secret-color-multi.md](working-secret-color-multi.md) for the 0.2.0
foundation.

## 2. Record-schema evolution

Each Tier-1 feature extends the six-field record with its own field(s); the
readers and writers (`tp_parse_c`, the B positional parser, `tp_collect`, and
`--print-spec`) are updated alongside. New fields are appended at the tail so
the one-based `read` in `tp_collect` and the `--print-spec` formatter stay
consistent within a tier.

Planned additions:

- **Tier 1:** `trim`, `required`, `validate`, `validate_error`, `retry`.
- **Tier 2:** `label_color`, `default_color` (color); output-format and
  save/load are emit/storage concerns (no record fields); `header` is global.
- **Tier 3:** `preview` (B `pv:` prefix + C `preview=` key); `type` (editor) /
  `multiline` + `sentinel`; `--timeout` and `--history` are global/runtime.

## 3. Per-feature implementation notes

Filled in as each feature lands. Each entry records the record-field addition
(if any), the code seams touched, the test file added, and the cross-references
updated.

### 0.3.0 Tier 1

#### `--specs-from <file>` — implemented

No record-field change (a new B-spec source, not a per-spec attribute). New
option `--specs-from <file>` / `--specs-from=<file>` reads B specs from the
file (one per line; `#` comments and blank lines skipped) into `TP_BSPECS`,
after the option loop and before the mode/source derivation. Mutually exclusive
with positional specs (hard error); a missing, unreadable, or spec-free file is
a hard error (exit 1). Combines with C unchanged (stdin is the scripted-B
answer pipe or the interactive tty). Seams touched: the option loop, the
post-loop `--specs-from` block, and `tp_usage`. Tests: `t/19-specs-from.sh`
(9 assertions). Docs: manpage (md + roff), docs/usage.md, README, CHANGELOG.

#### `--trim` / `--no-trim` + C `trim=` — implemented

Record extended from six to seven fields: `name`, `prompt`, `default`, `values`,
`secret`, `multi`, `trim`. The `trim` field is the per-spec override (`""`
inherit, `1` force on, `0` force off); B emits `""` (no B trim syntax). New
helpers `tp_trim_ws` (awk `gsub` on leading/trailing spaces/tabs) and
`tp_trim_resolve` (per-spec > `TP_TRIM_GLOBAL` > default policy, where the
default policy is off for secrets and on otherwise). `--trim`/`--no-trim` set
`TP_TRIM_GLOBAL`; the flag is passed to the popup inner process via the re-entry
command. Trim runs in `tp_collect` after the read and before the ANSI strip
(where `required`/`--validate` will slot in, in later commits). `--print-spec`
now prints seven columns. This is a behavior change from 0.2.0 (which did not
trim) — default-on for non-secrets; `--no-trim` restores the old behavior.
Seams: option loop, `tp_usage`, B + C parsers, `tp_collect`, `--print-spec`,
popup re-entry. Tests: `t/20-trim.sh` (11 assertions); `t/19-specs-from.sh`
updated for the 7-column print-spec. Docs: manpage (md + roff), docs/usage.md,
README, CHANGELOG, DESIGN.md.

#### `required` — `!` prefix / C `required=1` — implemented

Record extended from seven to eight fields: `name`, `prompt`, `default`,
`values`, `secret`, `multi`, `trim`, `required`. A leading `!` on the name
marks the field required (parallel to `*` for secret); the B parser strips
leading `*`/`!` in a loop (so `*!pw`, `!*pw`, `!host` all work). The C parser
strips `*`/`!` in `flush()` but only sets the flag when the corresponding key
(`secret=`/`required=`) was not explicitly given (`rs_set`/`rr_set`) — so an
explicit key always overrides the prefix regardless of key/prefix order.
`tp_read_value` gained a `required` parameter: on empty input it leaves
`TP_VAL` empty (default **not** applied) so the downstream required check
catches it. `tp_collect` checks required after trim and before the no-value
check: scripted empty → `TPROMPT_ERROR:required field '<name>' is empty`
(rc 2 inner → exit 1 outer); interactive empty → cancel (rc 1; the `--retry`
loop will wrap this). The no-value check is now scoped to non-interactive
(scripted-B) so interactive empty-without-default still emits an empty value
(0.2.0 behavior preserved). `--print-spec` prints eight columns. Seams: B + C
parsers, `tp_read_value`, `tp_collect`, `--print-spec`, `tp_usage`. Tests:
`t/21-required.sh` (19 assertions); `t/19`/`t/20` print-spec checks made
column-robust. Docs: manpage (md + roff, +REQUIRED INPUT), docs/usage.md
(+Required input), README, CHANGELOG, DESIGN.md (record 7→8).

#### `--validate` / B `qr:` / C `validate=` + `validate-error=` — implemented

Record extended from eight to ten fields: `name`, `prompt`, `default`, `values`,
`secret`, `multi`, `trim`, `required`, `validate`, `validate-error`. The B
positional parser is now **awk-based** (was `IFS='|' read -r n p d v`): it
`split`s the spec on `/[|]/` (which preserves empty fields, verified on mawk),
scans every field for a `qr:` prefix → that field is the validate regex
(position-independent), and fills name/prompt/default/values from the remaining
fields in order. So a spec can carry both a values list and a regex
(`port|port|22|22,80,443|qr:^[0-9]+$`). The C parser gained `rv`/`rve` vars +
`validate`/`validate-error` keys. New global options `--validate <re>` /
`--validate-error <msg>` (passed to the popup inner process). `tp_collect`
resolves the effective regex: per-spec `validate` if set, else global
`--validate` **but only for free-text inputs** (values-list picks are exempt
unless a per-spec `qr:`/`validate=` constrains them — then the picked value is
checked). The check runs after `required` and before the no-value check, on the
final value (non-empty only — empty answers skip validation). Mismatch →
`TPROMPT_ERROR:<msg>` (scripted) / cancel + stderr hint (interactive); the
`--retry` loop will turn the cancel into a re-prompt. The match is
`awk -v re=... '{exit ($0~re?0:1)}'` (POSIX ERE; no backreferences/lookahead).
`--print-spec` prints ten columns. **Bug found+fixed during this commit**: the
awk B parser initially had `"$TP_EXPAND_AWK" '<block>'` (space) — awk treated
the block as a filename; fixed to `"$TP_EXPAND_AWK"'<block>'` (adjacent, as
`tp_parse_c` does). Seams: option loop, `tp_usage`, B + C parsers, `tp_collect`,
`--print-spec`, popup re-entry. Tests: `t/22-validate.sh` (19 assertions); full
suite 22 files green. Docs: manpage (md + roff, +VALIDATION), docs/usage.md
(+Validation), README, CHANGELOG, DESIGN.md (record 8→10).

#### `--retry` / C `retry=` — implemented (Tier 1 complete)

Record extended from ten to eleven fields: `name`, `prompt`, `default`,
`values`, `secret`, `multi`, `trim`, `required`, `validate`, `validate-error`,
`retry`. `tp_collect`'s interactive free-text path is now a retry loop; the
required + validate checks are factored into a new `tp_check_val` helper (sets
`TP_REASON`, returns 0 valid / 1 invalid) so the loop and the scripted/C paths
share one check. Resolution: per-spec `retry` if set, else global `TP_RETRY`
(default 0). On failure with attempts remaining, print
`<reason>; try again (n left)` to stderr and re-prompt; else cancel (rc 1).
Values-list picks are one-shot (no retry). Scripted mode prints a stderr notice
if `--retry > 0` (no re-prompt loop over a pipe). `--print-spec` prints eleven
columns; `--retry` passed to the popup inner process. **Tier 1 (0.3.0) is
complete: required, --retry, --validate (+qr:), --trim, --specs-from.** Seams:
option loop, `tp_usage`, B + C parsers, `tp_check_val` (new), `tp_collect`
(retry loop), `--print-spec`, popup re-entry. Tests: `t/23-retry.sh`
(15 assertions); full suite 23 files green. Docs: manpage (md + roff, +RETRY),
docs/usage.md (+Retry), README, CHANGELOG, DESIGN.md (record 10→11),
docs/working-next-round.md.

### 0.4.0 Tier 2

#### `--header` / `--header-file` — implemented

No record-field change (a global display option). New options `--header <text>`
/ `--header-file <path>` (plus `=` forms). `--header-file` is read into
`TP_HEADER` at startup (after the `--specs-from` block); `--header` and
`--header-file` are mutually exclusive (hard error); a missing/unreadable file
is a hard error. In `tp_collect`, the banner is printed to stderr once before the
read loop, colored via `tp_color_name` (label color) when `--color` is on. The
fzf picker passes `--header="$TP_HEADER"` (empty = no header). The banner is
passed to the popup inner process via `--header <shell-quoted>` on the re-entry
command. Seams: option loop, `tp_usage`, post-loop header-file block,
`tp_collect` (banner), `tp_pick_value` (fzf --header), popup re-entry. Tests:
`t/24-header.sh` (10 assertions); full suite 24 files green. Docs: manpage
(md + roff, +HEADER), docs/usage.md (+Header), README, CHANGELOG.

#### `--width` / `--height` / `--auto-size` — implemented

No record-field change (popup dimensions only). New options `--width <n>` /
`--height <n>` (default 80×20) and `--auto-size`. The popup re-entry uses
`-w "$TP_WIDTH" -h "$TP_HEIGHT"`; `--auto-size` computes both from the spec file
via awk (max prompt+default+longest-value width + padding; input count + 6 for
height), capped at `tput cols`/`tput lines` (fallback 80×24). In-shell mode
ignores them (no popup). `--width`/`--height` validate as positive integers.
Seams: option loop, `tp_usage`, popup re-entry (autosize block + `-w`/`-h`).
Tests: `t/25-width-height.sh` (8 assertions — parsing + validation; the
dimensional effect is only observable inside a tmux popup); full suite 25 files
green. Docs: manpage (md + roff), docs/usage.md (+Popup dimensions), README,
CHANGELOG.

#### `--json` / `--json-array` — implemented

No record-field change (an output-format concern, handled by the outer
interpreter). New options `--json` (JSON Lines) and `--json-array` (single JSON
array; implies `--json`). New helper `tp_json_emit` (awk) reads the result
file's `name=value` lines and emits `{"name":"…","value":"…"}` objects with
JSON escaping of `"`, `\`, and `\t`/`\n`/`\r`/`\b`/`\f`. The outer interpreter's
success path calls `tp_json_emit lines` or `tp_json_emit array` instead of
`cat`-ing the result file; cancel/error paths still emit no stdout. Secrets are
cleartext; multi-values stay a joined string. **Bug fixed during this commit**:
the array END initially printed `""` (missing the closing `]`); fixed to
`print "]"`. Seams: option loop, `tp_usage`, `tp_json_emit` (new), outer
interpreter. Tests: `t/26-json.sh` (10 assertions); full suite 26 files green.
Docs: manpage (md + roff, +JSON OUTPUT), docs/usage.md (+JSON output), README,
CHANGELOG.

#### Configurable color — `--label-color` / `--default-color` / `--theme` — implemented

Record extended from eleven to thirteen fields: `name`, `prompt`, `default`,
`values`, `secret`, `multi`, `trim`, `required`, `validate`, `validate-error`,
`retry`, `label-color`, `default-color`. New helper `tp_color_spec` resolves a
color spec (named `bold red` / `cyan`, or raw SGR `1;31`) to an ANSI CSI; it
detects raw specs by checking for letters (`*[a-zA-Z]*`) — a `;` in a case
pattern would terminate it, so the letter test avoids that trap. `tp_color_resolve`
now also resolves the global label/default CSIs from `--label-color`/
`--default-color`/`--theme` (themes: default=bold cyan/dim yellow, dark=bold
blue/dim white, light=blue/black, high-contrast=bold white/bold white), defaulting
to the 0.2.0 hardcoded CSIs. `tp_color_name`/`tp_color_default` use
`TP_LABEL_CSI`/`TP_DEFAULT_CSI` (was hardcoded `TP_C_NAME`/`TP_C_DEFAULT`).
`tp_collect` resets `TP_LABEL_CSI`/`TP_DEFAULT_CSI` per record from the global
(`_G`) then overrides from per-spec `label_color`/`default_color`. The options
are passed to the popup inner process. B emits `""` for both fields. **Bug fixed
during this commit**: `*[!0-9;]*` in a case pattern — the `;` terminates the
pattern (syntax error); replaced with `*[a-zA-Z]*`. Seams: `tp_color_spec` (new),
`tp_color_resolve` (extended), `tp_color_name`/`tp_color_default`, option loop,
`tp_usage`, B + C parsers, `tp_collect` (per-record CSI), `--print-spec`,
popup re-entry. Tests: `t/27-color-config.sh` (10 assertions); full suite 27
files green. Docs: manpage (md + roff), docs/usage.md (Color section), README,
CHANGELOG, DESIGN.md (record 11→13).

#### `--save` / `--load` — implemented (Tier 2 complete)

No record-field change (a persistence/pre-fill concern). New options `--save
<file>`, `--load <file>`, `--save-secrets` (plus `=` forms). `--load` (after spec
normalization, before the no-specs check) overrides the spec default field
(field 3) in `TP_SPEC` for names present in the load file (`awk NR==FNR` build a
lookup, then `$3 = lv[$1]`); `#` comments and blank lines skipped; a missing
file is a silent no-op. New `tp_save` helper: writes the result file atomically
(mktemp + mv) to the save path; the parent dir must exist and be writable (hard
error otherwise); secrets are filtered out (cross-referencing `TP_SPEC` field 5
== 1) with a per-field stderr warning, unless `--save-secrets`. `--save` runs in
the outer interpreter's success path BEFORE the stdout emit, so a save failure
exits non-zero with no stdout. `--json` + `--save` are mutually exclusive (the
save file is always `name=value`). Seams: option loop, `tp_usage`, `tp_save`
(new), `--load` block (new), `--json`/`--save` exclusion, outer interpreter.
Tests: `t/28-save-load.sh` (15 assertions); full suite 28 files green. Docs:
manpage (md + roff, +SAVE/LOAD), docs/usage.md (+Save/load), README, CHANGELOG.
**Tier 2 (0.4.0) complete: --header, --width/--height, --json, configurable
color, --save/--load.**

#### `preview` — B `pv:` prefix / C `preview=` — implemented

Record extended from thirteen to fourteen fields: `name`, `prompt`, `default`,
`values`, `secret`, `multi`, `trim`, `required`, `validate`, `validate-error`,
`retry`, `label-color`, `default-color`, `preview`. The B parser awk now also
scans for a `pv:`-prefixed field (alongside `qr:`), position-independent — so a
spec can carry values + qr: + pv: all at once. The C parser gained `rpv` + the
`preview` key. `tp_collect` sets `TP_PREVIEW` per record; `tp_pick_value`'s fzf
path adds `--preview="$TP_PREVIEW"` (a `mf` flag consolidates the `--multi`
toggle, avoiding the duplicated fzf line). Numbered/external pickers ignore it;
fzf-absent → silently ignored. Resolves the review's §7.1 correction: preview
works for **both** B (`pv:`) and C (`preview=`), not C-only. `--print-spec`
prints fourteen columns. Seams: B + C parsers, `tp_collect` (TP_PREVIEW),
`tp_pick_value` (fzf --preview), `--print-spec`. Tests: `t/29-preview.sh`
(10 assertions — parsing + numbered-picker-ignores; the fzf --preview path needs
a real fzf + tty); full suite 29 files green. Docs: manpage (md + roff, +PREVIEW,
B form pv:, C keys preview), docs/usage.md (+Preview, B form pv:, print-spec 14),
CHANGELOG, DESIGN.md (record 13→14).

#### `--multiline` / `--sentinel` + C `multiline=`/`sentinel=` — implemented

Record extended from fourteen to sixteen fields: `name`, `prompt`, `default`,
`values`, `secret`, `multi`, `trim`, `required`, `validate`, `validate-error`,
`retry`, `label-color`, `default-color`, `preview`, `multiline`, `sentinel`. New
helper `tp_read_block` reads stdin until a sentinel (or EOF if sentinel empty),
joining lines with real newlines (sentinel excluded; blank lines kept). `tp_collect`
gains a multiline branch in both the interactive free-text path (prompt + block,
no retry loop) and the scripted-B path (block from stdin). Effective
multiline/sentinel = per-spec if set, else global `TP_MULTILINE`/`TP_SENTINEL`
(default `.`); both passed to the popup inner process. Values-list inputs ignore
multiline.

**Result-file protocol change (NUL-separated):** multi-line values span multiple
lines, which broke the outer interpreter's line-count success check (`grep -c .
== N`). Records and `TPROMPT_ERROR:` markers in the result file are now
NUL-terminated (`\000`) instead of newline-terminated. The outer interpreter:
marker check via `awk 'BEGIN{RS="\000"} /^TPROMPT_ERROR:/'`; success check via
`tr -cd '\000' | wc -c == N`; output via `tr '\000' '\n'`. `tp_json_emit` uses
`RS="\000"`. `tp_save` converts NUL→\n before filtering. Existing single-line
behavior is unchanged (one NUL per record). `--print-spec` prints sixteen columns.
Seams: `tp_read_block` (new), `tp_collect` (multiline branches + NUL emit),
`tp_check_val`/markers (NUL), outer interpreter (NUL checks + tr), `tp_json_emit`
(RS), `tp_save` (tr), B + C parsers, `--print-spec`, popup re-entry. Tests:
`t/30-multiline.sh` (10 assertions); `t/15-internal-collect.sh` updated for the
NUL result file; full suite 30 files green. Docs: manpage (md + roff, +MULTILINE),
docs/usage.md (+Multiline), README, CHANGELOG, DESIGN.md (record 14→16 + NUL
protocol).

#### `--editor` / `file:` default — implemented

No record-field change (detected from the default prefix at collect time). New
helper `tp_edit`: mktemp a file, write the template (text after `file:`), spawn
`"${VISUAL:-${EDITOR:-vi}}" "$tmp"` (hard error if `command -v` fails), read back
via `$(cat; printf X)`${X} to preserve trailing newlines, strip exactly one
trailing newline. `tp_collect` sets `editor_mode`+`template` when the default
starts with `file:`, and branches: interactive free-text → `tp_edit`; scripted B
→ `val="$template"` (no stdin read); C → `val="$template"`. **Bug fixed during
this commit**: the editor + multiline interactive branches skipped `tp_check_val`,
so `required`/`--validate` were not enforced for them — added trim + `tp_check_val`
to both (cancel on failure). Multi-line editor values flow through the NUL result
protocol. Seams: `tp_edit` (new), `tp_collect` (editor_mode detection + 3
branches + tp_check_val on editor/multiline), `tp_usage` (file: documented in
manpage/usage). Tests: `t/31-editor.sh` (10 assertions — uses fake `$EDITOR`
scripts; the real editor path needs a tty); full suite 31 files green. Docs:
manpage (md + roff, +EDITOR, B form file:), docs/usage.md (+Editor), README,
CHANGELOG.

#### `--timeout` — implemented

No record-field change (a global run-level concern). New option `--timeout <n>`
(validated positive integer). New helper `tp_alarm_arm`: when `TP_TIMEOUT > 0`,
spawns `( sleep "$TP_TIMEOUT" && kill -ALRM $$ ) &` in the background, sets an
ALRM trap (`echo ... >&2; exit 1`) and an EXIT trap (`kill $TP_TIMEOUT_PID`).
Called before `tp_collect` in BOTH the in-shell outer path and the
`--internal-collect` inner path (so the popup inner times out its own reads). The
popup re-entry command passes `--timeout $TP_TIMEOUT` to the inner. A timeout is
a cancel (no stdout). Does not fire if input arrives in time (EXIT trap reaps the
sleep). Signal-based: a blocked `read` is interrupted by ALRM on most systems;
documented limitation where it is not. Seams: option loop, `tp_usage`,
`tp_alarm_arm` (new), in-shell collect site, internal-collect site, popup
re-entry. Tests: `t/32-timeout.sh` (7 assertions — `sleep N | tprompt` holds
stdin open so the read blocks); full suite 32 files green. Docs: manpage (md +
roff, +TIMEOUT), docs/usage.md (+Timeout), README, CHANGELOG.

#### `--history` — implemented (Tier 3 complete)

No record-field change (a global persistence/recall concern). New option
`--history <file>`. Pre-collect (after the `--load` block): an awk (identical to
`--load`'s, last-wins) overrides each spec's default field with the last prior
value for its name from the history file; missing file = no-op. Post-collect
(on the outer interpreter's success path, after `--save`): append each
`name=value` to the history file (NUL→\n via `tr`, secrets filtered unless
`--save-secrets` via the same awk as `tp_save`); missing file is created by `>>`.
Full fzf Ctrl-R search across all prior values is **deferred** — this MVP recalls
the last value per name (documented in manpage/usage). Seams: option loop,
`tp_usage`, pre-fill block (after `--load`), outer interpreter (append after
`--save`). Tests: `t/33-history.sh` (10 assertions); full suite 33 files green.
Docs: manpage (md + roff, +HISTORY), docs/usage.md (+History), README, CHANGELOG.
**Tier 3 (0.5.0) complete. All 15 next-round features implemented: --specs-from,
--trim, required, --validate/+qr:, --retry (Tier 1); --header, --width/--height,
--json, configurable color, --save/--load (Tier 2); preview, --multiline,
--editor, --timeout, --history (Tier 3).**

### 0.5.0+ Tier 3

_(pending)_
