#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
tools/build-vst3.sh
swift build -c debug --product VHSPluginProbe
fixture_dir=$(mktemp -d)
trap 'rm -rf "$fixture_dir"' EXIT
bin_dir=$(swift build -c debug --show-bin-path)
"$bin_dir/VHSPluginProbe" --state-fixture "$fixture_dir/graph.json"
.build/vst3/bin/Debug/VHSProcessorTests "$fixture_dir/graph.json"
.build/vst3/bin/Debug/validator "build/VHS.vst3"
codesign --verify --strict "build/VHS.vst3"
file "build/VHS.vst3/Contents/MacOS/VHS"
