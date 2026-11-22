#!/bin/sh
# 31 - editor: a file: prefix on the default opens $VISUAL/$EDITOR/vi on a temp
# file pre-filled with the template (the text after file:); the saved content
# (one trailing newline trimmed) is the value. Scripted mode uses the template as
# the value (no editor). Multi-line values flow through the NUL result protocol.
. "$(dirname "$0")/helpers.sh"

# fake editors
ed1=/tmp/tp31_ed1.sh; printf '#!/bin/sh\nprintf "edited content\\n" > "$1"\n' > "$ed1"; chmod +x "$ed1"
ed2=/tmp/tp31_ed2.sh; printf '#!/bin/sh\nprintf "edited\\n" >> "$1"\n' > "$ed2"; chmod +x "$ed2"
ed3=/tmp/tp31_ed3.sh; printf '#!/bin/sh\n: > "$1"\n' > "$ed3"; chmod +x "$ed3"            # empty result
ed4=/tmp/tp31_ed4.sh; printf '#!/bin/sh\nprintf "line1\\nline2\\n" > "$1"\n' > "$ed4"; chmod +x "$ed4"

# 1. interactive: editor writes the value
out=$(VISUAL="$ed1" EDITOR="$ed1" "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 'msg|message|file:' 2>/dev/null)
tp_eq "editor: interactive value" "msg=edited content" "$out"

# 2. template pre-fill: editor appends to the pre-filled template
out=$(VISUAL="$ed2" EDITOR="$ed2" "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 'msg|message|file:template-' 2>/dev/null)
tp_eq "editor: template pre-filled + appended" "msg=template-edited" "$out"

# 3. scripted: the template is the value (no editor opens)
out=$(printf '' | "$TPROMPT_BIN" --scripted --in-shell 'msg|message|file:template text' 2>/dev/null)
tp_eq "editor: scripted uses template" "msg=template text" "$out"

# 4. editor unavailable (EDITOR points nowhere) -> error, no stdout
out=$(VISUAL= EDITOR=/tmp/tp31_nonexistent_xyz "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 'msg|message|file:' 2>/dev/null)
tp_eq "editor: unavailable no stdout" "" "$out"
VISUAL= EDITOR=/tmp/tp31_nonexistent_xyz "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 'msg|message|file:' >/dev/null 2>&1
tp_rc "editor: unavailable rc" 1 $?

# 5. required editor + empty result -> cancel (no stdout)
out=$(VISUAL="$ed3" EDITOR="$ed3" "$TPROMPT_BIN" --interactive --no-fzf --no-tmux '!msg|message|file:' 2>/dev/null)
tp_eq "editor: required empty -> cancel" "" "$out"

# 6. multi-line editor value (carries embedded newlines via the NUL protocol)
out=$(VISUAL="$ed4" EDITOR="$ed4" "$TPROMPT_BIN" --interactive --no-fzf --no-tmux 'msg|message|file:' 2>/dev/null)
exp=$(printf 'msg=line1\nline2')
tp_eq "editor: multi-line value" "$exp" "$out"

# 7. C file: default (scripted -> template is the value)
c7=$(printf 'name=msg\nprompt=message\ndefault=file:from C\n' | "$TPROMPT_BIN" --scripted --in-shell 2>/dev/null)
tp_eq "editor: C file: default scripted" "msg=from C" "$c7"

# 8. file: with empty template, scripted -> empty value -> no-value error
out=$(printf '' | "$TPROMPT_BIN" --scripted --in-shell 'msg|message|file:' 2>/dev/null)
tp_eq "editor: empty template scripted no stdout" "" "$out"
printf '' | "$TPROMPT_BIN" --scripted --in-shell 'msg|message|file:' >/dev/null 2>&1
tp_rc "editor: empty template scripted rc" 1 $?

tp_summary
