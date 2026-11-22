# tprompt — design

## Goal

A prompting utility that collects one or more named inputs from a user and
prints `name=value` lines. Standalone (no tum dependency); tmux-optional;
fzf-optional. It exists so a caller (tum, or any tool) can fill
`{{placeholders}}` without baking prompt logic into itself.

## Identity

- One binary, `tprompt`, POSIX `sh` + `awk`. No runtime deps beyond those.
- Optional `fzf` (nicer values-list picking) and `tmux` (`--popup`). Both
  degrade gracefully when absent.
- Invoked two ways: **B** (positional `'name|prompt|default[|values]'` args)
  and **C** (a `key=value` spec on stdin, blank-line separated). No file mode —
  a caller that owns a definition file parses it and passes inputs as B/C.

## Contract

- **Input:** B specs on argv, or C specs on stdin (entered when stdin is not a
  tty and no B positionals are given).
- **Output:** one `name=value` line per input, in order, on stdout. The first
  `=` splits name from value; ANSI color codes are stripped from the value, so
  the output is plain text even when the choices were colored in the picker.
- **Cancel:** Esc in fzf, EOF/Ctrl-D on a prompt, or a malformed spec → exit
  non-zero, **no stdout**.
- **Secret:** a leading `*` on the name hides entry (the `*` is stripped from
  the key); the value is still printed cleartext.
- **Multi:** `--multi` (or C `multi=1`) lets a values-list input yield several
  values joined with `--sep` (default `,`).
- **Env expansion:** `$VAR` and `${VAR}` are expanded in `default`, `values`,
  and `prompt` from the environment (awk `ENVIRON`). C also has explicit
  `default-env=VAR` / `values-env=VAR` keys.

## Interaction modes

A run is either **interactive** (stdin is a tty, or `--interactive`) or
**scripted** (stdin is a pipe, or `--scripted`).

- **Interactive:** each input is prompted. A values-list input uses the picker
  (fzf/numbered/external); a free-text input is a `read` with the default
  pre-filled (empty answer ⇒ default). One persistent session loops through all
  inputs — no flicker between inputs.
- **Scripted (B):** one answer line is read per input from stdin; empty ⇒
  default; EOF ⇒ default (if any) else error.
- **Scripted (C):** the spec itself is the whole stdin; defaults (+ env) are
  used as-is, no prompting. An input with no resolvable default ⇒ error.

This split makes tprompt both a UI (interactive) and a scriptable transformer
(C with defaults), and it makes the test suite fully pipe-driven (no pty
needed): `--interactive --picker numbered` with piped indices exercises the
picker, and `--scripted` with piped lines exercises the answer path.

## Render modes

| mode | where it runs | requires |
| --- | --- | --- |
| `--in-shell` | the current process, reading stdin | nothing |
| `--popup` | a tmux `display-popup`, re-entering `tprompt --internal-collect` | tmux + inside a tmux session |
| `--new-shell` | `--popup` if tmux available, else `--in-shell` | tmux (optional) |

Default is dynamic: `--popup` when `$TMUX` is set and `tmux` exists, else
`--in-shell`. `--no-tmux` forces non-tmux silently (no warning); `--popup`
without tmux prints one stderr line and falls back to `--in-shell`.

The popup re-enters tprompt with `--internal-collect <specfile> <resfile>`: the
outer process normalizes specs into a spec file, runs the inner tprompt in the
popup, the inner collects into a result file, and the outer interprets it
(success ⇒ `cat` to stdout; cancel ⇒ empty result, exit 1; error ⇒ a
`TPROMPT_ERROR:` marker line, exit 1). The result file is the channel because
`tmux display-popup -E` does not reliably return the inner exit code.

## Picker

A values-list input (B's 4th `|`-field, or C's `values=`) is chosen via the
picker:

- `fzf` (default if installed): `printf lines | fzf --prompt=...`.
- `numbered`: a numbered list is printed to stderr, the user enters an index on
  stdin; out-of-range / non-numeric / empty / EOF ⇒ cancel.
- `<cmd>` (external): `printf lines | <cmd>`, first line of stdout is the pick.

The numbered list and prompts go to **stderr**; only the final `name=value`
lines go to **stdout**. This keeps stdout clean for the caller.

## Secret input

A leading `*` on the name marks the input as secret. Entry is hidden with
`stty -echo` (POSIX `read` has no `-s`), the default is **not** shown in the
prompt (showing `[s3cr3t]` would leak it), and the `*` is stripped so the
output key is the bare name. An EXIT/INT/TERM/HUP trap re-enables echo so an
interrupted prompt cannot leave the terminal silent. The output is still
cleartext — tprompt hides *entry*, not the captured value; the caller reads the
value into a variable. In scripted mode (stdin not a tty) `stty -echo` is
skipped (it would fail) and the value is read verbatim from the pipe, same as
any input.

## Color

`--color[=always|auto|never]` colorizes the prompt label (bold cyan) and the
default hint (dim yellow) on **stderr**. Default `auto`: on when stderr is a
tty and `NO_COLOR` is unset (mirrors tum's `--color` for consistency across the
tool family). A `values` list may carry ANSI codes — they are rendered in the
picker (fzf `--ansi`, or echoed raw for the numbered list so the terminal
renders them) and **stripped from the output** by an `awk` CSI-sequence filter,
so `name=value` is always plain text even when the choices were colored in the
UI. The filter runs on every emitted value (a no-op for plain text).

## Multiple values

`--multi` makes every values-list input multi-select; C's `multi=1` key marks
one input. A free-text input (no values list) is unaffected — the user already
types freely. Three paths:

- **fzf:** `fzf --multi --ansi`; selected lines (newline-joined) are joined with
  the separator.
