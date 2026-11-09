# Phase 2 verification

Reliable projects is functionally complete. Verified 2026-11-08 local / 2026-11-09 UTC on Apple M6 (Mac18,1), macOS 27.2, Xcode 27.2. Deployment target remains macOS 26. Release app installed at `~/Applications/VHS.app`.

## Implemented

New, Rename, Open, Save, Save As; native File commands and panels; versioned `.vhsproject` registration; immutable project/session state; saved baselines and edited indicators; actor-isolated disk I/O; temporary sibling write/synchronize/atomic replacement; collision-safe rename; save/discard/cancel for document replacement, editor close, and Quit. See [PROJECT-FORMAT.md](PROJECT-FORMAT.md) for the format and rename semantics.

## Automated checks

- Release build and signing: `./build.sh --install` passed with no compiler warnings.
- `tools/test.sh`: 15 core test functions (including parameterized validation cases) and 2 actual Metal GPU fixture functions passed. Covers versioned round trips, identity/seed/color, bad names/data/ranges/versions/size, injected pre-commit and actual write/replacement failures, temporary cleanup, collision/case-only rename, dirty baselines, undo, and edits during save.
- `tools/selftest.sh`: all checks passed through `SELFTEST done`. Exercises real SwiftUI command routing after menu refresh, undo/redo, output close/reopen, Command-1 from output, native editor close, actual ongoing preview/output drawable acquisition, project replacement/history resets, cancellation/failed save, Save As retention, corrupt/future rejection, and rename collisions. When Save overwrites the same file selected by Open, Open re-reads the committed file rather than loading a stale candidate. Scene editing is blocked during document transitions.
- `tools/snap.sh -AppleShowScrollBars Always`: 21 captures reviewed in light/dark: control default/minimum, saved/edited states, Rename normal/collision, native Open/Save, save-changes/error alerts, and output. No clipping or unreadable app controls found. Native alert tint follows system material over the scene.
- `tools/grid-lint.sh` passed. All eight layout captures passed: control 18 probes/7 areas; Rename 21 probes/8 areas.
- `git diff --check` passed.

## External native GUI checks

Used Orca Computer Use accessibility controls and real keyboard command delivery against the installed app; verified resulting window trees and file contents, rather than counting synthetic input delivery as a pass.

1. Set Red to 0.61. Command-S opened the native Save panel. Navigated to an owned temporary folder and saved `Native Set.vhsproject`. Title became Native Set; status Saved; JSON held Red 0.61, Green 0.08, Blue 0.62, seed 1.
2. Shift-Command-R opened Rename. Set Renamed Set and Return. File moved to `Renamed Set.vhsproject`; old path absent; title updated.
3. Shift-Command-S saved `Verification Copy.vhsproject`; original Renamed Set remained present; active title switched.
4. Set Red 0.33; Command-Q displayed save/discard/cancel. Cancel retained the live process, scene, and Edited state. Command-S wrote 0.33 and cleared dirty state. Clean Quit removed the process.
5. Opened the saved file through LaunchServices in a fresh process. This exposed a missing initial window: SwiftUI suppresses its default window for a document launch. Fixed delegate connection to occur before view appearance, with explicit Show Control on file events. Rebuilt/reinstalled; fresh process displayed Verification Copy, Saved, with Red 0.33.
6. Show Output and Command-1 from output worked with the loaded project. Set Red 0.44; Command-Q then native Save wrote 0.44 and terminated the process. A second cold file launch displayed the correct title, Saved state, and Red 0.44. Final pixel review exposed that the initial control preview acquired no drawables even though output worked. The app now drives both paused MTKViews explicitly from its existing shared frame timer; an added self-test requires their drawable counts to increase. File events wait for app launch completion. Cold-launch pixels now show the expected purple scene in the control preview. The persisted sample and [restart capture](verification/phase2/restart-native.png) are included.

## Limits and outstanding checks

GitHub #10 remains open. Actual external Edit-menu enabled/disabled appearance was not inspected: the current Orca provider cannot inspect the menubar. Command dispatch, published availability, Command-Z/Shift-Command-Z, Show Output, closing/reopening output, and Command-1 are covered by the passing app self-test; prior external undo/redo evidence remains in the Phase 1 report.

VoiceOver, keyboard-only slider traversal, Increase Contrast, and runtime/build verification on macOS 26 were not performed. The native panels were exercised with accessibility plus keyboard input; this does not constitute a full keyboard-only accessibility audit. Icon assets were unchanged and were not re-reviewed this phase.

Atomic save failure guarantees cover ordinary write/commit errors, with injected and actual filesystem failure tests. Power-loss durability, network/cloud filesystem behavior, and multi-process concurrent editing were not tested. Phase 3 sources, effects, and audio remain unimplemented.

All screenshots/layout files are in [verification/phase2](verification/phase2). Application sources and detailed evidence remain in the local checkout; GitHub issue completion is accompanied by this verification summary, not a claim that sources have been pushed.
