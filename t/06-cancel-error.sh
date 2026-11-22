#!/bin/sh
# 06 - cancel / error: no answer and no default => non-zero, no stdout
. "$(dirname "$0")/helpers.sh"

# B scripted: EOF before all answered, second input has no default
out=$(printf 'alice\n' | "$TPROMPT_BIN" --in-shell --scripted 'host|h|localhost' 'port|port|' 2>/dev/null)
tp_rc "cancel no-answer no-default rc" 1 $?
tp_eq "cancel emits no stdout" "" "$out"

# C spec: input with no default and no env => error
out=$(printf 'name=bare\n' | "$TPROMPT_BIN" --in-shell 2>/dev/null)
tp_rc "c no default error rc" 1 $?
tp_eq "c no default no stdout" "" "$out"

# B interactive: EOF (Ctrl-D) on first prompt => cancel
out=$(printf '' | "$TPROMPT_BIN" --interactive --in-shell 'k|k|' 2>/dev/null)
tp_rc "interactive EOF cancel rc" 1 $?
tp_eq "interactive EOF no stdout" "" "$out"

tp_summary
