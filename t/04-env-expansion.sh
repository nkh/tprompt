#!/bin/sh
# 04 - environment expansion ($VAR, ${VAR})
. "$(dirname "$0")/helpers.sh"

# $VAR in default, via --print-spec (extract default column = field 3)
def=$(TP_USER=bob "$TPROMPT_BIN" --print-spec 'name|n|$TP_USER' | awk -F'\t' 'NR==1{print $3}')
tp_eq "env \$TP_USER" "bob" "$def"

# ${VAR} in default
def=$(TP_USER=bob "$TPROMPT_BIN" --print-spec 'host|h|${TP_USER}.local' | awk -F'\t' '{print $3}')
tp_eq "env \${TP_USER}.local" "bob.local" "$def"

# env in prompt field (field 2)
pr=$(TP_USER=bob "$TPROMPT_BIN" --print-spec 'k|hi $TP_USER|d' | awk -F'\t' '{print $2}')
tp_eq "env in prompt" "hi bob" "$pr"

# C spec env expansion
out=$(TP_H=example.com "$TPROMPT_BIN" --in-shell <<'EOF'
name=host
default=$TP_H
EOF
)
tp_eq "c env expansion" "host=example.com" "$out"

# unset var expands to empty
def=$(unset TP_NONEXISTENT_999; "$TPROMPT_BIN" --print-spec 'k|k|$TP_NONEXISTENT_999' | awk -F'\t' '{print $3}')
tp_eq "unset env => empty" "" "$def"

tp_summary
