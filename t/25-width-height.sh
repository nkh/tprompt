#!/bin/sh
# 25 - --width / --height / --auto-size: tmux popup dimensions (default 80x20).
# In-shell mode ignores them (no popup). These tests cover parsing + validation;
# the dimensional effect is only observable inside a tmux popup.
. "$(dirname "$0")/helpers.sh"

# 1. --width / --height accepted in --in-shell (no popup, no error)
out=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --width 120 --height 40 'h|host|' 2>/dev/null)
tp_eq "width/height: accepted in-shell" "h=x" "$out"

# 2. --width non-numeric -> usage error
"$TPROMPT_BIN" --width abc 'h|host|' >/dev/null 2>&1
tp_rc "width: non-numeric rc" 1 $?

# 3. --height non-numeric -> usage error
"$TPROMPT_BIN" --height abc 'h|host|' >/dev/null 2>&1
tp_rc "height: non-numeric rc" 1 $?

# 4. --width= and --height= forms accepted
out=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --width=100 --height=10 'h|host|' 2>/dev/null)
tp_eq "width/height: =form accepted" "h=x" "$out"

# 5. --auto-size accepted (in-shell: no popup, no error)
out=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --auto-size 'h|host|localhost' 2>/dev/null)
tp_eq "auto-size: accepted in-shell" "h=x" "$out"

# 6. --width needs an argument
"$TPROMPT_BIN" --width >/dev/null 2>&1
tp_rc "width: missing arg rc" 1 $?

# 7. combination: width + height + auto-size + header -> accepted
out=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --width 120 --height 40 --auto-size --header "cfg" 'h|host|' 2>/dev/null)
tp_eq "width/height: combination accepted" "h=x" "$out"

# 8. --auto-size with a values list (exercises the awk dimension computation path
#    without requiring tmux; the popup block only runs under RENDER=popup)
specs='rg|region||us-east-1,eu-west-1,ap-south-1,some-very-long-region-name'
out=$(printf '1\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --auto-size "$specs" 2>/dev/null)
tp_eq "auto-size: values-list still works" "rg=us-east-1" "$out"

tp_summary
