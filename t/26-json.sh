#!/bin/sh
# 26 - --json / --json-array: emit JSON Lines or a single JSON array instead of
# name=value. Values are JSON-escaped; secrets are cleartext. Cancel/error -> no
# stdout (JSON or not).
. "$(dirname "$0")/helpers.sh"

# 1. --json scripted -> one JSON object per input (JSON Lines)
out=$(printf 'example.com\n' | "$TPROMPT_BIN" --scripted --in-shell --json 'h|host|localhost' 2>/dev/null)
tp_eq "json: lines single object" '{"name":"h","value":"example.com"}' "$out"

# 2. multiple inputs -> multiple objects, one per line
out=$(printf 'a\nb\n' | "$TPROMPT_BIN" --scripted --in-shell --json 'h|host|' 'p|port|' 2>/dev/null)
exp=$(printf '{"name":"h","value":"a"}\n{"name":"p","value":"b"}')
tp_eq "json: lines multiple objects" "$exp" "$out"

# 3. --json-array -> a single JSON array on one line
out=$(printf 'a\nb\n' | "$TPROMPT_BIN" --scripted --in-shell --json --json-array 'h|host|' 'p|port|' 2>/dev/null)
tp_eq "json: array form" '[{"name":"h","value":"a"},{"name":"p","value":"b"}]' "$out"

# 4. --json-array alone implies --json (array output without --json)
out=$(printf 'a\n' | "$TPROMPT_BIN" --scripted --in-shell --json-array 'h|host|' 2>/dev/null)
tp_eq "json: --json-array alone works" '[{"name":"h","value":"a"}]' "$out"

# 5. value with a double quote is escaped
out=$(printf 'a"b\n' | "$TPROMPT_BIN" --scripted --in-shell --json 'h|host|' 2>/dev/null)
tp_eq "json: quote escaped" '{"name":"h","value":"a\"b"}' "$out"

# 6. value with a backslash is escaped
out=$(printf 'a\\b\n' | "$TPROMPT_BIN" --scripted --in-shell --json 'h|host|' 2>/dev/null)
tp_eq "json: backslash escaped" '{"name":"h","value":"a\\b"}' "$out"

# 7. secret is emitted in cleartext (entry hidden, value not)
out=$(printf 's3cr3t\n' | "$TPROMPT_BIN" --scripted --in-shell --json '*pw|Password:' 2>/dev/null)
tp_eq "json: secret cleartext" '{"name":"pw","value":"s3cr3t"}' "$out"

# 8. default (no --json) -> still name=value
out=$(printf 'x\n' | "$TPROMPT_BIN" --scripted --in-shell 'h|host|localhost' 2>/dev/null)
tp_eq "json: default still name=value" "h=x" "$out"

# 9. required error in --json mode -> no stdout
out=$(printf '\n' | "$TPROMPT_BIN" --scripted --in-shell --json '!h|host|' 2>/dev/null)
tp_eq "json: error no stdout" "" "$out"

# 10. multi-value stays a single joined string in JSON
out=$(printf '1,3\n' | "$TPROMPT_BIN" --interactive --no-fzf --no-tmux --json --multi 't|tags||a,b,c,d' 2>/dev/null)
tp_eq "json: multi-value joined string" '{"name":"t","value":"a,c"}' "$out"

tp_summary
