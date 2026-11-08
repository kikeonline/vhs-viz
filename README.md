# VHS

A native macOS visual performance instrument built with Swift and Metal.

Phase 1 provides a solid-color scene, live preview, a separate resizable output window, and grouped undo/redo. Project files, other sources/effects, and audio arrive in the later phases of [the roadmap](docs/PLAN.md).

## Requirements

- macOS 26 or later and a Metal-capable Mac.
- Full Xcode 26 or later, including Icon Composer. Scripts use `/Applications/Xcode.app` when installed without changing the system-wide developer directory.

## Build and run

```sh
./build.sh --debug --open
# Release build, install in ~/Applications, then open:
./build.sh --install --open
```

The local app is `build/VHS.app`. Set `SIGN_IDENTITY` to a development signing identity if desired; the default is ad hoc signing. No third-party packages or network access are required.

Move the Red, Green, and Blue sliders to change the solid source. These values are linear-light components from 0 to 1; Metal encodes the result to sRGB for both surfaces. One slider gesture is one undo step.

| Action | Shortcut |
| --- | --- |
| Undo Color Change | Command-Z |
| Redo Color Change | Shift-Command-Z |
| Show Output | Shift-Command-O |
| Show Control Window | Command-1 |

Close and reopen the output without losing the scene. Changes currently live in memory; saving is Phase 2.

## Verify

```sh
tools/test.sh
tools/selftest.sh
tools/snap.sh -AppleShowScrollBars Always
tools/grid-lint.sh
swift tools/check-layout.swift /tmp/VHS-shots/*-layout.json
tools/icon_review.sh
```

Self-tests and snapshots use ephemeral state. Snapshot mode writes actual window captures at default/minimum sizes in light/dark to `/tmp/VHS-shots`, plus layout measurements, and exits. It needs a live graphical session and Screen Recording access for the launching app. Override the output directory with `APP_SNAPSHOT`. Icon review writes `/tmp/VHS-icon.png`.

`VHSCore` contains immutable snapshots, reducer, bounded edit history, and explicit clock. `VHSRenderer` contains the shared Metal device, command queue, pipeline, and shader. The app owns a shared frame for preview/output and native window lifecycle. The live render path uses bounded in-flight submissions and never waits for GPU completion. Only test fixtures perform synchronous readback.
