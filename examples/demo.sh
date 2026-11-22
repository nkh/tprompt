#!/bin/sh
# examples/demo.sh - runnable tprompt demo. No tmux/fzf required.
# Runs several scripted/interactive scenarios and prints what tprompt returns.

TPROMPT_BIN="${TPROMPT_BIN:-$(cd "$(dirname "$0")/.." && pwd)/tprompt}"
[ -x "$TPROMPT_BIN" ] || { echo "tprompt not found at $TPROMPT_BIN" >&2; exit 2; }
TP="$TPROMPT_BIN"

hr() { printf '\n=== %s ===\n' "$1"; }

hr "1. one input, scripted (pipe a value)"
printf 'example.com\n' | "$TP" --scripted --in-shell 'host|host to probe|localhost'

hr "2. values-list, numbered picker (pipe index 3)"
printf '3\n' | "$TP" --interactive --picker numbered --in-shell 'port|port|22|22,80,443' 2>/dev/null

hr "3. env expansion (print-spec)"
TP_USER=alice TP_HOST=alice.example.com "$TP" --print-spec 'user|u|$TP_USER' 'url|url|https://${TP_HOST}'

hr "4. C spec, scripted (defaults + env)"
TP_HOST=example.com "$TP" --in-shell <<'EOF'
name=host
default=$TP_HOST

name=port
default=22
EOF

hr "5. cancel: EOF, no default (rc=1, no stdout)"
printf '' | "$TP" --interactive --in-shell 'k|k|' 2>/dev/null
echo "rc=$?"

hr "6. default fallback: fewer answers than inputs"
printf 'alice\n' | "$TP" --scripted --in-shell 'host|h|localhost' 'port|port|22'

echo
echo "done."
