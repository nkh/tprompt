# tprompt

A small, standalone CLI that prompts for named inputs and prints `name=value`
lines. It is **tmux-optional** and **fzf-optional**: it runs in the current
shell, spawns a fresh shell, or opens a tmux popup; it uses `fzf` when present
and falls back to a numbered list otherwise. No runtime dependencies beyond
POSIX `sh` and `awk`.

tprompt is the prompting piece factored out of [tum](../..) (a tmux pane
manager). It has **no tum dependency**; any tool or script can call it.

## Install

```
cp tprompt /usr/local/bin/           # or anywhere on $PATH
chmod +x /usr/local/bin/tprompt
```

Optional, for nicer UX: `fzf` (values-list picking) and `tmux` (`--popup`).
Without them tprompt degrades gracefully (numbered list, in-shell).

## Quick start

Option **B** — one positional arg per input:

```
$ tprompt 'host|host to probe|localhost' 'port|port|22|22,80,443'
host=example.com
port=443
```

A leading `*` on the name marks a **secret** (entry hidden, `*` stripped):

```
$ tprompt '*pw|Password:' 'host|host|localhost'
pw=s3cr3t
host=example.com
```

**Multi-value** inputs (`--multi`) let the user pick several from a values list;
`--sep` sets the join separator (default `,`):

```
$ printf '1,3\n' | tprompt --interactive --no-fzf --multi --sep ',' 'tags|t||a,b,c,d'
tags=a,c
```

`--color[=always|auto|never]` colorizes the prompt label + default hint, and
strips any ANSI codes from the output values.

Option **C** — specs on stdin (scriptable, no arg-quoting):

```
$ tprompt <<'EOF'
name=host
prompt=host to probe
default=$TP_HOST

name=port
prompt=port
default=22
values=22,80,443
EOF
host=example.com
port=22
```

`$VAR` and `${VAR}` are expanded in `default` / `values` / `prompt` from the
environment. Output is one `name=value` line per input, in order. Cancel (Esc
in fzf, Ctrl-D/EOF on a prompt) exits non-zero with no stdout.

## Modes

| Flag | Meaning |
| --- | --- |
| `--in-shell` | prompt in the current shell (default without tmux) |
| `--new-shell` | prompt in a fresh shell (tmux popup if available) |
| `--popup` | prompt in a tmux `display-popup` |
| `--no-tmux` | never use tmux (popup/new-shell degrade to in-shell, silently) |
| `--interactive` | force prompting (default when stdin is a tty) |
| `--scripted` | force non-interactive (default when stdin is a pipe) |
| `--picker fzf\|numbered\|<cmd>` | picker for values-lists |
| `--no-fzf` | never use fzf (force numbered) |
| `--multi` | allow multiple values per values-list input |
| `--sep <char>` | separator for joined multi-values (default `,`; `--separator` alias) |
| `--color[=always\|auto\|never]` | colorize the prompt label + default hint; strip ANSI from output |
| `--print-spec` | normalize specs only, print records, exit (debug) |
| `--specs-from <file>` | read B specs from a file (one per line; `#`/blank ignored); mutually exclusive with positionals |
| `--trim` / `--no-trim` | trim leading/trailing whitespace from answers (default on for non-secrets, off for secrets); C `trim=0`/`1` overrides per spec |
| `--validate <re>` | POSIX ERE every free-text answer must match; B `qr:` field (any position) / C `validate=` per spec; `--validate-error <msg>` custom message |
| `--retry <n>` | re-prompt up to N times on a required/validate failure (default 0 = fail fast); C `retry=<n>` per spec; scripted mode ignores it |
| `--header <text>` / `--header-file <path>` | banner to stderr once before the first prompt (colored with label color); mutually exclusive; missing file is a hard error |
| `--width <n>` / `--height <n>` / `--auto-size` | tmux popup dimensions (default 80×20); `--auto-size` computes from specs, capped at terminal; in-shell ignores |
| `--json` / `--json-array` | emit JSON Lines or a single JSON array instead of `name=value`; values JSON-escaped; secrets cleartext |
| `--label-color` / `--default-color` / `--theme` | configurable prompt-label + default-hint colors (named `bold red` or raw `1;31`); themes: default/dark/light/high-contrast; C `label-color=`/`default-color=` per spec |
| `--save <file>` / `--load <file>` | persist answers + pre-fill defaults next run (answer > loaded > spec default); secrets skipped unless `--save-secrets`; missing load = no-op |
| `--multiline` / `--sentinel <s>` | read a multi-line block until a sentinel (default `.`; `--sentinel ''` = EOF); C `multiline=`/`sentinel=` per spec; values-lists ignore it |
| `file:` default | open `$VISUAL`/`$EDITOR`/`vi` on a temp file pre-filled with the template (text after `file:`); scripted uses the template; empty result subject to `required` |
| `--timeout <n>` | cancel the run after N seconds (background alarm + SIGALRM trap); no stdout; doesn't fire if input arrives in time |
| `--history <file>` | per-name recall file: pre-fill each default with the last prior value for its name; append this run's answers on success (secrets skipped unless `--save-secrets`) |

A leading `*` on a name marks a **secret** (hidden entry); a leading `!` marks a
**required** field (empty answer is an error); the two combine (`*!`/`!*`). C
also has `secret=1`, `multi=1`, `trim=0`/`1`, and `required=1` keys. Default render is `--popup` when inside tmux, else
`--in-shell`. Default picker is `fzf` when installed, else `numbered`. Default
color is `auto` (on at a tty with `NO_COLOR` unset).

## Tests

```
sh t/run.sh
```

18 files, ~90 assertions, no tmux/fzf required.

## Docs

- [docs/usage.md](docs/usage.md) — full reference (options, B/C specs, env, exit codes)
- [docs/working-secret-color-multi.md](docs/working-secret-color-multi.md) — design
  notes + 30 usability suggestions for this release
- [docs/next-round-design.md](docs/next-round-design.md) — design proposal for the
  next round (required, validate, retry, trim, specs-from, color, json,
  save/load, header, dimensions, preview, editor, multiline, timeout, history)
- [docs/working-next-round.md](docs/working-next-round.md) — implementation notes
  for the next round (0.3.0+), updated per feature
- [docs/examples.md](docs/examples.md) — worked examples
- [docs/integration.md](docs/integration.md) — how a caller (e.g. tum) integrates tprompt
- [DESIGN.md](DESIGN.md) — goals, contract, modes, the swap-to-shell fallback
- [man/tprompt.1.md](man/tprompt.1.md) — manpage source

## License

MIT — see [LICENSE](LICENSE).
