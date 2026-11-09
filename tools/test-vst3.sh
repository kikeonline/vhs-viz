#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
tools/build-vst3.sh
.build/vst3/bin/Debug/VHSPrototypeTests
.build/vst3/bin/Debug/validator "build/VHS Phase 3A.vst3"
codesign --verify --strict "build/VHS Phase 3A.vst3"
file "build/VHS Phase 3A.vst3/Contents/MacOS/VHSPrototype"
