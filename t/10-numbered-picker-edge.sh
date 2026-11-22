#!/bin/sh
# 10 - numbered picker edge cases: out-of-range, non-numeric, EOF => cancel
. "$(dirname "$0")/helpers.sh"

# out-of-range index => cancel
out=$(printf '9\n' | "$TPROMPT_BIN" --interactive --picker numbered --in-shell 'p|p|x|a,b,c' 2>/dev/null)
tp_rc "numbered out-of-range rc" 1 $?
tp_eq "numbered out-of-range no stdout" "" "$out"

# non-numeric input => cancel
out=$(printf 'foo\n' | "$TPROMPT_BIN" --interactive --picker numbered --in-shell 'p|p|x|a,b,c' 2>/dev/null)
tp_rc "numbered non-numeric rc" 1 $?
tp_eq "numbered non-numeric no stdout" "" "$out"

# empty input => cancel
out=$(printf '\n' | "$TPROMPT_BIN" --interactive --picker numbered --in-shell 'p|p|x|a,b,c' 2>/dev/null)
tp_rc "numbered empty rc" 1 $?
tp_eq "numbered empty no stdout" "" "$out"

# EOF (no input) => cancel
out=$(printf '' | "$TPROMPT_BIN" --interactive --picker numbered --in-shell 'p|p|x|a,b,c' 2>/dev/null)
tp_rc "numbered EOF rc" 1 $?
tp_eq "numbered EOF no stdout" "" "$out"

tp_summary
