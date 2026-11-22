#!/bin/sh
# 11 - scripted mode ignores values-lists (value used verbatim)
. "$(dirname "$0")/helpers.sh"

out=$(printf '999\n' | "$TPROMPT_BIN" --scripted --in-shell 'port|port|22|22,80,443')
tp_eq "scripted ignores values list" "port=999" "$out"

# value not in the list is accepted verbatim
out=$(printf 'not-in-list\n' | "$TPROMPT_BIN" --scripted --in-shell 'p|p|def|a,b,c')
tp_eq "scripted verbatim value" "p=not-in-list" "$out"

tp_summary
