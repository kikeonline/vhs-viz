#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
cmp design/tokens.json Sources/VHSSignal/Resources/tokens.json
# The approved JSON is copied as a package resource. A spec update must update that copy.
if rg -n 'Color\(hex:|\.font\(\.system|cornerRadius: [0-9]|duration: [0-9]' Sources/VHS Sources/VHSGraphUI Sources/VHSPluginUI; then
    echo 'FAIL Signal: raw styling outside shared kit'
    exit 1
fi
echo 'PASS Signal specification and shared styling'
