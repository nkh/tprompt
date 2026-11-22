#!/bin/sh
# 22 - --validate / B qr: / C validate= : reject answers that do not match a
# POSIX ERE. qr: is position-independent; values + qr: coexist (pick is checked).
# Global --validate applies to free-text only; picks are exempt unless qr:.
# Checked after required, before emit.
. "$(dirname "$0")/helpers.sh"

# 1. global --validate, scripted match -> success
out=$(printf '22\n' | "$TPROMPT_BIN" --scripted --in-shell --validate '^[0-9]+$' 'port|port|22' 2>/dev/null)
tp_eq "validate: global match" "port=22" "$out"

# 2. global --validate, scripted mismatch -> error + rc 1 + no stdout
out=$(printf 'abc\n' | "$TPROMPT_BIN" --scripted --in-shell --validate '^[0-9]+$' 'port|port|22' 2>/dev/null)
err=$(printf 'abc\n' | "$TPROMPT_BIN" --scripted --in-shell --validate '^[0-9]+$' 'port|port|22' 2>&1 1>/dev/null)
tp_eq "validate: mismatch no stdout" "" "$out"
case "$err" in *"invalid: does not match ^[0-9]+$"*) tp_eq "validate: mismatch message" "ok" "ok" ;; *) tp_eq "validate: mismatch message" "ok" "MISS" ;; esac
printf 'abc\n' | "$TPROMPT_BIN" --scripted --in-shell --validate '^[0-9]+$' 'port|port|22' >/dev/null 2>&1
tp_rc "validate: mismatch rc" 1 $?

# 3. B qr: in the values slot (no values list) -> validate
out=$(printf 'host.com\n' | "$TPROMPT_BIN" --scripted --in-shell 'host|h|localhost|qr:^[a-z][a-z0-9.-]+$' 2>/dev/null)
tp_eq "validate: qr in values slot match" "host=host.com" "$out"
printf 'HOST\n' | "$TPROMPT_BIN" --scripted --in-shell 'host|h|localhost|qr:^[a-z]+$' >/dev/null 2>&1
tp_rc "validate: qr mismatch rc" 1 $?

# 4. values + qr: coexist -> picked value is checked (match and mismatch)
out=$(printf '2\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 's|x||a,bb,ccc|qr:^[a-z]{2}$' 2>/dev/null)
tp_eq "validate: values+qr pick match" "s=bb" "$out"
out=$(printf '3\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 's|x||a,bb,ccc|qr:^[a-z]{2}$' 2>/dev/null)
tp_eq "validate: values+qr pick mismatch no stdout" "" "$out"
printf '3\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 's|x||a,bb,ccc|qr:^[a-z]{2}$' >/dev/null 2>&1
tp_rc "validate: values+qr pick mismatch rc" 1 $?

# 5. qr: is position-independent (qr: at the trailing slot, after values)
ps=$("$TPROMPT_BIN" --print-spec 'h|h|d||qr:^x$')
v9=$(printf '%s\n' "$ps" | awk -F'\t' '{print $9}')
nm=$(printf '%s\n' "$ps" | awk -F'\t' '{print $1}')
tp_eq "validate: qr position-independent -> validate col" "^x$" "$v9"
tp_eq "validate: qr stripped, name kept" "h" "$nm"

# 6. C validate= -> validate (default matches the regex)
c6=/tmp/tp22_c6.txt
printf 'name=host\nprompt=h\ndefault=example\nvalidate=^[a-z]+$\n' > "$c6"
out=$("$TPROMPT_BIN" --scripted --in-shell < "$c6" 2>/dev/null)
tp_eq "validate: C validate= match (default)" "host=example" "$out"

# 7. C validate-error= custom message
c7=/tmp/tp22_c7.txt
printf 'name=host\nprompt=h\ndefault=EXAMPLE\nvalidate=^[a-z]+$\nvalidate-error=lowercase only\n' > "$c7"
err=$("$TPROMPT_BIN" --scripted --in-shell < "$c7" 2>&1 1>/dev/null)
case "$err" in *"lowercase only"*) tp_eq "validate: C validate-error msg" "ok" "ok" ;; *) tp_eq "validate: C validate-error msg" "ok" "MISS" ;; esac

# 8. --validate-error (global) custom message
err=$(printf 'abc\n' | "$TPROMPT_BIN" --scripted --in-shell --validate '^[0-9]+$' --validate-error 'numbers only' 'port|port|22' 2>&1 1>/dev/null)
case "$err" in *"numbers only"*) tp_eq "validate: global validate-error msg" "ok" "ok" ;; *) tp_eq "validate: global validate-error msg" "ok" "MISS" ;; esac

# 9. values-list pick EXEMPT from global --validate (no qr:)
out=$(printf '2\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --validate '^[0-9]+$' 's|x||a,bb,ccc' 2>/dev/null)
tp_eq "validate: pick exempt from global" "s=bb" "$out"

# 10. empty answer + validate (not required) + default -> validate checks the default
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell --validate '^[0-9]+$' 'port|port|22' 2>/dev/null)
tp_eq "validate: empty+default checks default" "port=22" "$out"

# 11. required + validate: required fires first (empty -> required error, not validate)
err=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell --validate '^[0-9]+$' '!port|port|' 2>&1 1>/dev/null)
case "$err" in *"required field 'port' is empty"*) tp_eq "validate: required fires before validate" "ok" "ok" ;; *) tp_eq "validate: required fires before validate" "ok" "MISS" ;; esac

# 12. print-spec: validate is the 9th column; qr: sets it, B without qr: leaves it empty
psa=$("$TPROMPT_BIN" --print-spec 'port|p|22|qr:^[0-9]+$' | awk -F'\t' '{print $9}')
psb=$("$TPROMPT_BIN" --print-spec 'port|p|22' | awk -F'\t' '{print $9}')
tp_eq "validate: print-spec validate col with qr:" "^[0-9]+$" "$psa"
tp_eq "validate: print-spec validate col empty without qr:" "" "$psb"

tp_summary
