# Phase 4B — Signal UI verification

Date: 2026-11-10. Authorized by “Implement next phase 4B”. S-047–S-051 are implemented under the existing automated-only direction. Native visual, physical keyboard/menu, VoiceOver and actual Studio One observations remain deferred. Phase 5 is next and has not been started or authorized by this work.

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

## Remaining acceptance

The gallery and current-feature snapshot fixtures are ready for native capture, but active-window light/dark/increased-contrast visual acceptance is pending. No claim is made that geometry checks prove readability, contrast perception, actual focus rings or complete text visibility. Actual Return/Escape/reset behavior through physical keyboard input, Full Keyboard Access order, hover/drag hit testing, external Edit menu availability before/after a slider edit, Command-Z/Shift-Command-Z, Show Output/close/reopen and Command-1 from output must still be observed. VoiceOver parameter/node/port announcements and navigation, Reduce Motion/Bold Text behavior in use, and Studio One's editor/menu/undo interaction require observation.

The native harness is not Studio One certification. No new actual host attach/detach/song-recall observations, hardware/controller checks, macOS 26 runtime acceptance, performance soak, external-display behavior or production VST3 certification are claimed. Earlier Phase 3A/4/4A evidence and GitHub #10 debt remain intact. Phase 5 and later feature controls remain absent; the existing prototype discovery controls retain their prior feasibility limits.
