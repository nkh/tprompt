#!/bin/sh
# 08 - tmux-absent degradation (--popup / --new-shell fall back to in-shell)
. "$(dirname "$0")/helpers.sh"

# --popup with no tmux => stderr note + in-shell behavior
err=$(printf 'x\n' | "$TPROMPT_BIN" --popup --scripted 'k|k|def' 2>&1 >/dev/null)
tp_eq "popup degrade stderr" "tprompt: tmux unavailable; falling back to --in-shell" "$err"

out=$(printf 'x\n' | "$TPROMPT_BIN" --popup --scripted 'k|k|def' 2>/dev/null)
tp_eq "popup degrade still works" "k=x" "$out"

# --no-tmux silences the warning (forces in-shell)
err=$(printf 'x\n' | "$TPROMPT_BIN" --no-tmux --popup --scripted 'k|k|def' 2>&1 >/dev/null)
tp_eq "no-tmux flag silences warning" "" "$err"
out=$(printf 'x\n' | "$TPROMPT_BIN" --no-tmux --popup --scripted 'k|k|def' 2>/dev/null)
tp_eq "no-tmux flag works" "k=x" "$out"

# --new-shell degrades to in-shell too
out=$(printf 'x\n' | "$TPROMPT_BIN" --new-shell --scripted 'k|k|def' 2>/dev/null)
tp_eq "new-shell degrade works" "k=x" "$out"

tp_summary
