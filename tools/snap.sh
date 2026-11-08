#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Inherit the launching terminal's capture permission, then activate the registered app.
APP_SNAPSHOT=${APP_SNAPSHOT:-/tmp/VHS-shots} build/VHS.app/Contents/MacOS/VHS "$@" &
snapshot_pid=$!
sleep 0.5
open build/VHS.app
wait "$snapshot_pid"
