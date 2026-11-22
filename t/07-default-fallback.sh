#!/bin/sh
# 07 - default fallback when piped answers run out
. "$(dirname "$0")/helpers.sh"

# pipe 1 answer for 2 inputs; second falls back to its default
out=$(printf 'alice\n' | "$TPROMPT_BIN" --in-shell --scripted 'host|h|localhost' 'port|port|22')
tp_rc "exhaust answers rc" 0 $?
tp_eq "exhaust => default" "host=alice
port=22" "$out"

# zero answers, both have defaults
out=$(printf '' | "$TPROMPT_BIN" --in-shell --scripted 'a|a|da' 'b|b|db')
tp_eq "no answers => all defaults" "a=da
b=db" "$out"

tp_summary
