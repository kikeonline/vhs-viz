# VHS

A real-time visual performance instrument for macOS, built with Swift and Metal. Build procedural scenes in a control window and perform through a separate GPU-rendered output window for performance and projection.

## Current status

Phase 1 is implemented and functionally verified:

- Solid-color source with live RGB controls and preview.
- Separate resizable output window that preserves the scene when reopened.
- Immutable scene state with grouped undo and redo.
- Shared Metal renderer and clock, with deterministic GPU rendering tests.
- Native menu shortcuts, app icon, and light/dark layout verification.

Changes currently live in memory. Project persistence, additional sources/effects, and audio are planned. Accessibility and macOS 26 verification gaps are tracked in [the follow-up issue](https://github.com/kikeonline/vhs-viz/issues/10).

The implementation currently exists in the local development checkout; application sources and build scripts have not yet been published to this GitHub repository. The commands below apply to that checkout.

## Roadmap

| Phase | Scope | Status |
| --- | --- | --- |
| [1](https://github.com/kikeonline/vhs-viz/issues/2) | Runnable native core | Complete |
| [2](https://github.com/kikeonline/vhs-viz/issues/3) | Project creation, rename, open, and atomic save | Planned |
| [3](https://github.com/kikeonline/vhs-viz/issues/4) | Solid, gradient, noise, oscillator, and shape sources | Planned |
| [4](https://github.com/kikeonline/vhs-viz/issues/5) | Ordered transform, blur, pixelate, threshold, colorize, and RGB split effects | Planned |
| [5](https://github.com/kikeonline/vhs-viz/issues/6) | Microphone/interface capture and audio analysis | Planned |
| [6](https://github.com/kikeonline/vhs-viz/issues/7) | macOS system-audio capture | Planned |
| [7](https://github.com/kikeonline/vhs-viz/issues/8) | Persisted audio-to-visual mappings, curves, and smoothing | Planned |
| [8](https://github.com/kikeonline/vhs-viz/issues/9) | Projection readiness, performance, FPS/frame-time metrics, and accessibility | Planned |

See [the roadmap tracker](https://github.com/kikeonline/vhs-viz/issues/1) for dependencies and completion criteria.

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
