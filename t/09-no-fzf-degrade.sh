#!/bin/sh
# 09 - fzf-absent degradation: picker resolves to numbered; --interactive drives it
. "$(dirname "$0")/helpers.sh"

# fzf absent => auto picker is numbered; pick index 3
out=$(printf '3\n' | "$TPROMPT_BIN" --interactive --in-shell 'port|port|22|22,80,443' 2>/dev/null)
tp_eq "no-fzf numbered pick 3" "port=443" "$out"

# explicit --picker numbered
out=$(printf '1\n' | "$TPROMPT_BIN" --interactive --picker numbered --in-shell 'p|p|x|a,b,c' 2>/dev/null)
tp_eq "explicit numbered pick 1" "p=a" "$out"

# --no-fzf forces numbered
out=$(printf '2\n' | "$TPROMPT_BIN" --no-fzf --interactive --in-shell 'p|p|x|x,y,z' 2>/dev/null)
tp_eq "no-fzf flag pick 2" "p=y" "$out"

# free-text interactive input (no values list) reads a line
out=$(printf 'typed\n' | "$TPROMPT_BIN" --interactive --in-shell 'k|k|def' 2>/dev/null)
tp_eq "interactive free-text" "k=typed" "$out"

# interactive free-text empty => default
out=$(printf '\n' | "$TPROMPT_BIN" --interactive --in-shell 'k|k|def' 2>/dev/null)
tp_eq "interactive empty => default" "k=def" "$out"

tp_summary
