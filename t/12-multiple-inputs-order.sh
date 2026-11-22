#!/bin/sh
# 12 - multiple inputs preserve order
. "$(dirname "$0")/helpers.sh"

out=$(printf '1\n2\n3\n' | "$TPROMPT_BIN" --scripted --in-shell 'a|a|' 'b|b|' 'c|c|')
tp_eq "order preserved" "a=1
b=2
c=3" "$out"

# B + C cannot mix; B takes precedence when positionals present (stdin reserved for answers)
out=$(printf 'q\n' | "$TPROMPT_BIN" --scripted --in-shell 'only|o|def')
tp_eq "single positional" "only=q" "$out"

tp_summary
