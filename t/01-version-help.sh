#!/bin/sh
# 01 - version and help
. "$(dirname "$0")/helpers.sh"

out=$("$TPROMPT_BIN" --version)
tp_eq "version string" "tprompt 0.2.0" "$out"

"$TPROMPT_BIN" --help >/dev/null 2>&1; tp_rc "--help exits 0" 0 $?
"$TPROMPT_BIN" -h >/dev/null 2>&1;    tp_rc "-h exits 0" 0 $?

# unknown option => non-zero
"$TPROMPT_BIN" --no-such-opt >/dev/null 2>&1; tp_rc "unknown opt non-zero" 1 $?

tp_summary
