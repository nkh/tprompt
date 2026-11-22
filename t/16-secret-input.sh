#!/bin/sh
# 16 - secret input: leading '*' on the name hides entry; '*' is stripped.
. "$(dirname "$0")/helpers.sh"

# '*' prefix is stripped; secret flag is 1 in the normalized record (col 5)
f=$("$TPROMPT_BIN" --print-spec '*pw|Password:' | awk -F'\t' '{print $1"|"$5}')
tp_eq "secret: star stripped, flag set" "pw|1" "$f"

# a non-secret input has flag 0
f=$("$TPROMPT_BIN" --print-spec 'host|h|localhost' | awk -F'\t' '{print $1"|"$5}')
tp_eq "secret: plain flag 0" "host|0" "$f"

# secret scripted: empty answer -> default used (silently); output key is bare name
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell '*pw|Password|fallback')
tp_eq "secret: empty -> default" "pw=fallback" "$out"

# secret scripted: a provided answer is output verbatim (entry is hidden in
# interactive mode; in scripted mode the value comes from stdin)
out=$(printf 's3cr3t\n' | "$TPROMPT_BIN" --scripted --in-shell '*pw|Password|fallback')
tp_eq "secret: answer verbatim" "pw=s3cr3t" "$out"

# secret scripted: no default + EOF -> error, no stdout
out=$(printf '' | "$TPROMPT_BIN" --scripted --in-shell '*pw|Password' 2>/dev/null)
tp_rc "secret: no default EOF rc" 1 $?
tp_eq "secret: no default EOF no stdout" "" "$out"

# C spec: name=*pw sets secret; secret=1 key also sets it
f=$(printf 'name=*pw\nprompt=Password:\n' | "$TPROMPT_BIN" --print-spec | awk -F'\t' '{print $1"|"$5}')
tp_eq "secret: C name=* prefix" "pw|1" "$f"
f=$(printf 'name=pw\nprompt=Password:\nsecret=1\n' | "$TPROMPT_BIN" --print-spec | awk -F'\t' '{print $1"|"$5}')
tp_eq "secret: C secret=1 key" "pw|1" "$f"

tp_summary
