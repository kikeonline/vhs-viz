# Phase 4B — Signal UI verification

Date: 2026-11-10. Authorized by “Implement next phase 4B”. S-047–S-051 are implemented under the existing automated-only direction. Native visual, keyboard/menu, VoiceOver and actual Studio One observations were deferred at implementation. The unlocked Mac follow-up below records the subsequent checks. Phase 5 is next and has not been started or authorized by this work.

## Implementation and UX

`VHSSignal` is a shared native SwiftUI/AppKit module used by standalone, VHSGraphUI and VHSPluginUI. The approved JSON is bundled unchanged; adaptive semantic colors resolve light/dark and both increased-contrast appearances. The same data supplies spacing, specified metrics, radius and typography sizes. Dynamic Mac accent overrides win over the Signal brand. Native menus, alerts, file/color panels and window ownership remain intact. Custom controls retain native Button/Slider/TextField/Toggle/Picker semantics; button/row/node styles provide explicit state treatment, with named reduced-motion behavior and Bold Text handling. See design/DESIGN-SYSTEM.md for the mapping and future usage.

Source/effect selection reveals a generated inspector. Numeric controls combine a tabular exact-value field and separate unit with a native slider stepped by metadata precision; signed ranges have a neutral tick. Return validates the entire finite number and range, whole-number seeds reject fractions, Escape cancels, and invalid drafts remain visible with feedback. Uncommitted text never enters scene history. Control-click Reset restores the registry default. Slider drags form one history entry; valid exact commits/reset use one scene action. Host exact edits retain begin/value/end brackets. Proposed Shift fine-adjust and double-click reset are not added; the discoverable context-menu reset is present.

The workspace retains native project title/dirty state and file commands, with a Chain/Nodes segmented selector that refuses incompatible chain editing. Compact layout keeps effects below the aspect-preserving preview, a 280pt inspector and 20pt margins. The optional wide chain rail was not needed; wide windows keep the same layout while the preview grows. Effect rows have explicit Bypassed text, struck order markers, independent bypass, visible keyboard-focusable reorder and undoable removal. Inspector summaries moved into help. Source/effect inspectors and chain lists scroll independently.

Graph cards/typed wires use semantic type colors, scalar circles/image squares/vector or color diamonds and explicit type labels. Native inspector wiring alternatives, library/search, selection, pan/zoom, layout persistence, compile diagnostics and last-valid-scene behavior remain. The existing feasibility editor shares the family and preserves its current RGB/routing/discovery controls; no production mappings or inputs were introduced. Its fixed host-owned size is now 1000×720 to accommodate the current controls. Signal resources are copied into the VST3 bundle and located relative to the loaded dylib, independently of the host's Bundle.main.

Performance output remains a separate content-only Metal surface. Core snapshots/reducer/schema, stable IDs, renderer algorithms, automation bank, processor input routing and audio callback code were not changed.

## Automated evidence

| Check | Result |
| --- | --- |
| Debug build/install | Pass, no Swift compiler warnings; signed app at build/VHS.app and installed at ~/Applications/VHS.app. |
| Swift Testing | 56 test functions pass: 30 core, 17 actual Metal GPU, 5 bridge and 4 Signal; parameterized cases additional. |
| Numeric behavior | Invalid/empty/nonfinite/trailing-garbage/out-of-range input preserves the draft and rejects commit; cancel clears its error and restores the current text. Exact commit, no-op, reset, dirty state, undo/redo and continuous gesture boundaries pass against ProjectSession. Locale decimal input, signed endpoints and UInt32 seed boundary pass. The UI uses this tested NumericDraft state; these tests do not simulate physical typing. |
| Native resource loading | Runtime typography/layout/color consumers load the bundled JSON. This caught and fixed an initial cast of presentation metadata as numeric type data. Packaged VST3 resource JSON matches the approved specification. |
| Actual core/Metal regressions | Existing source/effect/branching graph pixels, migrations, stable identity/history, asynchronous compile/stale-build handling and last-valid-frame fixtures pass. |
| App self-test | Existing project/source/effect/graph actions, internal command dispatch, grouped history, render/output agreement, output close/reopen and last-valid GPU recovery pass. External menu enablement and actual keyboard input remain separate deferred checks. |
| Shared native editor harness | Pass: two independent bridges/runtimes, graph host-state restore, output lifetime across editor detach, compilation and teardown; editor and graph layouts pass in all four appearances. |
| VST3 processor fixtures | Pass: float/double byte pass-through, MIDI/CC offsets, transport, instance isolation, transactional legacy/graph recall. |
| Steinberg validator/signature | 47 passed, 0 failed; native arm64 package and strict signature check pass. Expected install_name_tool signature-invalidation notices occur before the package is re-signed and verified. |
| Grid and shared styling | tools/grid-lint.sh, tools/check-signal.sh and git diff --check pass. JSON copy drift and raw feature-view font/color/radius/duration styling are checked. |
| Measured native layouts | 220 standalone/gallery layout files pass, plus 8 shared-editor files. Includes all five sources/six effects, default/minimum sizes, scrolled inspector bottoms, native document dialogs, graph minimum/library/errors, 16 effects and long project names at 1000×720 / 880×500 / 1440×900, and nine separate gallery states. Source/effect/graph/gallery/stress fixtures include light/dark and both increased-contrast appearances. These are geometry measurements, not native image review. |

