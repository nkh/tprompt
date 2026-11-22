#!/bin/sh
# 03 - option C (stdin spec), scripted (defaults only)
. "$(dirname "$0")/helpers.sh"

out=$(printf 'name=host\ndefault=localhost\n\nname=port\ndefault=22\n' | "$TPROMPT_BIN" --in-shell)
tp_rc "c scripted rc" 0 $?
tp_eq "c scripted output" "host=localhost
port=22" "$out"

# single input C
out=$(printf 'name=only\ndefault=done\n' | "$TPROMPT_BIN" --in-shell)
tp_eq "c single" "only=done" "$out"

# prompt field preserved (does not affect output)
out=$(printf 'name=x\nprompt=whatever\ndefault=y\n' | "$TPROMPT_BIN" --in-shell)
tp_eq "c prompt ignored in output" "x=y" "$out"

tp_summary
