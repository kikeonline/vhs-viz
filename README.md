# VHS

A real-time visual performance instrument for macOS, built with Swift and Metal. Build procedural scenes and perform through a separate GPU-rendered output window. Planned delivery: standalone `VHS.app` and a native Apple Silicon `VHS.vst3` for Studio One 5.5.2, with audio/MIDI-driven visuals, DAW automation, tempo/transport sync, and song recall.

## Current status

Phases 1–3 are implemented and functionally verified. Phase 3A now passes the Studio One VST3 feasibility gate (see below). Phase 4 effects are implemented and automatically verified; visual/keyboard checks are deferred at the user’s direction (see docs/PHASE-4-VERIFICATION.md). Phase 4A is also implemented and automatically verified; manual visual/keyboard/Studio One graph checks are deferred (docs/PHASE-4A-VERIFICATION.md). The standalone app provides:

- Solid, Gradient, seeded Noise, animated Oscillator, and Shape sources with live preview.
- A shared node editor with typed connections, branching/blending, value/math/color nodes, background compilation and last-valid-render recovery.
- Six ordered effects: Transform, Blur, Pixelate, Threshold, Colorize and RGB Split, with repeated instances, bypass, move up/down, removal and undo.
- Generated numeric sliders, color pickers, choices, toggles, and integer seed controls.
- Separate resizable output window that preserves the scene when reopened.
- Immutable scene state with grouped undo and redo.
- Shared Metal renderer and clock, with deterministic GPU rendering tests.
- Native menu shortcuts, app icon, and light/dark layout verification.
- New, Rename, Open, Save, and Save As with native file panels.
- Versioned `.vhsproject` JSON, atomic saves, dirty-state tracking, and save/discard/cancel protection.

