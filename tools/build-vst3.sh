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
swift build -c debug --product VHSHostUI
bin_dir=$(swift build -c debug --show-bin-path)
cmake -S Plugin -B .build/vst3 -G Xcode -DVST3_SDK_ROOT="$sdk" -DVHS_SWIFT_LIB="$bin_dir/libVHSHostUI.dylib" -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0
cmake --build .build/vst3 --config Debug --target VHS VHSProcessorTests validator -- -quiet
plugin="$here/build/VHS.vst3"
mkdir -p "$here/build"
# Rebuild a clean local bundle so obsolete dylibs/resources cannot survive packaging.
rm -rf "$plugin"
ditto "$here/.build/vst3/VST3/Debug/VHS.vst3" "$plugin"
mkdir -p "$plugin/Contents/Frameworks" "$plugin/Contents/Resources"
cp "$bin_dir/libVHSHostUI.dylib" "$plugin/Contents/Frameworks/"
install_name_tool -id @rpath/libVHSHostUI.dylib "$plugin/Contents/Frameworks/libVHSHostUI.dylib"
install_name_tool -change "$bin_dir/libVHSHostUI.dylib" @rpath/libVHSHostUI.dylib "$plugin/Contents/MacOS/VHS"
install_name_tool -delete_rpath "$bin_dir" "$plugin/Contents/MacOS/VHS"
ditto "$bin_dir/VHS_VHSRenderer.bundle" "$plugin/Contents/Resources/VHS_VHSRenderer.bundle"
ditto "$bin_dir/VHS_VHSSignal.bundle" "$plugin/Contents/Resources/VHS_VHSSignal.bundle"
cp "$sdk/LICENSE.txt" "$plugin/Contents/Resources/VST3-SDK-LICENSE.txt"
codesign --force --sign - "$plugin/Contents/Frameworks/libVHSHostUI.dylib"
codesign --force --sign - "$plugin"
echo "Built $plugin"
if [[ " $* " == *" --install "* ]]; then
    destination="$HOME/Library/Audio/Plug-Ins/VST3/VHS.vst3"
    mkdir -p "${destination:h}"
    ditto "$plugin" "$destination"
    echo "Installed $destination"
fi
