#!/bin/sh
# 02 - option B (positional specs), scripted (piped answers)
. "$(dirname "$0")/helpers.sh"

out=$(printf 'alice\n443\n' | "$TPROMPT_BIN" --in-shell --scripted 'host|host to probe|localhost' 'port|port|22|22,80,443')
tp_rc "b scripted rc" 0 $?
tp_eq "b scripted output" "host=alice
port=443" "$out"

# empty answer => default
out=$(printf '\n\n' | "$TPROMPT_BIN" --in-shell --scripted 'a|a|defa' 'b|b|defb')
tp_eq "b empty => default" "a=defa
b=defb" "$out"

# three fields (no values list)
out=$(printf 'x\n' | "$TPROMPT_BIN" --in-shell --scripted 'k|k|def')
tp_eq "b three fields" "k=x" "$out"

tp_summary
