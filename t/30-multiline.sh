#!/bin/sh
# 30 - --multiline: read a block until a sentinel line (default '.') or EOF.
# Blank lines are part of the block; the sentinel is excluded. --sentinel '' =
# EOF-terminated. Values-list inputs ignore it. Multi-line values carry embedded
# newlines in the output (NUL-separated result protocol handles the count).
. "$(dirname "$0")/helpers.sh"

# 1. scripted: block until sentinel '.'
exp=$(printf 'desc=line1\nline2')
out=$(printf 'line1\nline2\n.\n' | "$TPROMPT_BIN" --scripted --in-shell --multiline 'desc|description|' 2>/dev/null)
tp_eq "multiline: block until sentinel" "$exp" "$out"

# 2. custom sentinel
exp=$(printf 'd=a\nb')
out=$(printf 'a\nb\n---\n' | "$TPROMPT_BIN" --scripted --in-shell --multiline --sentinel '---' 'd|desc|' 2>/dev/null)
tp_eq "multiline: custom sentinel" "$exp" "$out"

# 3. EOF-terminated (--sentinel '')
exp=$(printf 'd=a\nb')
out=$(printf 'a\nb\n' | "$TPROMPT_BIN" --scripted --in-shell --multiline --sentinel '' 'd|desc|' 2>/dev/null)
tp_eq "multiline: EOF-terminated" "$exp" "$out"

# 4. blank lines are part of the block (not a terminator)
exp=$(printf 'd=a\n\nb')
out=$(printf 'a\n\nb\n.\n' | "$TPROMPT_BIN" --scripted --in-shell --multiline 'd|desc|' 2>/dev/null)
tp_eq "multiline: blank lines kept" "$exp" "$out"

# 5. sentinel excluded from the block (covered by #1; explicit check)
out=$(printf 'a\n.\n' | "$TPROMPT_BIN" --scripted --in-shell --multiline 'd|desc|' 2>/dev/null)
tp_eq "multiline: sentinel excluded" "d=a" "$out"

# 6. default on an empty block (sentinel immediately)
out=$(printf '.\n' | "$TPROMPT_BIN" --scripted --in-shell --multiline 'd|desc|defaultval' 2>/dev/null)
tp_eq "multiline: default on empty block" "d=defaultval" "$out"

# 7. values-list input ignores --multiline (still a single pick)
out=$(printf '1\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --multiline 's|x||a,b,c' 2>/dev/null)
tp_eq "multiline: values-list ignores it" "s=a" "$out"

# 8. interactive multiline (piped input, sentinel terminates)
exp=$(printf 'd=a\nb')
out=$(printf 'a\nb\n.\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --multiline 'd|desc|' 2>/dev/null)
tp_eq "multiline: interactive block" "$exp" "$out"

# 9. C multiline=1 / sentinel= are recorded (print-spec cols 15/16)
c9=$(printf 'name=d\nprompt=desc\nmultiline=1\nsentinel=.\n' | "$TPROMPT_BIN" --print-spec 2>/dev/null | awk -F'\t' '{print $15"|"$16}')
tp_eq "multiline: C multiline/sentinel recorded" "1|." "$c9"

# 10. --json escapes the embedded newlines in a multi-line value
out=$(printf 'line1\nline2\n.\n' | "$TPROMPT_BIN" --scripted --in-shell --json --multiline 'd|desc|' 2>/dev/null)
tp_eq "multiline: json escapes newlines" '{"name":"d","value":"line1\nline2"}' "$out"

tp_summary
