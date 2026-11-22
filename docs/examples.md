# tprompt — examples

All examples assume `tprompt` is on `$PATH`. Lines prefixed with `$` are shell
input; following lines are stdout.

## 1. One input, with a default

```
$ tprompt 'host|host to probe|localhost'
host=example.com
```

(Interactive: the prompt `host to probe [localhost]: ` is shown on stderr; you
type the value, or press Enter to accept the default.)

## 2. A values-list pick

```
$ tprompt 'port|port|22|22,80,443'
port=443
```

With fzf: a fuzzy picker. Without fzf: a numbered list:

```
1) 22
2) 80
3) 443
port> 3
port=443
```

## 3. Multiple inputs (B)

```
$ tprompt 'host|host to probe|localhost' 'port|port|22|22,80,443'
host=example.com
port=443
```

## 4. Multiple inputs (C), scriptable

```
$ tprompt <<'EOF'
name=host
prompt=host to probe
default=localhost

name=port
prompt=port
default=22
values=22,80,443
EOF
host=localhost
port=22
```

C is scripted: defaults are used as-is (no prompting), so this is safe inside a
non-interactive script.

## 5. Environment expansion

```
$ TP_USER=alice TP_HOST=alice.example.com tprompt <<'EOF'
name=user
default=$TP_USER

name=url
default=https://${TP_USER}.${TP_HOST#alice.}
EOF
user=alice
url=https://alice.example.com
```

`$VAR` and `${VAR}` (including the `${VAR#word}` form, expanded by your shell
before tprompt sees it when the heredoc is unquoted) work in `default`,
`values`, and `prompt`. For a quoted heredoc, tprompt does the `$VAR`/`${VAR}`
expansion itself.

## 6. Explicit env keys (C)

```
$ TP_HOST=example.com TP_PORTS=22,80,443 tprompt <<'EOF'
name=host
default-env=TP_HOST

name=port
default=22
values-env=TP_PORTS
EOF
host=example.com
port=22
```

`default-env=VAR` and `values-env=VAR` read the named env var directly.

## 7. Scripted (pipe answers)

```
$ printf 'alice\n443\n' | tprompt --scripted 'host|h|localhost' 'port|port|22|22,80,443'
host=alice
port=443
```

One line per input. Empty line ⇒ default. Fewer lines than inputs ⇒ remaining
inputs use their default (or error if none).

## 8. Driving the numbered picker non-interactively

```
$ printf '3\n' | tprompt --interactive --picker numbered --in-shell 'port|port|22|22,80,443' 2>/dev/null
port=443
```

`--interactive --picker numbered` reads the index from stdin — handy for tests
and scripted picks without fzf.

## 9. Cancel

```
$ printf '' | tprompt --interactive --in-shell 'k|k|' 2>/dev/null; echo "rc=$?"
rc=1
```

EOF on a free-text prompt with no default ⇒ cancel, no stdout, exit 1.

## 10. Inspect what tprompt sees

```
$ TP_HOST=example.com tprompt --print-spec 'host|h|$TP_HOST' 'port|port|22|22,80,443'
host	h	example.com	
port	port	22	22,80,443
```

`--print-spec` normalizes (parse + env-expand) and prints readable records
without prompting.

## 11. In a tmux popup

```
$ tmux new -d -s demo
$ tmux send-keys -t demo "tprompt --popup 'host|h|localhost'" Enter
```

(Inside a tmux session, `--popup` is the default; the prompt opens in a
floating popup.)