- **numbered:** the list is printed; a comma-separated line is read. Each token
  is an index (a number in range → the value at that index) or a literal value
  (taken verbatim). So `1,3` or `a,b,d` both work — the user can type the
  values themselves, which is the no-tmux path the request called out.
- **scripted:** the answer line is taken verbatim — pipe `a,b,d`, get
  `name=a,b,d`. No picker.

`--sep <char>` (default `,`; multi-char accepted; `--separator` alias) is the
output join separator. A value that itself contains the separator is a caller
error (the join is unambiguous only if values do not contain the separator).
The `multi` flag is encoded in the record at normalize time, so the popup
inner process does not need `--multi` re-passed; `--sep` and (when explicit)
`--color` are passed on the re-entry command.

## Cancel & error semantics

Three terminal states, all with no stdout on failure:

| state | result file | exit |
| --- | --- | --- |
| success | N `name=value` lines (one per spec) | 0 |
| cancel | partial/empty, no `TPROMPT_ERROR:` marker | 1 |
| error | contains a `TPROMPT_ERROR:<msg>` line | 1 |

The outer interpreter counts non-empty spec records (N) and result lines (M):
`M == N` and no marker ⇒ success; marker ⇒ error (message to stderr); else ⇒
cancel. Partial results are never emitted on stdout.

## Internal spec format

Normalized specs are stored as records separated by newlines, fields by the
ASCII Unit Separator (`\x1f`, 0x1F). A non-whitespace delimiter is required
because `read` with a whitespace IFS coalesces consecutive delimiters and loses
empty fields (an empty prompt field would otherwise eat the default). Sixteen
fields: `name`, `prompt`, `default`, `values`, `secret`, `multi`, `trim`,
`required`, `validate`, `validate-error`, `retry`, `label-color`, `default-color`, `preview`, `multiline`, `sentinel` (already env-expanded at normalize
time, so the popup inner process sees the caller's environment regardless of the
tmux server env). `secret` and `multi` are `1`/`0` booleans set at normalize
time: `secret` from a leading `*` on the name (B and C) or the C `secret=1` key;
`multi` from the C `multi=1` key or the global `--multi` flag applied to every
record. `trim` is the per-spec override (`""` inherit, `1` force on, `0` force
off; B emits `""`); resolution is per-spec → global `--trim`/`--no-trim` →
default policy (off for secrets, on otherwise). `required` is `1`/`0` from a
leading `!` on the name (B and C) or the C `required=1` key (the key overrides
the prefix). `validate` is the per-spec POSIX ERE (from a B `qr:`-prefixed field
at any position — the B parser is awk-based and scans all `|`-fields — or C
`validate=`); `validate-error` is the per-spec mismatch message. The global
`--validate`/`--validate-error` apply to free-text inputs only (values-list picks
are exempt unless a per-spec regex constrains them). `retry` is the per-spec
override (C `retry=<n>`; B emits `""`); the global `--retry` wraps the
interactive free-text read+check loop. `label-color`/`default-color` are
per-spec color specs (C keys; B emits `""`) resolved via `tp_color_spec` to
ANSI CSIs, overriding the global `--label-color`/`--default-color`/`--theme`.
`--print-spec` reformats these to readable sixteen-column tab-separated output.
The internal **result file** is NUL-terminated per record (not newline), so a
multi-line value (`--multiline`/`--editor`) does not inflate the line count; the
outer interpreter counts NULs for the success/cancel check, detects
`TPROMPT_ERROR:` markers via `awk RS=\000`, and emits via `tr \000 \n`.

## Fallback when tprompt is absent (caller's concern)

A caller (tum) that uses tprompt should fall back to its own simple `read` when
`tprompt` is not on `$PATH`. In tum's case the fallback `read` may run in a pane
that has no interactive shell behind it; tum can **swap a shell in** for the
duration of the read using its `tum swap` primitive, then swap back —
guaranteeing the `read` always has somewhere to land. That is the caller's
responsibility; tprompt itself just prompts.

## Next round (0.3.0+)

The next-round feature set is specified in
[docs/next-round-design.md](docs/next-round-design.md): fifteen features in
three tiers. Tier 1 (0.3.0) — `required`, `--validate` (with B `qr:` prefix),
`--retry`, `--trim`/`--no-trim`, `--specs-from`. Tier 2 (0.4.0) — configurable
color, `--json`, `--save`/`--load`, `--header`, `--width`/`--height`. Tier 3
(0.5.0+) — `preview` (B `pv:` prefix + C `preview=` key), `--editor`,
`--multiline`, `--timeout`, `--history` (fzf primary, rlwrap optional). Each
feature extends the six-field record and the option loop; the design doc is
updated per feature as it lands, and implementation notes live in
[docs/working-next-round.md](docs/working-next-round.md).

## Open design questions (carried from the design doc)

1. Env syntax: `$VAR` expansion in default/values/prompt + `default-env=`/
   `values-env=` — **implemented**.
2. Default render mode = dynamic (popup→in-shell) — **implemented**.
3. Fallback swap target (dedicated prompt-shell vs. reuse any hidden shell) —
   the caller's call; not tprompt's concern.
4. Language: POSIX sh + awk — **implemented**.
5. Secret input — **implemented (0.2.0).** `*` prefix on the name; `stty -echo`;
   default hidden; output cleartext. C `secret=1` key.
6. Color — **implemented (0.2.0).** `--color[=always|auto|never]`; label/default
   colored on stderr; ANSI in values rendered in the picker + stripped from
   output.
7. Multiple values — **implemented (0.2.0).** `--multi` + C `multi=1`; `--sep`;
   fzf `--multi`; numbered comma-select (indices or values); scripted verbatim.

See `docs/working-secret-color-multi.md` for the design notes behind 5–7 and
thirty further usability suggestions.
