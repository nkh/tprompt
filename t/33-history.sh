#!/bin/sh
# 33 - --history: pre-fill each input's default with the last prior value for its
# name from a history file, and append this run's name=value on success (secrets
# skipped unless --save-secrets). Missing file = no pre-fill (but is created on
# append).
. "$(dirname "$0")/helpers.sh"

rm -f /tmp/tp33_*.txt 2>/dev/null

# 1. first run: appends name=value to the history file
out=$(printf 'alice\n' | "$TPROMPT_BIN" --scripted --in-shell --history /tmp/tp33_h.txt 'h|host|' 2>/dev/null)
tp_eq "history: stdout result" "h=alice" "$out"
tp_eq "history: appended to file" "h=alice" "$(cat /tmp/tp33_h.txt 2>/dev/null)"

# 2. second run: default pre-filled with the last prior value (alice)
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell --history /tmp/tp33_h.txt 'h|host|localhost' 2>/dev/null)
tp_eq "history: default pre-filled from last value" "h=alice" "$out"

# 3. a newer value wins as the default (last entry per name)
printf 'h=carol\n' >> /tmp/tp33_h.txt   # carol is now the last h= entry
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell --history /tmp/tp33_h.txt 'h|host|localhost' 2>/dev/null)
tp_eq "history: last entry wins as default" "h=carol" "$out"

# 4. typed answer still wins over the history default
out=$(printf 'dave\n' | "$TPROMPT_BIN" --scripted --in-shell --history /tmp/tp33_h.txt 'h|host|localhost' 2>/dev/null)
tp_eq "history: typed answer wins" "h=dave" "$out"

# 5. secrets skipped from the history (unless --save-secrets)
printf 's3cr3t\n' | "$TPROMPT_BIN" --scripted --in-shell --history /tmp/tp33_sec.txt '*pw|Password:' >/dev/null 2>&1
tp_eq "history: secret skipped" "" "$(cat /tmp/tp33_sec.txt 2>/dev/null)"
printf 's3cr3t\n' | "$TPROMPT_BIN" --scripted --in-shell --save-secrets --history /tmp/tp33_sec2.txt '*pw|Password:' >/dev/null 2>&1
tp_eq "history: --save-secrets writes secret" "pw=s3cr3t" "$(cat /tmp/tp33_sec2.txt 2>/dev/null)"

# 6. multiple inputs all appended
printf 'a\nb\n' | "$TPROMPT_BIN" --scripted --in-shell --history /tmp/tp33_multi.txt 'h|host|' 'p|port|' >/dev/null 2>&1
exp=$(printf 'h=a\np=b')
tp_eq "history: multiple inputs appended" "$exp" "$(cat /tmp/tp33_multi.txt 2>/dev/null)"

# 7. missing history file -> no pre-fill (spec default used); file created on append
out=$(printf 'x\n' | "$TPROMPT_BIN" --scripted --in-shell --history /tmp/tp33_new.txt 'h|host|localhost' 2>/dev/null)
tp_eq "history: missing file no pre-fill (uses answer)" "h=x" "$out"
tp_eq "history: missing file created on append" "h=x" "$(cat /tmp/tp33_new.txt 2>/dev/null)"

tp_summary