Evidence is retained in docs/verification/phase4b/. The complete layout matrix was repeated after the last control changes. No PNG capture was requested or reviewed. Snapshot mode logs every skipped capture explicitly; layout data and the HTML sheet are not appearance evidence.

## Items deferred at implementation

The gallery and current-feature snapshot fixtures are ready for native capture, but active-window light/dark/increased-contrast visual acceptance is pending. No claim is made that geometry checks prove readability, contrast perception, actual focus rings or complete text visibility. Actual Return/Escape/reset behavior through physical keyboard input, Full Keyboard Access order, hover/drag hit testing, external Edit menu availability before/after a slider edit, Command-Z/Shift-Command-Z, Show Output/close/reopen and Command-1 from output must still be observed. VoiceOver parameter/node/port announcements and navigation, Reduce Motion/Bold Text behavior in use, and Studio One's editor/menu/undo interaction require observation.

The native harness is not Studio One certification. No new actual host attach/detach/song-recall observations, hardware/controller checks, macOS 26 runtime acceptance, performance soak, external-display behavior or production VST3 certification are claimed. Earlier Phase 3A/4/4A evidence and GitHub #10 debt remain intact. Phase 5 and later feature controls remain absent; the existing prototype discovery controls retain their prior feasibility limits.


## Unlocked Mac follow-up — 2026-11-10

The follow-up used macOS 27.2 and Studio One Professional 5.5.2 ARM64. The captures used a temporary copy of the snapshot runner with Orca window capture because the app's usual capture subprocess could not produce images. The production UI and source code were unchanged. The Studio One test used a copy of the Phase 3A song and a temporary installation of the signed Phase 4B probe. The previous installed probe was restored and verified against its backup.

| Check | Observed result |
| --- | --- |
| Native visual review | Captured 215 native images and measured 220 layouts. Reviewed representative light and dark captures of the workspace, source and effect controls, scrolled inspectors, graph canvas and error states, output, and gallery. At minimum size the effect list shows approximately one row at a time. Large graphs extend beyond the canvas viewport and can be panned. The long project title truncates ahead of the toolbar controls. Open and Save panel capture timed out in both appearances. |
| Increase Contrast | Enabled the real system setting. The dark graph canvas switched to the higher-contrast palette and remained readable. Setting a high-contrast appearance name in the snapshot runner alone produced the same sampled canvas pixels as normal appearance. The actual system toggle was restored. |
| Reduce Motion and Bold Text | Verified the graph remained usable with the real Reduce Motion setting enabled and restored the setting. Hover animation timing and Bold Text behavior were not established. |
| Exact numeric entry | Return committed Red 0.44, Escape canceled an uncommitted 0.89, and 1.2 produced invalid input feedback while Red stayed 0.44. Context menu Reset Red returned a separate test project from 0.55 to 0.24. |
| External keyboard and Edit menu | On a clean project both commands were disabled. After a keyboard slider edit Undo was enabled and Red advanced one 0.01 step. Command-Z and Shift-Command-Z restored the expected values. Tab navigation reached the numeric field and slider with macOS Keyboard Navigation enabled. A mouse drag from Red 0.24 to 0.83 was undone as one edit. The original Keyboard Navigation setting was restored. |
| Output | Shift-Command-O opened output. Its close button closed it and Show Output reopened it. Command-1 returned from the reopened output to the control window. Command-W did not close the output during the external shortcut check. |
| Interactive graph | Searched the node library for Number, added it, and dragged the node to canvas position (284, 220). Click-to-connect rejected a scalar on the image input and kept the preview. Click-to-connect wired Number to Red. A foreground mouse wire drag from Number to Green was confirmed in the inspector. A real pointer hover changed the Source button fill. |
| VoiceOver | Enabled VoiceOver and exercised its navigation and speech-copy shortcuts with the editor and graph active. No spoken phrase could be captured reliably. Parameter, node, and port announcements remain unverified. VoiceOver was turned off afterward. |
| Studio One | Opened both installed native editors. The preview rendered and the graph showed Ready. The host editor's Seed label wraps as “Se” and “ed.” With the seed field focused, the select-all attempt did not select its value. Typing 42 appended to 1, producing 142. The graph's Undo and Redo buttons stepped 142 → 14 → 142. The output stayed visible after the host editor closed, and reopening the editor retained the edit. After saving the disposable song and relaunching Studio One, the second insert recalled seed 142 and the first insert retained seed 1. No output window opened on recall. Full host menu shortcut and accessibility traversal coverage remains open. |

