#!/bin/zsh
set -euo pipefail
# Use the full installed Xcode without changing the machine-wide selection.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
here=${0:A:h}
config=release
[[ " $* " == *" --debug "* ]] && config=debug
cd "$here"
swift build -c "$config" --scratch-path "$here/.build"
bin_dir=$(swift build -c "$config" --scratch-path "$here/.build" --show-bin-path)
tools/make_icon.sh
app="$here/build/VHS.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/VHS" "$app/Contents/MacOS/VHS"
# App-bundled SwiftPM resources are resolved through Bundle.main.resourceURL.
for resource in "$bin_dir"/*.bundle; do
    ditto "$resource" "$app/Contents/Resources/${resource:t}"
done
sed "s/__BUILD__/$(date +%Y%m%d%H%M)/" Info.plist.in > "$app/Contents/Info.plist"
cp Resources/Assets.car Resources/AppIcon.icns "$app/Contents/Resources/"
codesign --force --sign "${SIGN_IDENTITY:--}" "$app"
if [[ " $* " == *" --install "* ]]; then
    mkdir -p "$HOME/Applications"
    ditto "$app" "$HOME/Applications/VHS.app"
    app="$HOME/Applications/VHS.app"
fi
echo "Built $app"
if [[ " $* " == *" --open "* ]]; then
    open "$app"
fi
