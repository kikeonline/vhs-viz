# Phase 1 verification

Verified on 2026-11-08, macOS 27.2, Apple M6 (Mac18,1), Xcode 27.2. The deployment target is macOS 26; running on macOS 26 itself has not been tested.

## Automated checks

- Release build: Swift 6, no compiler warnings or errors; signed app includes its Metal shader resource bundle and Icon Composer assets.
- `tools/test.sh`: 7 state test functions (including 5 parameter-validation cases) and 2 real GPU test functions pass. GPU tests check every pixel, sRGB encoding, fixed time/seed repeatability, opaque endpoints, and varying output sizes.
- `tools/selftest.sh`: native Edit menu starts with Undo/Redo disabled; committed edits enable Undo; real menu key-equivalent dispatch through Command-Z and Shift-Command-Z restores/reapplies the scene and updates enablement. Multi-update gestures create one history entry.
- Self-test also dispatches Show Output through Shift-Command-O and Show Control Window through Command-1; checks output resize/close/reopen, preserved state, edited-scene GPU readback, and a two-second live render/shared-clock smoke run.
- `tools/grid-lint.sh` passes. All four layout files pass with 18 probes across 7 areas each.

## Visual review

Actual active-window captures were reviewed with always-visible-scrollbar preference enabled. No clipping, overlap, unnecessary scrollbars, focus rings, or selected text appeared. The output content is entirely the scene, below the native title bar.

- [Control, light](verification/phase1/control-light.png): large violet preview beside aligned RGB labels, values, and native controls; system accent is visible.
- [Control, dark](verification/phase1/control-dark.png): semantic dark surfaces and readable primary/secondary text; scene color matches light mode.
- [Minimum, light](verification/phase1/control-minimum-light.png) and [minimum, dark](verification/phase1/control-minimum-dark.png): all controls remain visible and the preview retains its aspect ratio.
- [Output](verification/phase1/output.png): the solid fills the drawable without editor controls or overlays.
- [Icon contact sheet](verification/phase1/icon.png): Default, Dark, Tinted, Clear, and small renditions remain legible; source is custom filled SVG shapes, with no SF Symbols.

## Implementation decisions

The command layer uses AppKit menu items and explicit native validation. This replaced stale enablement observed with SwiftUI Commands during keyboard-dispatch testing. Shifted native key equivalents use uppercase characters. SwiftUI supplies the editing interface and open-window action; both render surfaces consume the same cached frame and shared GPU pipeline.

Snapshot launches inherit the terminal's capture permission, then activate the registered app through LaunchServices. This produces active captures without requiring VHS itself to capture other applications.

## Manual checks not performed

Computer Use still returned “Computer Use was not approved to use VHS” after Orca restarted. External Accessibility inspection and physical pointer/keyboard interaction were not performed; the menu and shortcut evidence above comes from the app's actual native menu objects and dispatched key equivalents. VoiceOver, Accessibility Inspector, increased contrast, and keyboard-only slider navigation have not been manually audited. No external-display/projector test or extended performance soak was performed; those belong to Phase 8.

Phase 1 is an in-memory instrument. Project persistence is Phase 2; procedural sources, effects, and audio are later phases. No later-phase functionality is implied by this verification.
