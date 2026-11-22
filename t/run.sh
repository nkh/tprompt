#!/bin/sh
# t/run.sh - run all tprompt tests.
cd "$(dirname "$0")" || exit 2

failed=0
ran=0
for t in [0-9]*.sh; do
    [ "$t" = "run.sh" ] && continue
    [ -f "$t" ] || continue
    ran=$((ran + 1))
    printf -- '--- %s ---\n' "$t"
    sh "./$t"
    rc=$?
    [ "$rc" -ne 0 ] && failed=1
done

printf '\n'
if [ "$failed" -eq 0 ]; then
    printf 'ALL TESTS PASSED (%d files)\n' "$ran"
else
    printf 'SOME TESTS FAILED\n'
fi
exit "$failed"
