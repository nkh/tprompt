# tprompt — usage reference

## Synopsis

```
tprompt [--in-shell|--new-shell|--popup] [--interactive|--scripted]
        [--picker fzf|numbered|<cmd>] [--no-tmux] [--no-fzf]
        [--color[=always|auto|never]] [--multi] [--sep <char>] [--trim|--no-trim] [--validate <re>] [--retry <n>] [--header <text>] [--width <n>] [--height <n>] [--auto-size] [--json] [--json-array]
        [--label-color <spec>] [--default-color <spec>] [--theme <name>] [--save <file>] [--load <file>] [--multiline] [--sentinel <s>] [--timeout <n>] [--history <file>] [--print-spec] [--specs-from <file>] [-h] [-V]
        ['name|prompt|default[|values]' ...]
```

## Input specs

### Option B — positional args

Each positional is `name|prompt|default[|values]`, split on `|`:

```
tprompt 'host|host to probe|localhost' 'port|port|22|22,80,443'
```

- `name` — the output key. A leading `*` marks a **secret** (see
  [Secret input](#secret-input)); a leading `!` marks a **required** field (see
  [Required input](#required-input)). Both are stripped from the key and combine
  (`*!` or `!*`). A `qr:`-prefixed field at any position is a **validation**
  regex (see [Validation](#validation)); a `pv:`-prefixed field at any position
  is a **preview** command (see [Preview](#preview)); a `file:`-prefixed default
  opens an editor (see [Editor](#editor)).
- `prompt` — shown to the user (stderr).
- `default` — used on empty input; pre-filled in the prompt.
- `values` (optional) — a comma-list; turns the input into a pick.

A `|` inside a field is not supported in B (use C for complex cases).

### Option C — stdin spec

When no B positionals are given and stdin is not a tty, tprompt reads a spec
from stdin: `key=value` lines, blank line separating inputs.

```
tprompt <<'EOF'
name=host
prompt=host to probe
default=localhost

name=port
prompt=port
default=22
values=22,80,443
EOF
```

Keys:

| key | meaning |
| --- | --- |
| `name` | output key (required); a leading `*` marks a secret |
| `prompt` | shown to the user |
| `default` | used on empty input |
| `values` | comma-list → pick |
| `default-env=VAR` | set `default` to the value of env var `VAR` |
| `values-env=VAR` | set `values` to the value of env var `VAR` |
| `secret=1` | mark this input as secret (hidden entry) |
| `multi=1` | mark this values-list input as multi-select |
| `trim=0`/`trim=1` | override whitespace trimming per spec (see [Trim](#trim)) |
| `required=1` | mark this input as required (empty answer is an error) |
| `validate=<regex>` | a POSIX ERE the answer must match (see [Validation](#validation)) |
| `validate-error=<msg>` | override the default mismatch message for this spec |

C is **scripted-only**: defaults (+ env) are used as-is, no prompting. An input
with no resolvable default is an error.

### Specs from a file — `--specs-from <file>`

Read B specs from a file (one per line) instead of positional args:

```
$ tprompt --specs-from deploy.txt
```

Each non-empty, non-`#` line is a B spec (`name|prompt|default[|values]`);
`#` comments and blank lines are ignored. Mutually exclusive with B positionals
(passing both is an error). It combines with C — `--specs-from` supplies the
B specs; stdin is then the answer pipe for scripted B, or a tty for
interactive B. A missing, unreadable, or spec-free file is a hard error
(exit 1), unlike `--load` (which is optional pre-fill).

## Secret input

A leading `*` on the name marks the input as secret. Entry is hidden
(`stty -echo`), the default is **not** shown in the prompt (showing it would
leak it), and the `*` is stripped so the output key is the bare name.

```
tprompt '*pw|Password:'              # B: name 'pw', secret
```

```
name=*pw                             # C: '*' prefix on the name value
prompt=Password:
```

or the explicit key:

```
name=pw
secret=1
```

If the user enters an empty line, the default is used silently. The output is
still cleartext `pw=s3cr3t` — tprompt hides *entry*, not the captured value;
the caller reads the value into a variable and uses it. In scripted mode (stdin
not a tty) the value is read verbatim from the pipe, same as any input.

## Required input

A leading `!` on the name (B) or the C `required=1` key marks a field as
required: an empty answer is an error, distinct from having a default.

- Scripted mode: tprompt writes `TPROMPT_ERROR: required field '<name>' is
  empty` and exits non-zero with no stdout.
- Interactive mode: an empty answer cancels the run (re-prompted up to `--retry`
  times once that feature lands).
- The default is **not** applied to a required field on an empty answer —
  required demands a real value.
- `!` combines with `*` (secret) in either order: `*!pw` or `!*pw`.

```
$ printf '\n' | tprompt --scripted '!host|host|'        # empty -> error
$ printf 'x\n'  | tprompt --scripted '!host|host|'      # host=x
```

## Validation

`--validate <regex>` (global) or a per-spec regex rejects answers that do not
match a POSIX ERE.

- **Global** `--validate <regex>` applies to every **free-text** input.
- **Per-spec**: a B `qr:`-prefixed field at **any** position, or a C
  `validate=<regex>` key. The parser splits the B spec on `|` and treats any
  field beginning with `qr:` as the regex; the remaining fields fill
  name/prompt/default/values in order — so it can sit in the values slot or
  after the values list.
- The regex is matched against the **final value** (after env expansion, default
  fallback, and trim). A mismatch is an error in scripted mode
  (`TPROMPT_ERROR:invalid: does not match <pattern>`) and a cancel in
  interactive mode.
- `--validate-error <msg>` or C `validate-error=<msg>` overrides the default
  message.
- Checked after `required` (an empty answer reports "required" first).
- Values-list picks are **exempt** from the global `--validate` (valid by
  construction), unless a per-spec `qr:`/`validate=` constrains them — then the
  picked value is also checked. A spec may carry both a values list and a
  regex: `'port|port|22|22,80,443|qr:^[0-9]+$'`.
- The flavor is POSIX ERE (awk's native regex); backreferences and lookahead are
  not supported.

```
$ printf '22\n'  | tprompt --scripted --validate '^[0-9]+$' 'port|port|22'   # port=22
$ printf 'abc\n' | tprompt --scripted --validate '^[0-9]+$' 'port|port|22'   # error
$ printf 'host\n' | tprompt --scripted 'host|h|localhost|qr:^[a-z]+$'        # host=host
```

## Retry

`--retry <n>` (default 0 = fail fast) re-prompts up to N times on a `required` or
`--validate` failure before canceling the run (no stdout). The counter is
per-input and resets between inputs. A C `retry=<n>` key overrides the global
value per spec.

- Each retry prints `invalid: <reason>; try again (n left)` on stderr.
- Scripted mode ignores `--retry` (there is no re-prompt loop over a pipe) and
  prints a stderr notice if it is set explicitly.
- Applies to interactive free-text inputs only (values-list picks are one-shot).

```
$ printf 'abc\n22\n' | tprompt --interactive --no-fzf --retry 2 --validate '^[0-9]+$' 'port|port|22'
invalid: does not match ^[0-9]+$; try again (1 left)
port=22
```

## Header

`--header <text>` (or `--header-file <path>`) prints a banner to stderr once at
the top of the run, before the first prompt. When `--color` is on the banner is
colored with the label color. For the fzf picker the banner is also passed as
fzf's `--header`. `--header` and `--header-file` are mutually exclusive; a
missing or unreadable `--header-file` is a hard error. Multi-line banners are
supported.

```
$ printf 'x\n' | tprompt --interactive --no-fzf --header "Deploy config — prod" 'h|host|'
Deploy config — prod    # stderr banner
h=x                     # stdout result
```

## Popup dimensions

`--width <n>` (default 80) and `--height <n>` (default 20) set the tmux
`display-popup` dimensions (characters and lines). `--auto-size` computes both
from the specs — width as the max of prompt + default-hint + longest value (plus
padding), height as the number of inputs plus padding — capped at the terminal
size (`tput cols`/`tput lines`, falling back to 80×24). In-shell mode ignores
these (there is no popup); `tmux` clamps an oversized popup anyway.

## Multiple values

`--multi` makes every values-list input multi-select; C's `multi=1` key marks
one input. A free-text input (no values list) is unaffected — the user already
types freely.

- **Interactive + fzf:** `fzf --multi` — Tab to select several; selected lines
  are joined with the separator.
- **Interactive + numbered (no fzf):** the numbered list is printed; enter a
  comma-separated line. Each token is an index (a number in range → the value
  at that index) or a literal value (taken verbatim). So `1,3` or `a,b,d` both
  work.
- **Scripted (B, stdin pipe):** the answer line is taken verbatim — pipe
  `a,b,d`, get `name=a,b,d`.

`--sep <char>` (default `,`) sets the join separator. Multi-character
separators are accepted (`--sep '; '`). `--separator` is a long alias.

```
$ printf '1,3\n' | tprompt --interactive --no-fzf --multi --sep ',' 'tags|t||a,b,c,d'
tags=a,c
$ printf 'a,b,d\n' | tprompt --interactive --no-fzf --multi 'tags|t||a,b,c,d'
tags=a,b,d
```

A value that itself contains the separator is a caller error (the join is
unambiguous only if values do not contain the separator). An empty multi
selection falls back to the default, or cancels if there is no default.

## Color

`--color[=always|auto|never]`. Bare `--color` = `always`; default `auto` (on
when stderr is a tty and `NO_COLOR` is unset).

- The **prompt label** is bold cyan; the **default hint** `[default]` is dim
  yellow (the `default` theme). Display only, on stderr.
- `--label-color <spec>` and `--default-color <spec>` override the label and
  default-hint colors. A spec is a named color (`black`, `red`, …, `white`) with
  optional styles (`bold`, `dim`, `underline`, combinable as `bold red`), or a
  raw SGR string like `1;31`. `--theme <name>` (`default`, `dark`, `light`,
  `high-contrast`) bundles both. C `label-color=`/`default-color=` keys override
  per spec. The on/off `--color` switch gates all of this.
- A `values` list may carry ANSI codes (e.g. `\033[31mred\033[0m`). They are
  **rendered** in the picker (fzf `--ansi`, or echoed raw for the numbered list)
  and **stripped from the output**, so `name=value` is always plain text even
  when the choices were colored in the UI.

## Trim

`--trim` / `--no-trim` control whether leading and trailing whitespace (spaces
and tabs) is stripped from answers.

- Default is **on** for non-secrets and **off** for secrets (a secret with
  trailing spaces is a real case). `--no-trim` preserves whitespace; `--trim`
  makes the default explicit.
- A C `trim=0` / `trim=1` key overrides per spec (B has no per-spec trim).
- Trimming runs after the read and before validation (and before ANSI
  stripping), so the emitted `name=value` reflects the trimmed value.

This is a behavior change from 0.2.0, which did not trim. Use `--no-trim` to
restore the old behavior.

```
$ printf '  x  \n' | tprompt --interactive --no-fzf 'h|host|'
h=x
$ printf '  x\n' | tprompt --interactive --no-fzf --no-trim 'h|host|'
h=  x
```

## Environment expansion

`$VAR` and `${VAR}` are expanded in `default`, `values`, and `prompt` from the
environment:

```
$ TP_HOST=example.com tprompt 'host|h|$TP_HOST'
host=example.com

$ TP_USER=bob tprompt --print-spec 'k|hi $TP_USER|d'
k	hi bob	d	
```

Unset variables expand to empty.

## Interaction modes

| stdin | default mode | behavior |
| --- | --- | --- |
| tty | interactive | prompt each input (picker for values-lists, read for free-text) |
| pipe (B) | scripted | read one answer line per input; empty ⇒ default; EOF ⇒ default or error |
| pipe (C) | scripted | use defaults as-is, no prompting |

Override with `--interactive` or `--scripted`. Interactive requires B
positionals (C consumes stdin).

## Render modes

| flag | where | requires |
| --- | --- | --- |
| `--in-shell` | current process, stdin | nothing |
| `--popup` | tmux `display-popup` | tmux + inside a session |
| `--new-shell` | popup if tmux, else in-shell | tmux (optional) |

Default: `--popup` if `$TMUX` set and `tmux` exists, else `--in-shell`.
`--no-tmux` forces non-tmux silently. `--popup` without tmux warns once on
stderr and falls back to in-shell.

## Picker (values-list inputs)

| `--picker` | behavior |
| --- | --- |
| `fzf` | `printf lines \| fzf --ansi --prompt=...` (default if fzf installed). `--multi` adds `--multi`. |
| `numbered` | numbered list to stderr, read an index on stdin. With `--multi`, read a comma-separated line of indices or values. |
| `<cmd>` | `printf lines \| <cmd>`, first stdout line is the pick (single-select) |

`--no-fzf` forces numbered. In **scripted** mode the picker is not used — the
piped answer line is the value verbatim.

## Output

- One `name=value` line per input, in order, on stdout.
- Prompts and the numbered list go to **stderr**.
- On cancel or error: exit non-zero, **no stdout**.

## JSON output

`--json` emits JSON Lines — one `{"name":"…","value":"…"}` object per input on
its own line — instead of `name=value`. `--json-array` emits a single JSON array
on one line (and implies `--json`). Values are JSON-escaped (quotes, backslashes,
and `\t`/`\n`/`\r`/`\b`/`\f`); secrets are cleartext (tprompt does not redact).
Multi-values stay a single joined string. On cancel or error, no JSON is emitted.

```
$ printf 'example.com\n' | tprompt --scripted --json 'h|host|localhost'
{"name":"h","value":"example.com"}
$ printf 'a\nb\n' | tprompt --scripted --json --json-array 'h|host|' 'p|port|'
[{"name":"h","value":"a"},{"name":"p","value":"b"}]
```

## Preview

A per-spec preview command — B `pv:`-prefixed field at any position, or C
`preview=<cmd>` — is passed to the fzf picker as `--preview`. `<cmd>` has `{}`
substituted with the current item. It is only effective when the picker is fzf;
the numbered picker and external command ignore it, and if fzf is absent the
preview is silently ignored. Keep the command fast (`ping -c1 -W1 {}`, `head -1`).
A spec may carry both a values list and a preview
(`man|man page||git.1,git-add.1|pv:man {}`); `pv:` is detected by prefix at any
position, parallel to `qr:`.

## Multiline

`--multiline` (or C `multiline=1`) reads a multi-line block until a sentinel line
(default `.`; `--sentinel <s>` sets it, `--sentinel ''` means EOF-terminated).
Blank lines are part of the block (not a terminator); only the sentinel ends it;
the sentinel is excluded from the value. Values-list inputs ignore `--multiline`.
The value may contain embedded newlines — the `name=value` output carries them,
and `--json` escapes them. In scripted mode the block is read from stdin until
the sentinel or EOF.

## Editor

A `file:` prefix on the default (`file:` alone, or `file:<template>`) opens
`$VISUAL`/`$EDITOR` (or `vi`) on a temp file pre-filled with the template (the
text after `file:`). When the editor exits, the file's content (one trailing
newline trimmed) is the value. An empty result is subject to `required`. If no
editor is available (`$EDITOR` unset and `vi` missing) it is a hard error. In
scripted mode the editor does not open — the template is the value.

```
$ EDITOR=vim tprompt 'msg|commit message|file:# enter commit message'
```

```
$ printf 'line1\nline2\n.\n' | tprompt --scripted --multiline 'desc|description|'
desc=line1
line2
```

## Timeout

`--timeout <n>` arms a background alarm (`sleep N && kill -ALRM`) with a SIGALRM
trap that cancels the run after N seconds — exit non-zero, no stdout, and a
`tprompt: timed out after Ns` notice on stderr. It does not fire if all input
arrives in time. Signal-based, so a blocked `read` is interrupted on most systems
(on the rare system where it is not, the timeout cannot preempt the read).

```
$ sleep 30 | tprompt --interactive --timeout 5 'h|host|'   # cancels after 5s
```

## History

`--history <file>` keeps a per-name recall file of `name=value` lines. Before
collecting, each input's default is set to the last prior value for its name (so
the prompt pre-fills with the most recent answer). On a successful run, each
input's `name=value` is appended (secrets skipped unless `--save-secrets`). A
missing file is a no-op for pre-fill and is created on append. Full fzf Ctrl-R
search across all prior values is deferred — this MVP recalls the last value per
name.

```
$ tprompt --history .tprompt-history 'h|host|' 'p|port|22'
```

## Save / load

`--save <file>` writes this run's `name=value` answers to `<file>` on success
(atomic: temp + rename, so a crash does not corrupt it). Secrets are skipped
(with a stderr warning) unless `--save-secrets` is given. `--load <file>` reads a
prior `name=value` file (`#` comments and blank lines ignored) and, for each name
matching a current spec input, the loaded value becomes the default. Precedence:
a typed or scripted answer wins; then the loaded value; then the spec `default`.
A missing `--load` file is a silent no-op; a missing parent directory or
non-writable `--save` target is a hard error (exit non-zero, no stdout). `--json`
and `--save` are mutually exclusive.

```
$ tprompt --save .tprompt-answers 'host|h|' 'port|p|22'
$ tprompt --load .tprompt-answers 'host|h|' 'port|p|22'   # pre-fills from the file
```

## Exit codes

| code | meaning |
| --- | --- |
| 0 | all inputs collected; results on stdout |
| 1 | cancel, or an error (e.g. scripted input with no resolvable default) |
| 2 | usage error (unknown option, malformed C spec) |

## Debug

`--print-spec` normalizes the specs (parsing B/C + env expansion) and prints
readable tab-separated records without prompting. Sixteen columns: `name`,
`prompt`, `default`, `values`, `secret`, `multi`, `trim`, `required`, `validate`,
`validate-error`, `retry`, `label-color`, `default-color`, `preview`, `multiline`,
`sentinel`. Useful for verifying what tprompt sees.

```
$ tprompt --print-spec 'port|port|22|22,80,443' '*pw|Password:' --multi
port	port	22	22,80,443	0	1
pw	Password:			1	1
```
