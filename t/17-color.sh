#!/bin/sh
# 17 - --color: label/default coloring on stderr; ANSI stripped from output.
. "$(dirname "$0")/helpers.sh"

ESC=$(printf '\033')
RED=$(printf '\033[31m'); RST=$(printf '\033[0m')
NAME_CSI="${ESC}[1;36m"; DEF_CSI="${ESC}[2;33m"

# --color=never: no ANSI escapes in the stderr prompt
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=never 'h|host|localhost' 2>&1 1>/dev/null)
case "$err" in
    *"$ESC"*) tp_eq "color=never: no CSI in stderr" "no-esc" "has-esc" ;;
    *)         tp_eq "color=never: no CSI in stderr" "no-esc" "no-esc" ;;
esac

# --color=always: the label and the default hint carry ANSI
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=always 'h|host|localhost' 2>&1 1>/dev/null)
case "$err" in
    *"${NAME_CSI}host${RST}"*"${DEF_CSI}localhost${RST}"*)
        tp_eq "color=always: name+default colored" "colored" "colored" ;;
    *) tp_eq "color=always: name+default colored" "colored" "not-colored" ;;
esac

# --color=bad mode -> usage error
"$TPROMPT_BIN" --color=bad 'h|h|' >/dev/null 2>&1
tp_rc "color=bad: usage error rc" 1 $?

# ANSI in a values list is stripped from the output (numbered pick, index 1)
spec="c|c||${RED}red${RST},green"
out=$(printf '1\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=never "$spec" 2>/dev/null)
tp_eq "color: ANSI stripped from picked value" "c=red" "$out"

# ANSI in a C default is stripped from the scripted output
printf 'name=c\nprompt=c\ndefault=%sred%s,green\n' "$RED" "$RST" > /tmp/tp17_c.txt
out=$("$TPROMPT_BIN" --scripted --in-shell < /tmp/tp17_c.txt)
tp_eq "color: ANSI stripped from C default" "c=red,green" "$out"

# multi pick with ANSI values: stripped AND joined
out=$(printf '1,2\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=never --multi "$spec" 2>/dev/null)
tp_eq "color: multi ANSI stripped + joined" "c=red,green" "$out"

tp_summary
