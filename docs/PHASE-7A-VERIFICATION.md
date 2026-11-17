# Phase 7A — Factory and user presets

Authorized on 2026-11-16 by “implemente next phase” referencing roadmap issue #1, whose next implementation is Phase 7A / #14. Implementation is complete with the automated/runtime evidence below; attended acceptance remains pending. Phase 4C is not closed and Phase 8 is not implemented by this work.

## Implemented

- Shared Signal browser in standalone and embedded VST3 editor: Factory/User scopes, search, explicit Load, Save Current Scene, Duplicate, Rename, confirmed Delete, and native import/export with replacement confirmation.
- Three immutable factory examples: Solid, peak-reactive Noise and a branching Gradient/Oscillator blend. No named input device is required.
- Portable `.vhspreset` envelope with validated project-schema migrations, graph/base values/seed/mappings/confirmed MIDI assignments/sync. Device/display/project/host identities, editor layout, live values and window state are excluded.
- Off-main-actor I/O and Metal preflight. Invalid, unsupported, oversized or uncompileable loads do not change the scene/history/frame. A document change during preparation cancels the load. Successful standalone load is one undoable replacement within the existing project, without saving it.
- Atomic creation/replacement, collision detection and safe failed writes. Read-only factory data is separate from user files. Saved project/host state embeds scene content independently of library paths.
- Existing VST3 parameter IDs remain unchanged; incompatible Solid controls and unresolved mapping targets remain unavailable rather than retargeted. Host state publication sends dirty/value-refresh notifications through the control-thread bridge and retains pending dirty notification until publication succeeds. The existing 128 KiB host-state capacity is checked before loading.

Behavior/format/ownership details: [PRESETS.md](PRESETS.md). The VST3 surface remains the existing feasibility adapter: production automation, RMS/bands/transient audio feeding, transport sync and actual song acceptance belong to Phase 8. Saving a sync enum does not establish transport-follow support.

## Fresh verification

Evidence directory: [verification/phase7a](verification/phase7a/). Fresh runtime: macOS 27.2.1 (26B7131), arm64. This is not macOS 26 runtime acceptance.

| Check | Result |
| --- | --- |
| `tools/test.sh` | **108 Swift Testing functions passed**: 44 core, 21 Metal renderer, 19 shared input, 15 device/system, 5 bridge and 4 Signal; no reported compiler warnings/errors |
| `./build.sh --debug` | Signed local `build/VHS.app` built successfully |
| Standalone `--preset-selftest` | Passed through `PRESET SELFTEST done`; inert selection/search, one undoable load, project identity, undo/redo, invalid-load preservation, shared user-list refresh/collision and library-independent project recall |
| Full standalone `--selftest`, exact-process foregrounding | Passed through **`SELFTEST done`**, including menu command availability, Command-Z/Shift-Command-Z, output Command-W/reopen/Command-1, source/effect/graph/input/mapping/preset and persistence regressions |
| `tools/test-vst3.sh` | Actual C++ processor/state fixtures passed; SDK validator **47 passed / 0 failed**; strict signature check and arm64 bundle check passed |
| `APP_LAYOUT_ONLY=1 tools/probe-vst3-ui.sh` | Embedded runtime harness passed: independent preset ownership, one host notification/scene edit, embedded state, local undo/redo and failed-load preservation; existing lifecycle/mapping checks and eight editor/graph appearance layouts passed |
| Preset native captures | **16 PNGs and 16 passing layout files**: factory, long user name, empty search and error, each in light/dark and both increased-contrast appearances |
| Signal/grid/plist/diff checks | `tools/check-signal.sh`, `tools/grid-lint.sh`, `plutil -lint Info.plist.in` and `git diff --check` passed |

New core fixtures exercise strict envelope types/version/size, legacy scene migration, malformed/unknown graph rejection, atomic commit failure, names/collisions, rename/delete, export/replacement, one history transaction and project recall after library deletion. They also verify confirmed CC/channel/sync portability and stable unavailable mapping targets. New Metal fixtures compile/render every factory example, check deterministic opaque output, inject an actual Metal compiler failure and prove prior frame/history preservation, then verify successful prepared load and undo.

Reviewed captures include factory light/dark, long-name User light and increased-contrast error. The browser's fixed native surface keeps its list scrollable and actions visible. These captures are of the shared browser fixture, not proof of every parent-window minimum/wide popover arrangement or host keyboard interaction.

## Harness and failed attempts

The first capture attempt produced a light PNG, then lost key-window ownership. A later launch restored a no-window session and was stopped after remaining idle; sampling showed an idle AppKit event loop. Verification launches now explicitly open the control window, including when macOS restores no windows. Normal product launch behavior is unchanged. Fixture launch uses `-ApplePersistenceIgnoreState YES` and exact-process foregrounding. A long-name fixture was corrected to avoid trailing whitespace rejected by the existing name rules; no product name validation was weakened. A measured divider gap was corrected to the Signal spacing grid before the final 16 captures/layout checks.

The first `tools/selftest.sh` rerun failed at output close with `active=false, key=none, outputKey=false, enabled=false`; see `selftest-focus-failure.log`. A subsequent run of the same signed app with exact-process System Events foregrounding passed the entire suite; see `selftest.log`. This records a focus-dependent harness/desktop limitation, not a new product Command-W acceptance claim. The earlier Phase 4C evidence is retained.

Reproduce the focused standalone run:

```sh
build/VHS.app/Contents/MacOS/VHS --selftest -ApplePersistenceIgnoreState YES > /tmp/vhs-selftest.log 2>&1 &
vhs_verification_pid=$!
sleep 0.5
osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $vhs_verification_pid) to true"
wait "$vhs_verification_pid"
```

For browser captures, run `APP_SNAPSHOT=/tmp/VHS-presets APP_SNAPSHOT_PAGES=presets tools/snap.sh -ApplePersistenceIgnoreState YES`, then the Swift layout checker on the generated JSON. `APP_LAYOUT_ONLY=1` explicitly omits PNG capture. Fixtures use ephemeral preset directories and do not write the user's library.

## Pending attended acceptance

- Actual standalone and Studio One browser interaction: keyboard-only selection/load/naming, native file/replace/delete panels, VoiceOver announcements and focus return. Minimum/wide parent-window popover arrangements need observation.
- Actual Studio One preset load/host dirty indication, compatible automation/chase behavior, song save/reopen after deleting a library file and multiple-instance/editor/output lifecycle. The harness and SDK validator are not Studio One acceptance.
- Existing Phase 4C physical audio/MIDI, live system capture, accessibility, native appearance/focus, host quit crash and minimum-OS checks remain as documented. No new hardware, permission, performance or macOS 26 acceptance is claimed.

Only local build bundles were rebuilt. Installed app/plug-in bundles and original songs were not replaced. The user subsequently authorized committing/pushing Phase 7A and updating the documentation/roadmap status. Phase 7A remains implemented with attended acceptance pending; its issue stays open. Pre-existing `.agents/`, `.claude/` and `skills-lock.json` remain untouched.
