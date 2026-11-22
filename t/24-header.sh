#!/bin/sh
# 24 - --header / --header-file: a banner to stderr once before the first prompt
# (colored with the label color when --color is on); passed to fzf as --header.
# --header and --header-file are mutually exclusive; a missing file is a hard error.
. "$(dirname "$0")/helpers.sh"

ESC=$(printf '\033')
NAME_CSI="${ESC}[1;36m"; RST="${ESC}[0m"

# 1. --header prints the banner to stderr (before the prompt)
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --header "Deploy config — prod" 'h|host|' 2>&1 1>/dev/null)
case "$err" in *"Deploy config — prod"*) tp_eq "header: banner on stderr" "ok" "ok" ;; *) tp_eq "header: banner on stderr" "ok" "MISS" ;; esac

# 2. the banner is NOT on stdout (only the name=value result)
out=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --header "Deploy config" 'h|host|' 2>/dev/null)
tp_eq "header: result on stdout" "h=x" "$out"
case "$out" in *"Deploy config"*) tp_eq "header: no banner on stdout" "ok" "MISS" ;; *) tp_eq "header: no banner on stdout" "ok" "ok" ;; esac

# 3. --color=always: the banner is colored with the label color
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=always --header "BANNER" 'h|host|' 2>&1 1>/dev/null)
case "$err" in *"${NAME_CSI}BANNER${RST}"*) tp_eq "header: colored with label color" "ok" "ok" ;; *) tp_eq "header: colored with label color" "ok" "MISS" ;; esac

# 4. --color=never: the banner is plain (no CSI)
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=never --header "BANNER" 'h|host|' 2>&1 1>/dev/null)
case "$err" in *"$ESC"*) tp_eq "header: plain when color=never" "ok" "MISS" ;; *) tp_eq "header: plain when color=never" "ok" "ok" ;; esac

# 5. --header-file reads the banner from a file
hf=/tmp/tp24_banner.txt
printf 'Step 2 of 4: database\n' > "$hf"
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --header-file "$hf" 'h|host|' 2>&1 1>/dev/null)
case "$err" in *"Step 2 of 4: database"*) tp_eq "header-file: banner from file" "ok" "ok" ;; *) tp_eq "header-file: banner from file" "ok" "MISS" ;; esac

# 6. multi-line header (from a file) is preserved
printf 'line one\nline two\n' > "$hf"
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --header-file "$hf" 'h|host|' 2>&1 1>/dev/null)
case "$err" in *"line one"*"line two"*) tp_eq "header: multi-line preserved" "ok" "ok" ;; *) tp_eq "header: multi-line preserved" "ok" "MISS" ;; esac

# 7. --header and --header-file are mutually exclusive -> error
"$TPROMPT_BIN" --header "X" --header-file "$hf" 'h|host|' >/dev/null 2>&1
tp_rc "header: +header-file mutual exclusion rc" 1 $?

# 8. --header-file missing -> hard error
"$TPROMPT_BIN" --header-file /tmp/tp24_does_not_exist_xyz.txt 'h|host|' >/dev/null 2>&1
tp_rc "header: missing header-file rc" 1 $?

# 9. no --header -> no banner on stderr (just the prompt)
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 'h|host|' 2>&1 1>/dev/null)
case "$err" in *"Deploy config"*) tp_eq "header: absent when not set" "ok" "MISS" ;; *) tp_eq "header: absent when not set" "ok" "ok" ;; esac

tp_summary
