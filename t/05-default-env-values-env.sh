#!/bin/sh
# 05 - default-env= and values-env= (C explicit env keys)
. "$(dirname "$0")/helpers.sh"

out=$(TP_HOST=example.com TP_PORTS=22,80,443 "$TPROMPT_BIN" --in-shell <<'EOF'
name=host
default-env=TP_HOST

name=port
default=22
values-env=TP_PORTS
EOF
)
tp_rc "default-env/values-env rc" 0 $?
tp_eq "default-env + values-env" "host=example.com
port=22" "$out"

# default-env referencing an unset var => empty default => error (C, scripted, no default)
out=$(unset TP_DEFINITELY_UNSET_42; env -u TP_DEFINITELY_UNSET_42 "$TPROMPT_BIN" --in-shell <<'EOF' 2>/dev/null
name=x
default-env=TP_DEFINITELY_UNSET_42
EOF
)
tp_rc "default-env unset => error" 1 $?
tp_eq "default-env unset no stdout" "" "$out"

tp_summary
