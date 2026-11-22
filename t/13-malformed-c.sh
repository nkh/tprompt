#!/bin/sh
# 13 - malformed C spec => error
. "$(dirname "$0")/helpers.sh"

# line without '='
out=$(printf 'name=ok\nbadline-no-eq\n' | "$TPROMPT_BIN" --in-shell 2>/dev/null)
tp_rc "malformed C (no =) rc" 1 $?
tp_eq "malformed C no stdout" "" "$out"

# unknown key
out=$(printf 'boguskey=v\n' | "$TPROMPT_BIN" --in-shell 2>/dev/null)
tp_rc "unknown C key rc" 1 $?
tp_eq "unknown C key no stdout" "" "$out"

# empty C spec (no inputs)
out=$(printf '' | "$TPROMPT_BIN" --in-shell 2>/dev/null)
tp_rc "empty C rc" 1 $?
tp_eq "empty C no stdout" "" "$out"

tp_summary
