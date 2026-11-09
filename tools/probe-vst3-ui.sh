#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
swift build -c debug --product VHSPluginProbe
bin_dir=$(swift build -c debug --show-bin-path)
APP_SNAPSHOT=1 "$bin_dir/VHSPluginProbe" "${1:-/tmp/VHS-plugin-shots}"
swift tools/check-layout.swift "${1:-/tmp/VHS-plugin-shots}"/*-layout.json
