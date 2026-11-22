#!/bin/sh
# t/helpers.sh - test helpers, sourced by each test file.
# Not run directly.

TP_TESTS=0
TP_PASS=0
TP_FAIL=0

TPROMPT_BIN="${TPROMPT_BIN:-$(cd "$(dirname "$0")/.." && pwd)/tprompt}"
if [ ! -x "$TPROMPT_BIN" ]; then
    echo "tprompt binary not found at $TPROMPT_BIN" >&2
    exit 2
fi

# tp_eq <desc> <expected> <actual>
tp_eq() {
    TP_TESTS=$((TP_TESTS + 1))
    if [ "$2" = "$3" ]; then
        TP_PASS=$((TP_PASS + 1))
    else
        TP_FAIL=$((TP_FAIL + 1))
        printf 'FAIL: %s\n  expected: [%s]\n  actual:   [%s]\n' "$1" "$2" "$3" >&2
    fi
}

# tp_rc <desc> <expected_rc> <actual_rc>
tp_rc() {
    TP_TESTS=$((TP_TESTS + 1))
    if [ "$2" = "$3" ]; then
        TP_PASS=$((TP_PASS + 1))
    else
        TP_FAIL=$((TP_FAIL + 1))
        printf 'FAIL: %s (rc: expected %s, got %s)\n' "$1" "$2" "$3" >&2
    fi
}

# tp_summary - print pass count, exit non-zero if any failed
tp_summary() {
    printf '  %d/%d passed\n' "$TP_PASS" "$TP_TESTS"
    [ "$TP_FAIL" -eq 0 ]
}
