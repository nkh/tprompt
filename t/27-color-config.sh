#!/bin/sh
# 27 - configurable color: --label-color / --default-color / --theme (global) and
# C label-color=/default-color= (per spec). Named colors + styles, or raw SGR.
. "$(dirname "$0")/helpers.sh"

ESC=$(printf '\033'); RST=$(printf '\033[0m')
BOLD_RED=$(printf '\033[1;31m'); BOLD_BLUE=$(printf '\033[1;34m'); BLUE=$(printf '\033[34m')
BOLD_WHITE=$(printf '\033[1;37m'); DIM_WHITE=$(printf '\033[2;37m'); BLACK=$(printf '\033[30m')
NAME_CSI="${ESC}[1;36m"; DEF_CSI="${ESC}[2;33m"   # 0.2.0 defaults

# 1. --label-color "bold red" -> label is bold red (default hint stays dim yellow)
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=always --label-color "bold red" 'h|host|localhost' 2>&1 1>/dev/null)
case "$err" in *"${BOLD_RED}host${RST}"*) tp_eq "color: --label-color bold red" "ok" "ok" ;; *) tp_eq "color: --label-color bold red" "ok" "MISS" ;; esac

# 2. --default-color "dim white" -> default hint is dim white (label stays bold cyan)
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=always --default-color "dim white" 'h|host|localhost' 2>&1 1>/dev/null)
case "$err" in *"${DIM_WHITE}localhost${RST}"*) tp_eq "color: --default-color dim white" "ok" "ok" ;; *) tp_eq "color: --default-color dim white" "ok" "MISS" ;; esac

# 3. --theme dark -> label bold blue, default dim white
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=always --theme dark 'h|host|localhost' 2>&1 1>/dev/null)
case "$err" in *"${BOLD_BLUE}host${RST}"*"${DIM_WHITE}localhost${RST}"*) tp_eq "color: theme dark" "ok" "ok" ;; *) tp_eq "color: theme dark" "ok" "MISS" ;; esac

# 4. --theme light -> label blue, default black
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=always --theme light 'h|host|localhost' 2>&1 1>/dev/null)
case "$err" in *"${BLUE}host${RST}"*"${BLACK}localhost${RST}"*) tp_eq "color: theme light" "ok" "ok" ;; *) tp_eq "color: theme light" "ok" "MISS" ;; esac

# 5. --theme high-contrast -> label bold white
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=always --theme high-contrast 'h|host|localhost' 2>&1 1>/dev/null)
case "$err" in *"${BOLD_WHITE}host${RST}"*) tp_eq "color: theme high-contrast" "ok" "ok" ;; *) tp_eq "color: theme high-contrast" "ok" "MISS" ;; esac

# 6. --theme bad -> usage error
"$TPROMPT_BIN" --theme bad 'h|host|' >/dev/null 2>&1
tp_rc "color: bad theme rc" 1 $?

# 7. raw SGR --label-color "1;31" == bold red
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=always --label-color "1;31" 'h|host|localhost' 2>&1 1>/dev/null)
case "$err" in *"${BOLD_RED}host${RST}"*) tp_eq "color: raw SGR label-color" "ok" "ok" ;; *) tp_eq "color: raw SGR label-color" "ok" "MISS" ;; esac

# 8. no overrides -> 0.2.0 defaults unchanged (bold cyan label, dim yellow default)
err=$(printf 'x\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --color=always 'h|host|localhost' 2>&1 1>/dev/null)
case "$err" in *"${NAME_CSI}host${RST}"*"${DEF_CSI}localhost${RST}"*) tp_eq "color: defaults unchanged" "ok" "ok" ;; *) tp_eq "color: defaults unchanged" "ok" "MISS" ;; esac

# 9. per-spec C label-color= is recorded in the record (print-spec col 12)
c9=$(printf 'name=h\nprompt=host\ndefault=x\nlabel-color=red\ndefault-color=blue\n' | "$TPROMPT_BIN" --print-spec 2>/dev/null | awk -F'\t' '{print $12"|"$13}')
tp_eq "color: per-spec C label/default-color recorded" "red|blue" "$c9"

# 10. print-spec: label-color/default-color are columns 12/13; empty for a B spec
b12=$("$TPROMPT_BIN" --print-spec 'h|host|d' | awk -F'\t' '{print $12"|"$13}')
tp_eq "color: print-spec cols 12/13 empty for B" "|" "$b12"

tp_summary
