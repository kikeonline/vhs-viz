#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Inherit the launching terminal's capture permission, then activate this exact test process.
APP_SNAPSHOT=${APP_SNAPSHOT:-/tmp/VHS-shots} build/VHS.app/Contents/MacOS/VHS "$@" &
snapshot_pid=$!
sleep 0.5
osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $snapshot_pid) to true"
wait "$snapshot_pid"
