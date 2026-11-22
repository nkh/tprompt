#!/bin/sh
# 19 - --specs-from: read B specs from a file (one per line); comments/blanks ignored.
. "$(dirname "$0")/helpers.sh"

# spec file with comments, blanks, and two real specs
f=/tmp/tp19_specs.txt
cat > "$f" <<'EOF'
# tprompt specs for the deploy
host|host to probe|localhost

# port has a values list
port|port|22|22,80,443
EOF

# 1. scripted: one answer line per spec from stdin
exp=$(printf 'host=example.com\nport=443')
out=$(printf 'example.com\n443\n' | "$TPROMPT_BIN" --scripted --in-shell --specs-from "$f")
tp_eq "specs-from: scripted two inputs" "$exp" "$out"

# 2. exactly two output lines (comments/blanks skipped)
lines=$(printf '%s\n' "$out" | wc -l | tr -dc '0-9')
tp_eq "specs-from: comments/blanks skipped (2 lines)" 2 "$lines"

# 3. print-spec: normalized records (check the first 4 columns, robust to later field additions)
row1=$("$TPROMPT_BIN" --print-spec --specs-from "$f" | sed -n 1p | awk -F'\t' '{print $1"|"$2"|"$3"|"$4}')
row2=$("$TPROMPT_BIN" --print-spec --specs-from "$f" | sed -n 2p | awk -F'\t' '{print $1"|"$2"|"$3"|"$4}')
tp_eq "specs-from: print-spec row 1 (name|prompt|default|values)" "host|host to probe|localhost|" "$row1"
tp_eq "specs-from: print-spec row 2 (name|prompt|default|values)" "port|port|22|22,80,443" "$row2"

# 4. missing file -> hard error (rc 1)
"$TPROMPT_BIN" --specs-from /tmp/tp19_does_not_exist_xyz.txt >/dev/null 2>&1
tp_rc "specs-from: missing file rc" 1 $?

# 5. mutual exclusion with positionals -> error
"$TPROMPT_BIN" --specs-from "$f" 'extra|e|' >/dev/null 2>&1
tp_rc "specs-from: + positional rc" 1 $?

# 6. file with only comments/blanks -> no specs -> error
empty=/tmp/tp19_empty.txt
printf '# just a comment\n\n# another\n' > "$empty"
"$TPROMPT_BIN" --specs-from "$empty" >/dev/null 2>&1
tp_rc "specs-from: comments-only file rc" 1 $?

# 7. interactive numbered pick from a values list in the file
vf=/tmp/tp19_vals.txt
printf 'rg|region||us,eu,ap\n' > "$vf"
out=$(printf '2\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --specs-from "$vf" 2>/dev/null)
tp_eq "specs-from: interactive numbered pick" "rg=eu" "$out"

# 8. --specs-from= form (scripted, one answer + default fallback for the 2nd)
out=$(printf 'x\n' | "$TPROMPT_BIN" --scripted --in-shell --specs-from="$f" 2>/dev/null | sed -n 1p)
tp_eq "specs-from: =form works" "host=x" "$out"

tp_summary
