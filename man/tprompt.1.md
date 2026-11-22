# tprompt 1 — manpage source

This is the markdown source for `tprompt.1` (rendered to roff in
`../tprompt.1`). It mirrors [../docs/usage.md](../docs/usage.md) in man form.

## NAME

tprompt — prompt for named inputs, print name=value lines

## SYNOPSIS

```
tprompt [-h|-V]
        [--in-shell|--new-shell|--popup]
        [--interactive|--scripted]
        [--picker fzf|numbered|cmd]
        [--no-tmux] [--no-fzf]
        [--color[=always|auto|never]]
        [--multi] [--sep char] [--trim|--no-trim] [--validate re] [--retry n] [--header text] [--width n] [--height n] [--auto-size] [--json] [--json-array]
        [--label-color spec] [--default-color spec] [--theme name] [--save file] [--load file] [--multiline] [--sentinel s] [--timeout n] [--history file] [--print-spec] [--specs-from file]
        [spec ...]
```

## DESCRIPTION

**tprompt** collects one or more named inputs and prints one `name=value` line
per input, in order, to stdout. It is standalone (no tum dependency),
tmux-optional, and fzf-optional.

Inputs are described in one of two forms:

- **B (positional):** each argument is `name|prompt|default[|values]`.
  Repeatable for multiple inputs. A leading `*` on the name marks a secret
  (hidden entry); a leading `!` marks a required field (an empty answer is an
  error). The prefixes combine (`*!` or `!*`) and are stripped from the key. A
  `qr:`-prefixed field at any position is a validation regex (see
  [Validation](#validation)); a `pv:`-prefixed field at any position is a
  preview command (see [Preview](#preview)); a `file:`-prefixed default opens
  an editor (see [Editor](#editor)).
- **C (stdin):** when no B positionals are given and stdin is not a tty, a spec
  is read from stdin as `key=value` lines, blank line separating inputs. Keys:
  `name`, `prompt`, `default`, `values`, `default-env`, `values-env`,
  `secret`, `multi`, `trim`, `required`, `validate`, `validate-error`,
  `label-color`, `default-color`, `preview`.

A `values` comma-list turns the input into a pick. With `--multi` (or C
`multi=1`) the user may select several; selected values are joined with `--sep`
(default `,`). `$VAR` and `${VAR}` are expanded in `default`, `values`, and
`prompt` from the environment.

## OPTIONS

- `-h`, `--help` — show usage and exit.
- `-V`, `--version` — print version and exit.
- `--in-shell` — prompt in the current shell (default without tmux).
- `--new-shell` — prompt in a fresh shell (tmux popup if available, else in-shell).
- `--popup` — prompt in a tmux `display-popup`. Requires being inside tmux;
  otherwise degrades to `--in-shell` with a stderr notice.
- `--no-tmux` — never use tmux (silent fallback to in-shell).
- `--interactive` — force prompting (default when stdin is a tty).
- `--scripted` — force non-interactive (default when stdin is a pipe).
- `--picker fzf|numbered|cmd` — picker for values-lists. `fzf` (default when
  installed), `numbered`, or an external command.
- `--no-fzf` — never use fzf; force numbered.
- `--multi` — allow multiple values per values-list input. Interactive fzf uses
  `--multi`; the numbered picker reads a comma-separated line of indices or
  values. Selected values are joined with `--sep`. Free-text inputs are
  unaffected.
- `--sep char` — separator for joined multi-values (default `,`).
  Multi-character separators are accepted. `--separator` is a long alias.
- `--color[=always|auto|never]` — colorize the prompt label (bold cyan) and the
  default hint (dim yellow) on stderr. Bare `--color` = `always`; default
  `auto` (on when stderr is a tty and `NO_COLOR` is unset). ANSI codes in a
  `values` list are rendered in the picker and stripped from the output, so
  `name=value` is always plain text.
- `--label-color <spec>` — set the prompt-label color. `--default-color <spec>`
  sets the default-hint color. A spec is a named color (`black`, `red`, …,
  `white`) with optional styles (`bold`, `dim`, `underline`, combinable as
  `bold red`), or a raw SGR string like `1;31`. `--theme <name>`
  (`default`, `dark`, `light`, `high-contrast`) bundles both. C `label-color=`/
  `default-color=` keys override per spec. The on/off `--color` switch gates all
  of this.
- `--trim` — trim leading/trailing whitespace from answers. Default is **on**
  for non-secrets and **off** for secrets (a secret with trailing spaces is a
  real case). `--no-trim` preserves whitespace. A C `trim=0`/`trim=1` key
  overrides per spec. Trimming runs after the read and before validation.
- `--validate <regex>` — a POSIX ERE every free-text answer must match. A
  mismatch is an error in scripted mode and a cancel in interactive mode. A
  per-spec regex (B `qr:` field or C `validate=`) overrides this for one input
  and also applies to values-list picks; picks are otherwise exempt (valid by
  construction). `--validate-error <msg>` overrides the default
  `invalid: does not match <pattern>` message. Checked after `required`.
- `--retry <n>` — re-prompt up to N times on a `required`/`--validate` failure
  before canceling (default 0 = fail fast). A C `retry=<n>` key overrides per
  spec. The counter is per-input. Scripted mode ignores `--retry` (no re-prompt
  loop) with a stderr notice. Each retry prints `invalid: <reason>; try again (n
  left)` on stderr.
- `--header <text>` — a banner printed to stderr once before the first prompt
  (colored with the label color when `--color` is on); for fzf it is also passed
  as `--header`. `--header-file <path>` reads the banner from a file; the two
  are mutually exclusive and a missing file is a hard error. Multi-line headers
  are supported.
- `--width <n>` — tmux popup width in characters (default 80). `--height <n>` is
  the height in lines (default 20). `--auto-size` computes both from the specs
  (max prompt+default+value width, number of inputs plus padding), capped at the
  terminal size. In-shell mode ignores these (there is no popup).
- `--json` — emit JSON Lines: one `{"name":"…","value":"…"}` object per input,
  on its own line, instead of `name=value`. `--json-array` emits a single JSON
  array on one line (`--json-array` implies `--json`). Values are JSON-escaped;
  secrets are cleartext. Multi-values stay a single joined string.
- `--save <file>` — write this run's `name=value` answers to `<file>` on success
  (atomic: temp + rename). Secrets are skipped (with a stderr warning) unless
  `--save-secrets` is given. `--load <file>` pre-fills defaults from a prior
  answers file (`#` comments and blank lines ignored); a missing file is a silent
  no-op. Precedence: typed answer > loaded value > spec `default`. `--json` and
  `--save` are mutually exclusive. A missing parent directory or non-writable
  `--save` target is a hard error (exit non-zero, no stdout).
- `--multiline` — read a multi-line block until a sentinel line (default `.`;
  `--sentinel <s>` sets it, `--sentinel ''` = EOF-terminated). Blank lines are
  part of the block; the sentinel is excluded. C `multiline=1`/`sentinel=` per
  spec. Values-list inputs ignore it. The value may contain embedded newlines.
- `--timeout <n>` — cancel the run after N seconds (a background alarm + SIGALRM
  trap). A timeout is a cancel (exit non-zero, no stdout). Does not fire if input
  arrives in time.
- `--history <file>` — pre-fill each input's default with the last prior value
  for its name from `<file>`, and append this run's `name=value` answers on
  success (secrets skipped unless `--save-secrets`). A missing file is created on
  append.
- `--print-spec` — normalize specs only, print sixteen tab-separated columns
  (`name`, `prompt`, `default`, `values`, `secret`, `multi`, `trim`, `required`,
  `validate`, `validate-error`, `retry`, `label-color`, `default-color`, `preview`,
  `multiline`, `sentinel`), exit (debug).
  (`name`, `prompt`, `default`, `values`, `secret`, `multi`, `trim`, `required`,
  `validate`, `validate-error`, `retry`), exit (debug).
- `--specs-from <file>` — read B specs from `<file>` (one per line; `#` comments
  and blank lines are ignored) instead of positional args. Mutually exclusive
  with B positionals; combines with C (stdin is then the answer pipe for
  scripted B, or a tty for interactive B). A missing, unreadable, or spec-free
  file is a hard error (exit 1) — distinct from `--load`, which is optional
  pre-fill.

## SECRET INPUT

A leading `*` on the name marks the input as secret. Entry is hidden
(`stty -echo`), the default is not shown in the prompt (it would leak it), and
the `*` is stripped so the output key is the bare name. If the user enters an
empty line, the default is used silently. The output is still cleartext
(`pw=s3cr3t`) — tprompt hides *entry*, not the captured value. In C, use
`name=*pw` or the `secret=1` key.

## REQUIRED INPUT

A leading `!` on the name (B) or the C `required=1` key marks a field as
required: an empty answer is an error, distinct from having a default. In
scripted mode tprompt writes `TPROMPT_ERROR: required field '<name>' is empty`
to the result and exits non-zero with no stdout; in interactive mode an empty
answer cancels the run (re-prompted up to `--retry` times once that feature
lands). `!` combines with `*` (secret) in either order. The default is **not**
applied to a required field on an empty answer — required demands a real value.

## VALIDATION

`--validate <regex>` (global) or a per-spec regex — B `qr:`-prefixed field at any
position, or C `validate=<regex>` — rejects answers that do not match a POSIX
ERE. The regex is matched against the final value (after env expansion, default
fallback, and trim). A mismatch is an error in scripted mode
(`TPROMPT_ERROR:invalid: does not match <pattern>`) and a cancel in interactive
mode. `--validate-error <msg>` or C `validate-error=<msg>` overrides the default
message. Checked after `required` (an empty answer reports "required" first).

The global `--validate` applies to free-text inputs only; values-list picks are
exempt (valid by construction) unless a per-spec `qr:`/`validate=` constrains
them, in which case the picked value is also checked. A spec may carry both a
values list and a regex (`port|port|22|22,80,443|qr:^[0-9]+$`). The regex flavor
is POSIX ERE (awk's native regex); backreferences and lookahead are not
supported.

## RETRY

`--retry <n>` (default 0) re-prompts up to N times on a `required` or
`--validate` failure before canceling the run (no stdout). The counter is
per-input and resets between inputs. Each retry prints
`invalid: <reason>; try again (n left)` on stderr. A C `retry=<n>` key overrides
the global value per spec. Scripted mode ignores `--retry` — there is no
re-prompt loop over a pipe — and prints a stderr notice if it is set explicitly.

## HEADER

`--header <text>` (or `--header-file <path>`) prints a banner to stderr once at
the top of the run, before the first prompt. When `--color` is on the banner is
colored with the label color. For the fzf picker the banner is also passed as
fzf's `--header`. `--header` and `--header-file` are mutually exclusive; a
missing or unreadable `--header-file` is a hard error. Multi-line banners are
supported (the text or file may contain newlines).

## OUTPUT

One `name=value` line per input, in order, on stdout. Prompts and the numbered
list go to stderr. On cancel (Esc in fzf, EOF/Ctrl-D on a prompt, or a malformed
spec), tprompt exits non-zero and prints nothing on stdout.

## JSON OUTPUT

`--json` emits JSON Lines — one `{"name":"…","value":"…"}` object per input, on
its own line — instead of `name=value`. `--json-array` emits a single JSON array
on one line (and implies `--json`). Values are JSON-string-escaped (quotes,
backslashes, and the control characters `\t`, `\n`, `\r`, `\b`, `\f`); secrets
are included in cleartext (tprompt does not redact). Multi-values stay a single
joined string (`a,b,d`) for consistency with the default output. On cancel or
error, no JSON is emitted (exit non-zero, no stdout).

## SAVE / LOAD

`--save <file>` writes this run's `name=value` answers to `<file>` on success
(atomic: temp file plus rename, so a crash does not corrupt it). Secrets are
skipped (with a stderr warning) unless `--save-secrets` is given; `--load` of a
secret input pre-fills it (the file already contains it cleartext). `--load
<file>` reads a prior `name=value` file (`#` comments and blank lines ignored)
and, for each name matching a current spec input, the loaded value becomes the
default. Precedence: a typed or scripted answer wins; then the loaded value;
then the spec `default`. A missing `--load` file is a silent no-op; a missing
parent directory or non-writable `--save` target is a hard error (exit non-zero,
no stdout). `--json` and `--save` are mutually exclusive (the save file is always
`name=value`).

## PREVIEW

A per-spec preview command (B `pv:`-prefixed field at any position, or C
`preview=<cmd>`) is passed to the fzf picker as `--preview`. `<cmd>` has `{}`
substituted with the current item (the fzf convention). It is only effective when
the picker is fzf; the numbered picker and external command ignore it, and if fzf
is absent the preview is silently ignored. The command runs in the popup's shell
with the caller's environment — keep it fast (e.g. `ping -c1 -W1 {}`, `head -1`).
A spec may carry both a values list and a preview
(`man|man page||git.1,git-add.1|pv:man {}`); `pv:` is detected by prefix at any
position, parallel to `qr:`.

## MULTILINE

`--multiline` (or C `multiline=1`) reads a multi-line block until a sentinel line
(default `.`; `--sentinel <s>` sets it, `--sentinel ''` means EOF-terminated).
Blank lines are part of the block (not a terminator); only the sentinel ends it.
The sentinel is excluded from the value. Values-list inputs ignore `--multiline`.
The value may contain embedded newlines — the `name=value` output line carries
them, and `--json` escapes them. In scripted mode the block is read from stdin
until the sentinel or EOF.

## EDITOR

A `file:` prefix on the default (`file:` alone, or `file:<template>`) opens
`$VISUAL`/`$EDITOR` (or `vi`) on a temp file pre-filled with the template (the
text after `file:`). When the editor exits, the file's content (one trailing
newline trimmed) is the value. An empty result is subject to `required`. If no
editor is available (`$EDITOR` unset and `vi` missing) it is a hard error. In
scripted mode the editor does not open — the template is the value. Multi-line
values flow through the NUL result protocol (see [Multiline](#multiline)).

## TIMEOUT

`--timeout <n>` arms a background alarm (`sleep N && kill -ALRM`) with a SIGALRM
trap that cancels the run after N seconds — exit non-zero, no stdout, and a
`tprompt: timed out after Ns` notice on stderr. It does not fire if all input
arrives in time. The alarm is armed in whichever process does the collect
(in-shell outer, or the popup inner via the re-entry command). Signal-based, so a
blocked `read` is interrupted on most systems; on the rare system where it is
not, the timeout cannot preempt the read (documented limitation).

## HISTORY

`--history <file>` keeps a per-name recall file of `name=value` lines. Before
collecting, each input's default is set to the last prior value for its name in
the file (so the prompt pre-fills with the most recent answer). On a successful
run, each input's `name=value` is appended (secrets are skipped unless
`--save-secrets`). A missing file is a no-op for pre-fill and is created on
append. Full fzf Ctrl-R search across all prior values is deferred (this MVP
recalls the last value per name).

## EXIT STATUS

- **0** — all inputs collected; results on stdout.
- **1** — cancel, or an error (e.g. a scripted input with no resolvable default).
- **2** — usage error.

## ENVIRONMENT

- `TMUX` — if set (inside tmux) and tmux is available, the default render mode
  is `--popup`.
- `NO_COLOR` — if set, disables color in `auto` mode.
- `TPROMPT_BIN` — used by the test suite to locate the binary.

## EXAMPLES

```
tprompt 'host|host to probe|localhost'
tprompt 'port|port|22|22,80,443'
tprompt '*pw|Password:'
tprompt --multi --sep ',' 'tags|t||a,b,c,d'
tprompt --color=always 'host|h|localhost'
tprompt --print-spec 'k|k|$USER'
tprompt --specs-from deploy.txt
```

## SEE ALSO

[../README.md](../README.md), [../DESIGN.md](../DESIGN.md),
[../docs/usage.md](../docs/usage.md), [../docs/integration.md](../docs/integration.md)
