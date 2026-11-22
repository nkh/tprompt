#!/bin/sh
# 15 - --internal-collect (the mode tmux popup re-enters; also directly testable)
. "$(dirname "$0")/helpers.sh"

US=$(printf '\037')   # internal spec field separator (ASCII Unit Separator)
spec=$(mktemp /tmp/tpit.XXXXXX)
res=$(mktemp /tmp/tpit.XXXXXX)
trap 'rm -f "$spec" "$res"' EXIT

# spec: host with default localhost; pipe answer 'alice'
printf 'host%s%s%slocalhost%s\n' "$US" "$US" "$US" "$US" > "$spec"
printf 'alice\n' | "$TPROMPT_BIN" --internal-collect "$spec" "$res" 2>/dev/null
tp_rc "internal-collect rc" 0 $?
tp_eq "internal-collect result" "host=alice" "$(tr '\000' '\n' < "$res")"

# no default, no answer => error marker + non-zero
printf 'host%sh%s%s%s\n' "$US" "$US" "$US" "$US" > "$spec"
: > "$res"
printf '' | "$TPROMPT_BIN" --internal-collect "$spec" "$res" 2>/dev/null
tp_rc "internal-collect no-answer rc" 2 $?
tp_eq "internal-collect error marker" "TPROMPT_ERROR:no value for host (no answer, no default)" "$(tr '\000' '\n' < "$res")"

# interactive internal-collect: pipe an index for a values list
printf 'port%sport%s22%s22,80,443\n' "$US" "$US" "$US" > "$spec"
: > "$res"
printf '2\n' | "$TPROMPT_BIN" --interactive --internal-collect "$spec" "$res" 2>/dev/null
tp_rc "internal-collect interactive rc" 0 $?
tp_eq "internal-collect interactive result" "port=80" "$(tr '\000' '\n' < "$res")"

tp_summary
