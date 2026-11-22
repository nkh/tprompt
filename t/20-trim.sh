#!/bin/sh
# 20 - --trim/--no-trim: trim leading/trailing whitespace from answers.
# Default ON for non-secrets, OFF for secrets; C trim=0/trim=1 overrides per spec.
# Runs after the read, before required/--validate (and before ANSI strip).
. "$(dirname "$0")/helpers.sh"

# 1. default trim ON (non-secret): both edges stripped
out=$(printf '  x  \n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 'h|host|' 2>/dev/null)
tp_eq "trim default: strips both edges" "h=x" "$out"

# 2. --no-trim: leading spaces preserved (leading-only keeps the assert clean)
out=$(printf '  x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --no-trim 'h|host|' 2>/dev/null)
tp_eq "no-trim: leading spaces kept" "h=  x" "$out"

# 3. --trim explicit == default behavior
out=$(printf '  x  \n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --trim 'h|host|' 2>/dev/null)
tp_eq "trim explicit: strips both edges" "h=x" "$out"

# 4. secret default OFF: leading spaces preserved
out=$(printf '  pw\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux '*pw|Password:' 2>/dev/null)
tp_eq "secret default: no trim (leading kept)" "pw=  pw" "$out"

# 5. --trim forces secret trim ON (overrides the secret-default-off policy)
out=$(printf '  pw  \n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --trim '*pw|Password:' 2>/dev/null)
tp_eq "trim + secret: forced on" "pw=pw" "$out"

# 6. C default with spaces, no trim key -> default policy (non-secret) trims
c6=/tmp/tp20_c6.txt
printf 'name=h\nprompt=host\ndefault=  x\n' > "$c6"
out=$("$TPROMPT_BIN" --scripted --in-shell < "$c6" 2>/dev/null)
tp_eq "C default trim (policy on)" "h=x" "$out"

# 7. C trim=0 overrides policy -> spaces preserved (leading-only for clean assert)
c7=/tmp/tp20_c7.txt
printf 'name=h\nprompt=host\ndefault=  x\ntrim=0\n' > "$c7"
out=$("$TPROMPT_BIN" --scripted --in-shell < "$c7" 2>/dev/null)
tp_eq "C trim=0: leading spaces kept" "h=  x" "$out"

# 8. C trim=1 overrides global --no-trim
c8=/tmp/tp20_c8.txt
printf 'name=h\nprompt=host\ndefault=  x\ntrim=1\n' > "$c8"
out=$("$TPROMPT_BIN" --scripted --in-shell --no-trim < "$c8" 2>/dev/null)
tp_eq "C trim=1 overrides --no-trim" "h=x" "$out"

# 9. trim runs BEFORE ANSI strip: spaces around ANSI both removed, then ANSI stripped
RED=$(printf '\033[31m'); RST=$(printf '\033[0m')
out=$(printf '  %sred%s  \n' "$RED" "$RST" | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 'h|host|' 2>/dev/null)
tp_eq "trim before ansi-strip" "h=red" "$out"

# 10. print-spec: trim is a column (the 7th); empty for a B spec
ps=$("$TPROMPT_BIN" --print-spec 'h|host|d')
tc=$(printf '%s\n' "$ps" | awk -F'\t' '{print $7}')
tp_eq "print-spec: trim column (7th) empty for B" "" "$tc"

tp_summary
