# Phase 1 verification

Verified on 2026-11-08, macOS 27.2, Apple M6 (Mac18,1), Xcode 27.2. The deployment target is macOS 26; running on macOS 26 itself has not been tested. The current fixed build is installed at ~/Applications/VHS.app.

## Automated checks

- Release build: Swift 6, no compiler warnings or errors; signed app includes the Metal shader bundle and Icon Composer assets.
- `tools/test.sh`: 7 state test functions (including 5 parameter-validation cases) and 2 real GPU test functions pass. GPU tests check every pixel, sRGB encoding, fixed time/seed repeatability, opaque endpoints, and varying output sizes.
- `tools/selftest.sh`: grouped history edits, published command availability, undo/redo, output lifecycle, shared clock, and GPU smoke checks pass.
- The shortcut regression refreshes menu content through its delegate, constructs key events from virtual key codes with the correct modifier flags, and sends them through `NSApplication.sendEvent`. It verifies Command-Z, Shift-Command-Z, Shift-Command-O, and Command-1. No system-wide keyboard events are posted by this self-test.
- `tools/grid-lint.sh` passes. All four layout files pass with 18 probes across 7 areas each.

## Visual review

Actual active-window captures were reviewed with always-visible-scrollbar preference enabled. No clipping, overlap, unnecessary scrollbars, unsolicited focus rings, or selected text appeared.

- [Control, light](verification/phase1/control-light.png): violet preview beside aligned RGB labels, values, and native controls; system accent visible.
- [Control, dark](verification/phase1/control-dark.png): readable semantic surfaces and text; matching scene color.
- [Minimum, light](verification/phase1/control-minimum-light.png) and [minimum, dark](verification/phase1/control-minimum-dark.png): all controls fit and preview keeps its aspect ratio.
- [Output](verification/phase1/output.png): solid fills the drawable below native window chrome with no editor overlays.
- [Icon contact sheet](verification/phase1/icon.png): Default, Dark, Tinted, Clear, and small renditions remain legible. Art uses custom SVG shapes and no SF Symbols.

## External Orca Computer Use

The `orca-computer-use` skill successfully inspected the installed app through Accessibility, changed real slider values, invoked toolbar/close buttons, and captured windows.

Observed before the shortcut fix:
- Red 0.24 → 0.80 and Green 0.08 → 0.40 updated both [preview](verification/phase1/orca/control-edited.png) and [output](verification/phase1/orca/output-edited.png).
- Show Output opened a separate window; closing it removed only that window. Restoring the initial values while output was closed and reopening it rendered the [current violet scene](verification/phase1/orca/output-reopened.png).
- Synthetic undo produced no change. An initial focus error obscured the cause, but the user then confirmed that a physical Command-Z also failed.

Observed after installing the fix, using Orca hotkeys with Accessibility readback and screenshot review:
- Set Red to 0.70. Command-Z changed it to [0.24](verification/phase1/orca/undo-fixed.png).
- Shift-Command-Z restored [0.70](verification/phase1/orca/redo-fixed.png).
- Shift-Command-O opened the output window.
- Command-Z sent to the output window restored Red to 0.24 in the control window.
- Command-1 sent to output returned focus to the control window.

The provider labels synthetic input as unverified delivery; the results above were verified separately from subsequent values, window inventory, and focus state. The app is left running at its original RGB values with output open.

## Shortcut regression and fix

Manually inserted AppKit menu items were not part of SwiftUI's command tree. A menu refresh removed them. The original self-test directly invoked `NSMenu.performKeyEquivalent`, so it passed while bypassing this failure.

The new regression failed on the original implementation after refreshing the menu, then passed after commands were declared through SwiftUI `Commands`. A small observed menu-state object publishes Undo/Redo availability into `App.body`; the command tree receives those values. The test now uses application event routing and accurate shifted key events.

Snapshot launches inherit the terminal's capture permission and activate the registered app through LaunchServices.

## Remaining manual checks and scope

The Orca provider does not expose menus/menubar inspection. External visual inspection of disabled Edit items, VoiceOver, Accessibility Inspector, increased contrast, and keyboard-only slider navigation remain unaudited. No projector test or extended performance soak was performed; those belong to Phase 8.

Project persistence is Phase 2. Other sources, effects, and audio remain in later phases.
