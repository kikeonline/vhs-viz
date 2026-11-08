#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
test_log=$(mktemp)
test_errors=$(mktemp)
trap 'rm -f "$test_log" "$test_errors"' EXIT
open -n -W --stdout "$test_log" --stderr "$test_errors" build/VHS.app --args --selftest "$@"
cat "$test_log" "$test_errors"
/usr/bin/grep -q '^SELFTEST done$' "$test_log"
