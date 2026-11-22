#!/bin/sh
# 14 - --print-spec debug output (normalized tab-separated records)
. "$(dirname "$0")/helpers.sh"

# four fields
f=$("$TPROMPT_BIN" --print-spec 'port|port|22|22,80,443' | awk -F'\t' '{print $1"|"$2"|"$3"|"$4}')
tp_eq "print-spec 4 fields" "port|port|22|22,80,443" "$f"

# three fields (empty values)
f=$("$TPROMPT_BIN" --print-spec 'host|h|localhost' | awk -F'\t' '{print $1"|"$2"|"$3"|"$4}')
tp_eq "print-spec 3 fields" "host|h|localhost|" "$f"

# two fields (empty default + values)
f=$("$TPROMPT_BIN" --print-spec 'bare|b' | awk -F'\t' '{print $1"|"$2"|"$3"|"$4}')
tp_eq "print-spec 2 fields" "bare|b||" "$f"

# multiple records, order preserved
n=$("$TPROMPT_BIN" --print-spec 'a|a|1' 'b|b|2' 'c|c|3' | wc -l | tr -dc '0-9')
tp_eq "print-spec record count" "3" "$n"

# print-spec applies env expansion
f=$(TP_V=hello "$TPROMPT_BIN" --print-spec 'k|k|$TP_V' | awk -F'\t' '{print $3}')
tp_eq "print-spec env expansion" "hello" "$f"

tp_summary
