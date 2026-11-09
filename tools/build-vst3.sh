#!/bin/zsh
set -euo pipefail
here=${0:A:h:h}
cd "$here"
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
sdk="$here/.build/vst3sdk"
revision=3cdf9ca5d1f5b1b21e0a86832aa4abe55607bd96
if [[ ! -d "$sdk/.git" ]]; then
    git clone https://github.com/steinbergmedia/vst3sdk.git "$sdk"
    git -C "$sdk" checkout "$revision"
fi
[[ $(git -C "$sdk" rev-parse HEAD) == "$revision" ]] || { echo "Unexpected SDK revision at $sdk"; exit 1; }
git -C "$sdk" submodule update --init base cmake pluginterfaces public.sdk
swift build -c debug --product VHSPluginUI
bin_dir=$(swift build -c debug --show-bin-path)
cmake -S Plugin -B .build/vst3 -G Xcode -DVST3_SDK_ROOT="$sdk" -DVHS_SWIFT_LIB="$bin_dir/libVHSPluginUI.dylib" -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0
cmake --build .build/vst3 --config Debug --target VHSPrototype VHSPrototypeTests validator -- -quiet
plugin="$here/build/VHS Phase 3A.vst3"
mkdir -p "$here/build"
ditto "$here/.build/vst3/VST3/Debug/VHSPrototype.vst3" "$plugin"
mkdir -p "$plugin/Contents/Frameworks" "$plugin/Contents/Resources"
cp "$bin_dir/libVHSPluginUI.dylib" "$plugin/Contents/Frameworks/"
install_name_tool -id @rpath/libVHSPluginUI.dylib "$plugin/Contents/Frameworks/libVHSPluginUI.dylib"
install_name_tool -change "$bin_dir/libVHSPluginUI.dylib" @rpath/libVHSPluginUI.dylib "$plugin/Contents/MacOS/VHSPrototype"
install_name_tool -delete_rpath "$bin_dir" "$plugin/Contents/MacOS/VHSPrototype"
ditto "$bin_dir/VHS_VHSRenderer.bundle" "$plugin/Contents/Resources/VHS_VHSRenderer.bundle"
cp "$sdk/LICENSE.txt" "$plugin/Contents/Resources/VST3-SDK-LICENSE.txt"
codesign --force --sign - "$plugin/Contents/Frameworks/libVHSPluginUI.dylib"
codesign --force --sign - "$plugin"
echo "Built $plugin"
if [[ " $* " == *" --install "* ]]; then
    destination="$HOME/Library/Audio/Plug-Ins/VST3/VHS Phase 3A.vst3"
    mkdir -p "${destination:h}"
    ditto "$plugin" "$destination"
    echo "Installed $destination"
fi
