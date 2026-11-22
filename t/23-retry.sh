#!/bin/sh
# 23 - --retry / C retry=: re-prompt up to N times on a required/validate failure
# before canceling. Default 0 (fail fast). Counter is per-input. Scripted mode
# ignores --retry (with a stderr notice). Composes with required + validate.
. "$(dirname "$0")/helpers.sh"

# 1. --retry 0 (default): interactive validate mismatch -> cancel (one shot)
out=$(printf 'abc\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --retry 0 --validate '^[0-9]+$' 'port|port|22' 2>/dev/null)
tp_eq "retry 0: mismatch no stdout" "" "$out"
printf 'abc\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --retry 0 --validate '^[0-9]+$' 'port|port|22' >/dev/null 2>&1
tp_rc "retry 0: mismatch rc" 1 $?

# 2. --retry 2: first bad, second good -> success
out=$(printf 'abc\n22\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --retry 2 --validate '^[0-9]+$' 'port|port|22' 2>/dev/null)
tp_eq "retry 2: bad-then-good succeeds" "port=22" "$out"

# 3. --retry 2: three bad -> cancel after retries exhausted (no stdout)
out=$(printf 'a\nb\nc\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --retry 2 --validate '^[0-9]+$' 'port|port|22' 2>/dev/null)
tp_eq "retry 2: three bad no stdout" "" "$out"
printf 'a\nb\nc\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --retry 2 --validate '^[0-9]+$' 'port|port|22' >/dev/null 2>&1
tp_rc "retry 2: three bad rc" 1 $?

# 4. retry hint format: "invalid: <reason>; try again (n left)"
err=$(printf 'abc\n22\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --retry 2 --validate '^[0-9]+$' 'port|port|22' 2>&1 1>/dev/null)
case "$err" in *"try again (1 left)"*) tp_eq "retry: hint format + count" "ok" "ok" ;; *) tp_eq "retry: hint format + count" "ok" "MISS" ;; esac
case "$err" in *"invalid: does not match ^[0-9]+$"*) tp_eq "retry: hint carries reason" "ok" "ok" ;; *) tp_eq "retry: hint carries reason" "ok" "MISS" ;; esac

# 5. --retry with required: empty then good -> success
out=$(printf '\nx\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --retry 1 '!host|host|' 2>/dev/null)
tp_eq "retry: required empty-then-good" "host=x" "$out"

# 6. per-input counter resets between inputs (first input bad-then-good, second good)
exp6=$(printf 'port=22\nrep=80')
out=$(printf 'abc\n22\n80\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --retry 2 --validate '^[0-9]+$' 'port|port|22' 'rep|replicas|3' 2>/dev/null)
tp_eq "retry: counter resets per input" "$exp6" "$out"

# 7. scripted mode ignores --retry (stderr notice) and still succeeds
out=$(printf '22\n' | "$TPROMPT_BIN" --scripted --in-shell --retry 3 --validate '^[0-9]+$' 'port|port|22' 2>/dev/null)
err=$(printf '22\n' | "$TPROMPT_BIN" --scripted --in-shell --retry 3 --validate '^[0-9]+$' 'port|port|22' 2>&1 1>/dev/null)
tp_eq "retry: scripted still succeeds" "port=22" "$out"
case "$err" in *"--retry has no effect in scripted mode"*) tp_eq "retry: scripted notice" "ok" "ok" ;; *) tp_eq "retry: scripted notice" "ok" "MISS" ;; esac

# 8. --retry with a non-numeric value -> usage error
"$TPROMPT_BIN" --retry abc 'p|p|' >/dev/null 2>&1
tp_rc "retry: non-numeric rc" 1 $?

# 9. C retry= is parsed (print-spec shows it); scripted C ignores it (default used)
c9=/tmp/tp23_c9.txt
printf 'name=h\nprompt=h\ndefault=x\nretry=2\n' > "$c9"
out=$("$TPROMPT_BIN" --scripted --in-shell < "$c9" 2>/dev/null)
tp_eq "retry: C retry= ignored in scripted, default used" "h=x" "$out"
c9v=$("$TPROMPT_BIN" --print-spec < "$c9" 2>/dev/null | awk -F'\t' '{print $11}')
tp_eq "retry: C retry= recorded in print-spec" "2" "$c9v"

# 10. print-spec: retry is the 11th column; empty for a B spec
b11=$("$TPROMPT_BIN" --print-spec 'p|p|d' | awk -F'\t' '{print $11}')
tp_eq "retry: print-spec retry col empty for B" "" "$b11"

tp_summary
