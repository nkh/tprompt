#!/bin/sh
# 21 - required: '!' prefix (B) / required=1 (C). An empty answer is an error
# (scripted: TPROMPT_ERROR marker; interactive: cancel). '!' combines with '*'
# (secret) in either order. Checked after trim, before --validate.
. "$(dirname "$0")/helpers.sh"

# 1. B '!' scripted empty -> error marker + rc 1 + no stdout
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell '!host|host|' 2>/dev/null)
err=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell '!host|host|' 2>&1 1>/dev/null)
tp_eq "required: empty answer no stdout" "" "$out"
case "$err" in *"required field 'host' is empty"*) tp_eq "required: error message" "ok" "ok" ;; *) tp_eq "required: error message" "ok" "MISSING" ;; esac
printf '\n' | "$TPROMPT_BIN" --scripted --in-shell '!host|host|' >/dev/null 2>&1
tp_rc "required: empty answer rc" 1 $?

# 2. B '!' scripted non-empty -> success
out=$(printf 'example.com\n' | "$TPROMPT_BIN" --scripted --in-shell '!host|host|' 2>/dev/null)
tp_eq "required: non-empty answer" "host=example.com" "$out"

# 3. B '!' WITH a default + empty answer -> still an error (default NOT applied)
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell '!host|host|localhost' 2>/dev/null)
tp_eq "required: default not applied on empty" "" "$out"
printf '\n' | "$TPROMPT_BIN" --scripted --in-shell '!host|host|localhost' >/dev/null 2>&1
tp_rc "required: default-not-applied rc" 1 $?

# 4. B '*!' secret+required scripted non-empty -> success, secret output
out=$(printf 's3cr3t\n' | "$TPROMPT_BIN" --scripted --in-shell '*!pw|Password:' 2>/dev/null)
tp_eq "required: secret+required non-empty" "pw=s3cr3t" "$out"

# 5. B '!*' (reverse order) scripted empty -> error (required fires)
printf '\n' | "$TPROMPT_BIN" --scripted --in-shell '!*pw|Password:' >/dev/null 2>&1
tp_rc "required: !* reverse-order empty rc" 1 $?

# 6. C required=1 + no default + scripted -> error (no value)
c6=/tmp/tp21_c6.txt
printf 'name=host\nprompt=host\nrequired=1\n' > "$c6"
out=$("$TPROMPT_BIN" --scripted --in-shell < "$c6" 2>/dev/null)
tp_eq "required: C required no default no stdout" "" "$out"
$TPROMPT_BIN --scripted --in-shell < "$c6" >/dev/null 2>&1
tp_rc "required: C required no default rc" 1 $?

# 7. C required=1 + default -> success (default is the value)
c7=/tmp/tp21_c7.txt
printf 'name=host\nprompt=host\ndefault=example.com\nrequired=1\n' > "$c7"
out=$("$TPROMPT_BIN" --scripted --in-shell < "$c7" 2>/dev/null)
tp_eq "required: C required with default" "host=example.com" "$out"

# 8. C '!' prefix on the name value -> required is parsed (default satisfies it)
c8=/tmp/tp21_c8.txt
printf 'name=!host\nprompt=host\ndefault=x\n' > "$c8"
out=$("$TPROMPT_BIN" --scripted --in-shell < "$c8" 2>/dev/null)
tp_eq "required: C !prefix + default" "host=x" "$out"

# 9. interactive required empty -> cancel (rc 1, no stdout)
out=$(printf '\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux '!host|host|' 2>/dev/null)
tp_eq "required: interactive empty no stdout" "" "$out"
printf '\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux '!host|host|' >/dev/null 2>&1
tp_rc "required: interactive empty rc" 1 $?

# 10. interactive required non-empty -> success
out=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux '!host|host|' 2>/dev/null)
tp_eq "required: interactive non-empty" "host=x" "$out"

# 11. print-spec: required is the 8th column; '!' sets it to 1 and is stripped from the name
ps=$("$TPROMPT_BIN" --print-spec '!host|h|')
req=$(printf '%s\n' "$ps" | awk -F'\t' '{print $8}')
nm=$(printf '%s\n' "$ps" | awk -F'\t' '{print $1}')
tp_eq "required: print-spec required col=1 for !" "1" "$req"
tp_eq "required: '!' stripped from name in print-spec" "host" "$nm"

# 12. '!' and '*' combine in both orders -> both secret=1, required=1
psa=$("$TPROMPT_BIN" --print-spec '*!pw|p|' | awk -F'\t' '{print $5"|"$8}')
psb=$("$TPROMPT_BIN" --print-spec '!*pw|p|' | awk -F'\t' '{print $5"|"$8}')
tp_eq "required: *! -> secret|required" "1|1" "$psa"
tp_eq "required: !* -> secret|required" "1|1" "$psb"

tp_summary
