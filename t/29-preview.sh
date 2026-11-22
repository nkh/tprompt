#!/bin/sh
# 29 - preview: per-spec fzf --preview command. B pv:-prefixed field (any
# position, parallel to qr:) or C preview= key. Only effective for the fzf
# picker; numbered/external ignore it. These tests cover parsing (the fzf path
# needs a real fzf + tty); numbered picker ignores it.
. "$(dirname "$0")/helpers.sh"

# 1. B pv: prefix recorded in print-spec (col 14); values list kept
ps=$("$TPROMPT_BIN" --print-spec 'man|man page||git.1,git-add.1|pv:man {}')
v14=$(printf '%s\n' "$ps" | awk -F'\t' '{print $14}')
vals=$(printf '%s\n' "$ps" | awk -F'\t' '{print $4}')
nm=$(printf '%s\n' "$ps" | awk -F'\t' '{print $1}')
tp_eq "preview: B pv: recorded" "man {}" "$v14"
tp_eq "preview: values list kept" "git.1,git-add.1" "$vals"
tp_eq "preview: name kept" "man" "$nm"

# 2. pv: position-independent (after a values list, with default)
ps=$("$TPROMPT_BIN" --print-spec 'host|host||host-a,host-b,host-c|pv:ping -c1 -W1 {}')
v14=$(printf '%s\n' "$ps" | awk -F'\t' '{print $14}')
tp_eq "preview: pv position-independent" "ping -c1 -W1 {}" "$v14"

# 3. C preview= key recorded
c3=$(printf 'name=man\nprompt=man page\nvalues=git.1,git-add.1\npreview=man {}\n' | "$TPROMPT_BIN" --print-spec 2>/dev/null | awk -F'\t' '{print $14}')
tp_eq "preview: C preview= recorded" "man {}" "$c3"

# 4. pv: and qr: coexist (both prefix-detected)
ps=$("$TPROMPT_BIN" --print-spec 'port|port||22,80,443|qr:^[0-9]+$|pv:echo {}')
v9=$(printf '%s\n' "$ps" | awk -F'\t' '{print $9}')
v14=$(printf '%s\n' "$ps" | awk -F'\t' '{print $14}')
vals=$(printf '%s\n' "$ps" | awk -F'\t' '{print $4}')
tp_eq "preview: qr: + pv: coexist (validate)" "^[0-9]+$" "$v9"
tp_eq "preview: qr: + pv: coexist (preview)" "echo {}" "$v14"
tp_eq "preview: qr: + pv: coexist (values)" "22,80,443" "$vals"

# 5. numbered picker ignores preview (still picks correctly)
out=$(printf '1\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 's|x||a,b,c|pv:echo {}' 2>/dev/null)
tp_eq "preview: numbered picker ignores it" "s=a" "$out"

# 6. print-spec: preview is col 14; empty for a spec without pv:/preview=
b14=$("$TPROMPT_BIN" --print-spec 'h|host|d' | awk -F'\t' '{print $14}')
tp_eq "preview: col 14 empty without pv:" "" "$b14"

tp_summary
