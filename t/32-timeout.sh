#!/bin/sh
# 32 - --timeout: cancel the run after N seconds (background alarm + SIGALRM trap).
# A timeout is a cancel (exit non-zero, no stdout). Does not fire if input arrives
# in time. Bad value -> usage error.
. "$(dirname "$0")/helpers.sh"

# 1. timeout fires during a blocked read -> cancel (no stdout, rc 1, stderr msg)
out=$(sleep 3 | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --timeout 1 'h|host|' 2>/dev/null)
tp_eq "timeout: fires on blocked read (no stdout)" "" "$out"
sleep 3 | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --timeout 1 'h|host|' >/dev/null 2>&1
tp_rc "timeout: fires on blocked read rc" 1 $?
err=$(sleep 3 | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --timeout 1 'h|host|' 2>&1 1>/dev/null)
case "$err" in *"timed out after 1s"*) tp_eq "timeout: stderr message" "ok" "ok" ;; *) tp_eq "timeout: stderr message" "ok" "MISS" ;; esac

# 2. timeout does NOT fire if input arrives in time -> success
out=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --timeout 5 'h|host|' 2>/dev/null)
tp_eq "timeout: input in time succeeds" "h=x" "$out"

# 3. --timeout 0 = off (no timeout)
out=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --timeout 0 'h|host|' 2>/dev/null)
tp_eq "timeout: 0 = off" "h=x" "$out"

# 4. non-numeric --timeout -> usage error
"$TPROMPT_BIN" --timeout abc 'h|host|' >/dev/null 2>&1
tp_rc "timeout: non-numeric rc" 1 $?

# 5. timeout in scripted mode fires on a blocked stdin too
out=$(sleep 3 | "$TPROMPT_BIN" --scripted --in-shell --timeout 1 'h|host|' 2>/dev/null)
tp_eq "timeout: scripted blocked stdin (no stdout)" "" "$out"

tp_summary
