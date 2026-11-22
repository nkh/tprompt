# tprompt — integration

tprompt is standalone. Any tool or script can call it. This document describes
the contract a caller should rely on.

## Calling tprompt

Build a spec from your own definition format and pass it as B positionals (or C
stdin):

```
# caller knows the inputs
values=$(tprompt 'host|host to probe|localhost' 'port|port|22|22,80,443') || exit 0  # user cancelled
host=${values#*host=}; host=${host%%$'\n'*}
port=${values#*port=}; port=${port%%$'\n'*}
```

Output is one `name=value` line per input, in order. Parse with `awk -F=` or
shell parameter expansion. Cancel ⇒ non-zero exit, empty stdout.

## Honoring pre-set values (the `--set` contract)

If your caller lets users override an input (`--set host=foo`), do **not** pass
that input to tprompt — pass only the inputs not already satisfied. tprompt
prompts for exactly what it is given:

```
# inputs: host, port. User passed --set host=example.com.
remaining=""  # build the B specs for inputs NOT in --set
[ -z "$host_set" ] && remaining="$remaining 'host|host to probe|localhost'"
[ -z "$port_set" ] && remaining="$remaining 'port|port|22|22,80,443'"
if [ -n "$remaining" ]; then
    values=$(eval tprompt $remaining) || exit 0
    # apply $values
fi
```

## Locating tprompt

Use an option (mirrors `@tum-chooser`):

```
TPROMPT="${TPROMPT:-tprompt}"        # or an absolute path / @tum-prompt option
if command -v "$TPROMPT" >/dev/null 2>&1; then
    values=$("$TPROMPT" "$@")
else
    values=$(my_fallback_read ...)    # caller's own simple read
fi
```

## Fallback when tprompt is absent

A caller should fall back to its own simple `read` for each input when tprompt
is not installed. In tum's case the fallback `read` may run in a tmux pane that
has no interactive shell behind it (a "utility" pane). tum can **swap a shell
in** for the duration of the read using its `tum swap` primitive, then swap
back — guaranteeing the `read` always lands somewhere. That guarantee is the
caller's responsibility; tprompt itself just prompts.

## Why a separate project

- tprompt has no tum dependency, so it is reusable by other tools and testable
  in isolation.
- The rendering (popup + fzf + numbered fallback) and the multi-input loop are
  non-trivial; factoring them out keeps the caller simple.
- A caller that only needs a simple `read` can ignore tprompt entirely and lose
  nothing.

## Testing the integration

Drive tprompt from your caller's tests the same way tprompt's own tests do:

- `--scripted` with piped answer lines for the non-interactive path.
- `--interactive --picker numbered --in-shell` with piped indices for the
  picker path.
- `--no-tmux --no-fzf` to force deterministic degradation in CI.
- `--print-spec` to assert the caller built the right spec before prompting.
