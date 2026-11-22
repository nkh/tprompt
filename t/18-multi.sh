#!/bin/sh
# 18 - multi-value: --multi + --sep; numbered comma-select (indices or values).
. "$(dirname "$0")/helpers.sh"

# --multi scripted: the answer line is taken verbatim
out=$(printf 'a,b,d\n' | "$TPROMPT_BIN" --scripted --in-shell --multi 'tags|t||a,b,c,d')
tp_eq "multi: scripted verbatim" "tags=a,b,d" "$out"

# --multi without --multi flag: single-select (scripted still verbatim, but the
# flag is what enables multi-select in the interactive picker)
out=$(printf 'a,b,d\n' | "$TPROMPT_BIN" --scripted --in-shell 'tags|t||a,b,c,d')
tp_eq "multi: scripted verbatim without flag" "tags=a,b,d" "$out"

# --multi numbered: comma-separated indices -> joined values
out=$(printf '1,3\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --multi 'tags|t||a,b,c,d' 2>/dev/null)
tp_eq "multi: numbered indices joined" "tags=a,c" "$out"

# --multi numbered: comma-separated literal values -> joined verbatim
out=$(printf 'a,b,d\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --multi 'tags|t||a,b,c,d' 2>/dev/null)
tp_eq "multi: numbered values joined" "tags=a,b,d" "$out"

# --sep changes the output separator
out=$(printf '1,3\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --multi --sep '|' 'tags|t||a,b,c,d' 2>/dev/null)
tp_eq "multi: --sep '|'" "tags=a|c" "$out"

# --sep accepts a multi-character separator
out=$(printf '1,3\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --multi --sep '; ' 'tags|t||a,b,c,d' 2>/dev/null)
tp_eq "multi: --sep '; ' (multi-char)" "tags=a; c" "$out"

# --separator is a long alias of --sep
out=$(printf '1,3\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --multi --separator ':' 'tags|t||a,b,c,d' 2>/dev/null)
tp_eq "multi: --separator alias" "tags=a:c" "$out"

# C spec: multi=1 marks one input as multi (col 6)
f=$(printf 'name=tags\nprompt=t\nvalues=a,b,c,d\nmulti=1\n' | "$TPROMPT_BIN" --print-spec | awk -F'\t' '{print $1"|"$6}')
tp_eq "multi: C multi=1 sets flag" "tags|1" "$f"

# --multi sets the flag on every B record (col 6)
f=$("$TPROMPT_BIN" --print-spec --multi 'a|a||1,2,3' 'b|b||x,y,z' | awk -F'\t' '{print $6}' | tr '\n' ',')
tp_eq "multi: --multi flag on all records" "1,1," "$f"

# --multi free-text input (no values): unaffected, reads the line verbatim
out=$(printf 'hello\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --multi 'note|n|' 2>/dev/null)
tp_eq "multi: free-text unaffected" "note=hello" "$out"

# multi empty selection (no answer, no default) -> cancel
out=$(printf '' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --multi 'tags|t||a,b,c,d' 2>/dev/null)
tp_rc "multi: empty selection rc" 1 $?
tp_eq "multi: empty selection no stdout" "" "$out"

tp_summary