[Manual evidence](verification/phase4b/manual/) contains external keyboard results, observed values and representative native screenshots. The full local capture gallery is at `build/VHS-verification/phase4b/index.html`. VoiceOver speech-copy attempts followed [Apple's VoiceOver last-phrase guide](https://support.apple.com/en-euro/guide/voiceover/vo2725/mac).

The follow-up did not establish macOS 26 compatibility or production VST3 certification. Prior phase evidence remains historical.


## Unexpected-exit investigation — 2026-11-10 and 2026-11-11

The user reported Studio One unexpected-exit notifications after the manual checks. Four reports confirm quit-time crashes in processes 87471, 87970, 89272 and 90098. The editor and recall observations above remain valid. Host shutdown acceptance failed.

For processes 89272 and 90098, memory maps were captured before normal Quit. The first session was on Studio One's start page and had no VHS image in its captured map or crash image list. The second had the Phase 4B editor open. Both failed while AppKit drained the main dispatch queue during termination. The previously mapped program counter resolves to Studio One's own Contents/PlugIns/coreaudio.bundle/Contents/MacOS/coreaudio at offset 0x94f0 in both cases. This points to the host CoreAudio shutdown path on this macOS 27.2 machine. The closed-source module's underlying defect has not been determined.

A direct dynamic-library fixture created a VHS runtime, requested teardown from a worker thread, closed the dylib, and drained the main run loop for two seconds. That fixture completed successfully. This does not resolve the actual host failure.

The Mac rebooted on November 11. The newest Studio One report still dates from November 10 at 20:13. Studio One was closed during the follow-up. The reboot cleared the temporary raw memory maps, disposable song copy, direct fixture and older probe-bundle backup. The mapping excerpts had already been captured in the session output and are retained in the crash summaries. The original probe song in Documents remains present. The installed probe matches the signed Phase 4B build, UUID 7FC54F4D-2F8F-3ECE-9241-8D04BE796473. Restoring the older installed bundle is no longer possible from the cleared temporary backup.

The November 11 desktop check reported IOConsoleLocked = Yes. Remaining VoiceOver, Bold Text and host keyboard traversal checks require an unlocked desktop. The existing evidence does not mark them passed.

Crash summaries and the retained mapping excerpts are in docs/verification/phase4b/manual/crashes/. No VHS source changes resulted from this investigation.


### November 11 resume attempt

The desktop initially reported unlocked and VHS window reads succeeded. VoiceOver Utility still showed AppleScript control disabled. A later window read failed after IOConsoleLocked switched to Yes during setup. A temporary 15-minute caffeinate session was started to keep the display awake for another attempt. No new VoiceOver acceptance is claimed from this attempt.

A second November 11 resume reported IOConsoleLocked = No initially, followed by Yes within seconds before VoiceOver Quickstart became accessible. VoiceOver was verified enabled during setup, then turned off and verified disabled. Desktop locking continued after VoiceOver was disabled. The temporary keep-awake assertion did not establish a stable unlocked desktop.

### Deferred acceptance split — November 11

At the user's request, unfinished desktop acceptance and observed regressions are tracked separately in [Phase 4C](PHASE-4C-VERIFICATION.md) for a later attended session. Historical results above remain unchanged. Headless Phase 5A may proceed without claiming those checks passed.