Projects preserve scene values and seed across app restarts. MIDI learn, factory/user presets, selectable external-display fullscreen, audio/MIDI input and mappings, and production VST3 support remain planned; a native VST3 feasibility probe is implemented and tested. Schema 1/2 projects migrate to schema 4 with an empty effect chain and equivalent graph while preserving source settings, identity, color and seed. Accessibility and macOS 26 verification gaps are tracked in [the follow-up issue](https://github.com/kikeonline/vhs-viz/issues/10).

This repository contains the application sources, build scripts, design assets, and verification records. The commands below run from a local checkout.

## Roadmap

| Phase | Scope | Status |
| --- | --- | --- |
| [1](https://github.com/kikeonline/vhs-viz/issues/2) | Runnable native core | Complete |
| [2](https://github.com/kikeonline/vhs-viz/issues/3) | Project creation, rename, open, and atomic save | Complete |
| [3](https://github.com/kikeonline/vhs-viz/issues/4) | Solid, gradient, noise, oscillator, and shape sources | Complete |
| [3A](https://github.com/kikeonline/vhs-viz/issues/11) | Studio One VST3 feasibility: audio/MIDI routing, native editor/output, shared runtime | Feasibility gate passed |
| [4](https://github.com/kikeonline/vhs-viz/issues/5) | Ordered transform, blur, pixelate, threshold, colorize, and RGB split effects | Implemented; automated checks pass; manual checks deferred |
| [4A](https://github.com/kikeonline/vhs-viz/issues/13) | Node-based shader editor, typed connections, live Metal compilation | Implemented; automated checks pass; manual checks deferred |
| 4B | [Signal UI implementation for current features](docs/PHASE-4B-VERIFICATION.md) | Implemented; partial manual verification recorded |
| 4C | [Attended desktop verification](docs/PHASE-4C-VERIFICATION.md) | Deferred until computer access is available |
| 5A ([#6](https://github.com/kikeonline/vhs-viz/issues/6)) | [Shared audio-analysis and MIDI engine](docs/PHASE-5A-VERIFICATION.md) | Implemented; headless tests pass |
| 5B ([#6](https://github.com/kikeonline/vhs-viz/issues/6)) | [Standalone device adapters and Signal input UI](docs/PHASE-5B-VERIFICATION.md) | Implemented; physical/permission/visual acceptance deferred |
| [6](https://github.com/kikeonline/vhs-viz/issues/7) | [Standalone macOS system-audio capture](docs/PHASE-6-VERIFICATION.md) | Implemented; live sharing/permission/playback acceptance deferred |
| [7](https://github.com/kikeonline/vhs-viz/issues/8) | Persisted audio/MIDI mappings and MIDI learn for source/effect/node controls | Planned |
| [7A](https://github.com/kikeonline/vhs-viz/issues/14) | Factory/user presets, browser, save and portable import/export | Planned |
| [8](https://github.com/kikeonline/vhs-viz/issues/12) | Production VST3, automation, DAW transport, and self-contained song recall | Planned |
| [8A](https://github.com/kikeonline/vhs-viz/issues/15) | External-display selection, fullscreen, Fit/Fill and reconnect recovery | Planned |
| [9](https://github.com/kikeonline/vhs-viz/issues/9) | Standalone/VST3 release, projection, performance, and accessibility | Planned |

See [the roadmap tracker](https://github.com/kikeonline/vhs-viz/issues/1) for dependencies and completion criteria. Completed phase/issue identities are retained; the former Phase 8 readiness issue is now Phase 9. Phase 4 was subsequently authorized on 2026-11-10; its implementation and automated verification are complete; manual GUI checks are deferred by the user. Later phases remain planned. No AU, Windows, VST2, AAX, Intel/Rosetta delivery, sound generation, or video export is planned. Standalone physical/system audio capture remains in scope.

## Design direction

[VHS / Signal](design/KIT.md) is the approved design system. [Phase 4B](docs/PHASE-4B-VERIFICATION.md) implements shared native tokens/components for current source/effect/project/graph and existing plug-in editor UI. Every subsequent UI-bearing phase uses Signal automatically. See the [interactive reference](design/vhs-design-system.html), [tokens](design/tokens.json) and [design guidelines](design/DESIGN-SYSTEM.md). Automated checks pass; native visual/keyboard/VoiceOver/Studio One acceptance remains deferred. The reference sheet is separate from the native app.

## Requirements

- Current app: macOS 26 or later and a Metal-capable Mac. Planned release target: native Apple Silicon app + VST3.
- Primary plug-in host: Studio One 5.5.2 build 86528. Reference installation: Apple M6 / 16 GB / macOS 27.2 (26B7124). Phase 3A verified the native ARM64 host/prototype combination; actual macOS 26 runtime verification remains open in #10.
- Full Xcode 26 or later, including Icon Composer. Scripts use `/Applications/Xcode.app` when installed without changing the system-wide developer directory.

## Build and run

```sh
./build.sh --debug --open
# Release build, install in ~/Applications, then open:
./build.sh --install --open
```

The local app is `build/VHS.app`. Set `SIGN_IDENTITY` to a development signing identity if desired; the default is ad hoc signing. The current Phase 1–4 build requires no third-party packages or network access. The commands here build the standalone app; the separate Phase 3A probe commands are below.

Choose a Source above the inspector, then edit its generated controls. Source changes retain inactive settings and support undo. Gradient has Linear/Radial styles; Noise has Smooth/Cells; Oscillator has Sine/Triangle/Square; Shape has Circle/Rectangle/Triangle.

Solid keeps its Red, Green, and Blue sliders. These values are linear-light components from 0 to 1; Metal encodes the result to sRGB for both surfaces. One slider gesture is one undo step. Native color pickers convert to linear RGB; choices, toggles and committed seed edits are undoable. See local `docs/SOURCES.md` for coordinate and animation behavior.

| Action | Shortcut |
| --- | --- |
| New Project | Command-N |
| Open Project | Command-O |
| Save Project | Command-S |
| Save Project As | Shift-Command-S |
| Rename Project | Shift-Command-R |
| Undo Scene Change | Command-Z |
| Redo Scene Change | Shift-Command-Z |
| Show Output | Shift-Command-O |
| Show Control Window | Command-1 |

Close and reopen the output without losing the scene. Save projects as `.vhsproject` files. Rename moves an existing file in its folder and refuses collisions; Save As keeps the original and switches to the new file. Opening a project resets undo history. Malformed or unsupported project files leave the active project intact.

Saves write and synchronize a temporary sibling before atomically replacing the target. A failed write or replacement retains the previous valid file and unsaved edits. The filename supplies the visible project title on open.

## Verify

```sh
tools/test.sh
tools/selftest.sh
tools/snap.sh -AppleShowScrollBars Always
tools/grid-lint.sh
swift tools/check-layout.swift /tmp/VHS-shots/*-layout.json
tools/icon_review.sh
```

Self-tests and snapshots use ephemeral state. Snapshot mode writes actual window captures at default/minimum sizes in light/dark to `/tmp/VHS-shots`, plus all sources at default/minimum sizes, scrolled controls, output fixtures, native color/file panels, project states, and layout measurements, then exits. It needs an unlocked graphical session, Screen Recording access for the launching app, and System Events Accessibility access to activate the exact snapshot process. Override the output directory with `APP_SNAPSHOT`. Icon review writes `/tmp/VHS-icon.png`.

`VHSCore` contains immutable snapshots, reducer, bounded edit history, and explicit clock. `VHSRenderer` contains the shared Metal device, command queue, pipeline, and shader. The app owns a shared frame for preview/output and native window lifecycle. The live render path uses bounded in-flight submissions and never waits for GPU completion. Only test fixtures perform synchronous readback.


### Phase 3A VST3 feasibility probe

`tools/build-vst3.sh --install` builds an ad-hoc signed arm64 **VHS Phase 3A.vst3** for the user VST3 folder. Requires full Xcode, CMake and git/network on first SDK fetch. `tools/test-vst3.sh` runs actual processor fixtures and Steinberg's validator; `tools/probe-vst3-ui.sh` checks native embedding/output lifetimes and captures light/dark views. `python3 tools/vst3-fixtures.py` creates deterministic audio/MIDI routing fixtures in `/tmp`.

Studio One Professional 5.5.2 ARM64 scanned and loaded the probe; stereo audio and routed notes/velocity/CC drove the existing Solid renderer together. Two-instance state/output isolation and song recall/removal were observed. This is a feasibility prototype, with runtime-only CC learn and minimal RGB recall. Production mappings/automation remain later phases. See [verification and exact routing](docs/PHASE-3A-VERIFICATION.md) and [architecture decision](docs/decisions/0001-vst3-runtime.md).

### Ordered effects (Phase 4)

Choose Add Effect below Live Preview, then select a chain row to edit its controls. Bypass skips the operation while retaining settings. Move Up/Down changes order; Remove Effect is in the inspector/context menu. Source returns to source controls. Chains support 16 independent instances and persist their UUIDs/settings in schema 3. See [effect contracts](docs/EFFECTS.md).

`APP_SNAPSHOT_PAGES=effects tools/snap.sh` captures only effect inspectors/chains. `APP_LAYOUT_ONLY=1` skips image capture explicitly and produces layout measurements only; it does not prove visual appearance. Snapshot capture now rejects inactive/non-key windows.

### Shader graph editor (Phase 4A)

Choose Nodes in the toolbar. Add Node searches the library; connect by dragging, clicking output/input ports, or the inspector’s typed pickers. Duplicate/remove, numeric/color controls, global Seed, canvas positions and pan/zoom are supported. Graph edits are undoable; layout is saved outside musical undo. Chain remains available only for equivalent graphs and never flattens branches. Schemas 1–3 migrate to graph-aware schema 4. See [graph contracts](docs/SHADER-GRAPHS.md) and [automated verification](docs/PHASE-4A-VERIFICATION.md).

The 0.4.1 compatibility probe embeds the same editor and recalls complete graph documents in an extended host-state envelope, while retaining legacy RGB recall. Actual Studio One graph interaction and active visual/keyboard checks remain deferred by the user; production mappings/automation remain later phases.

`APP_LAYOUT_ONLY=1 APP_SNAPSHOT_PAGES=nodes tools/snap.sh` measures graph layouts without image capture. `APP_LAYOUT_ONLY=1 tools/probe-vst3-ui.sh` runs native embedding/state/lifecycle and layout checks without requiring screenshots. Neither is visual/keyboard certification.

Standalone Inputs now selects physical audio channels and MIDI sources, with explicit Start/Stop and live analysis/event status. Choices are local; capture starts only on request. See [input behavior](docs/INPUTS.md) and [Phase 5B evidence](docs/PHASE-5B-VERIFICATION.md). Physical devices/permissions and native visual/accessibility acceptance remain pending in Phase 4C.

System Audio is available in standalone Inputs through the native macOS sharing picker. Only audio feeds the existing meters; no recordings are saved. [System-audio behavior](docs/SYSTEM-AUDIO.md) describes source switching and the remaining attended checks.
