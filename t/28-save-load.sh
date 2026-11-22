#!/bin/sh
# 28 - --save / --load: persist answers to a file and pre-fill from it next run.
# Precedence: answer > loaded > spec default. Secrets skipped unless --save-secrets.
# Missing --load file = silent no-op; missing parent dir on --save = hard error.
. "$(dirname "$0")/helpers.sh"

rm -f /tmp/tp28_*.txt 2>/dev/null

# 1. --save writes name=value on success (stdout AND file)
out=$(printf 'x\n' | "$TPROMPT_BIN" --scripted --in-shell --save /tmp/tp28_a.txt 'h|host|localhost' 2>/dev/null)
tp_eq "save: stdout result" "h=x" "$out"
tp_eq "save: file written" "h=x" "$(cat /tmp/tp28_a.txt 2>/dev/null)"

# 2. --save leaves the file untouched on a failed run (cancel/error)
printf 'x\n' | "$TPROMPT_BIN" --scripted --in-shell --save /tmp/tp28_b.txt 'h|host|' >/dev/null 2>&1
printf '' | "$TPROMPT_BIN" --scripted --in-shell --save /tmp/tp28_b.txt 'h|host|' >/dev/null 2>&1   # EOF, no default -> error
tp_eq "save: file untouched on error" "h=x" "$(cat /tmp/tp28_b.txt)"

# 3. --load pre-fills defaults (loaded value used on empty answer)
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell --load /tmp/tp28_a.txt 'h|host|localhost' 2>/dev/null)
tp_eq "load: empty answer uses loaded value" "h=x" "$out"

# 4. precedence: typed answer > loaded > spec default
out=$(printf 'y\n' | "$TPROMPT_BIN" --scripted --in-shell --load /tmp/tp28_a.txt 'h|host|localhost' 2>/dev/null)
tp_eq "load: typed answer wins over loaded" "h=y" "$out"

# 5. --load missing file -> silent no-op (uses spec default; no error)
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell --load /tmp/tp28_nonexist_xyz.txt 'h|host|localhost' 2>/dev/null)
tp_eq "load: missing file no-op (spec default)" "h=localhost" "$out"

# 6. --load honors # comments and blank lines in the answers file
printf '# a comment\n\nh=loaded\n' > /tmp/tp28_c.txt
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell --load /tmp/tp28_c.txt 'h|host|localhost' 2>/dev/null)
tp_eq "load: comments/blanks skipped" "h=loaded" "$out"

# 7. --save skips secrets by default (+ stderr warning); the run still succeeds
out=$(printf 's3cr3t\n' | "$TPROMPT_BIN" --scripted --in-shell --save /tmp/tp28_s.txt '*pw|Password:' 2>/dev/null)
tp_eq "save: secret still on stdout" "pw=s3cr3t" "$out"
tp_eq "save: secret skipped from file" "" "$(cat /tmp/tp28_s.txt 2>/dev/null)"
err=$(printf 's3cr3t\n' | "$TPROMPT_BIN" --scripted --in-shell --save /tmp/tp28_s.txt '*pw|Password:' 2>&1 1>/dev/null)
case "$err" in *"not saving secret field pw"*) tp_eq "save: secret skip warning" "ok" "ok" ;; *) tp_eq "save: secret skip warning" "ok" "MISS" ;; esac

# 8. --save-secrets includes secrets in the file
printf 's3cr3t\n' | "$TPROMPT_BIN" --scripted --in-shell --save-secrets --save /tmp/tp28_s2.txt '*pw|Password:' >/dev/null 2>&1
tp_eq "save: --save-secrets writes secret" "pw=s3cr3t" "$(cat /tmp/tp28_s2.txt)"

# 9. --json + --save are mutually exclusive -> error
"$TPROMPT_BIN" --json --save /tmp/tp28_j.txt 'h|host|' >/dev/null 2>&1
tp_rc "save: --json + --save mutual exclusion rc" 1 $?

# 10. --save to a missing parent dir -> hard error, no stdout
out=$(printf 'x\n' | "$TPROMPT_BIN" --scripted --in-shell --save /tmp/tp28_nodir_xyz/file.txt 'h|host|' 2>/dev/null)
tp_eq "save: missing parent dir no stdout" "" "$out"
printf 'x\n' | "$TPROMPT_BIN" --scripted --in-shell --save /tmp/tp28_nodir_xyz/file.txt 'h|host|' >/dev/null 2>&1
tp_rc "save: missing parent dir rc" 1 $?

# 11. round-trip: save two inputs, load them, confirm both pre-filled
printf 'a\nb\n' | "$TPROMPT_BIN" --scripted --in-shell --save /tmp/tp28_rt.txt 'h|host|' 'p|port|' >/dev/null 2>&1
out=$(printf '\n\n' | "$TPROMPT_BIN" --scripted --in-shell --load /tmp/tp28_rt.txt 'h|host|' 'p|port|' 2>/dev/null)
exp=$(printf 'h=a\np=b')
tp_eq "save/load: round-trip two inputs" "$exp" "$out"

tp_summary
