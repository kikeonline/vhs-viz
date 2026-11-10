# Phase 4A — Shader graph verification

Date: 2026-11-10. Authorized by “Let’s go with next phase” after Phase 4. The user’s direction “Continue with automated checks only” remains in force: active-window visual review, physical keyboard/VoiceOver and actual Studio One graph interaction are deferred and are not counted as passed. Phase 5 is next and is not implicitly authorized.

## Delivered scope

Typed immutable graph nodes/edges, 27 library entries plus final Output, searchable library, canvas cards/wires, drag or native-picker wiring, connect/disconnect, selection, duplicate/remove, bypass, pan/zoom, draggable and keyboard-editable positions, generated parameters, global seed and undo/redo. Source/effect chain editing remains available only for fully representable graphs; arbitrary graphs never flatten silently.

Graph version 1 and project schema 4 include stable UUID/key targets, strict validation and explicit schema 1/2/3 migration. Node positions/pan/zoom are stored separately from musical history; selection stays transient. Missing supplied target references remain visibly unavailable and never bind to another node. Actual audio/MIDI/host automation mappings remain Phase 7/8.

GraphCompiler validates, plans and compiles registry-owned Metal on an actor executor. Debounce/cancellation/generation checks discard obsolete jobs. The frame timer alone adopts a matching ready executable; bad links, incomplete graphs and compiler errors preserve the previous accepted frame/program. Compatible chains keep the original rendering path. Generated graph execution uses bounded liveness-planned textures, no input/output alias within a pass and no live GPU wait/readback.

The shared VHSGraphUI is embedded in standalone and the VST3 probe. Probe version 0.4.1 keeps existing parameter/class identities and legacy RGB host-state compatibility; a new bounded envelope embeds the complete graph/seed/layout document. Restore works before an editor exists, never opens output, and is guarded against stale UI publication overwriting host state. Host process() is unchanged. See SHADER-GRAPHS.md and ARCHITECTURE.md for contracts/limits.

## Automated evidence

| Check | Result |
| --- | --- |
| Debug app build/install | Pass; locally ad-hoc signed build installed at ~/Applications/VHS.app. |
| Swift Testing | 30 core, 17 actual Metal GPU and 5 bridge tests pass (52 tests; parameterized cases additional). |
| Core graph validation | Types, required ports, cycles, missing/duplicate IDs, unknown kinds, malformed values, one Output, node/pass/texture budgets, incomplete draft vs executable validation, UUID/key round trips, target deletion/replacement and layout outside history. |
| Migration | Explicit schema 3 → 4 graph creation retains effect UUIDs and repeated opens are deterministic. Prior schema 1/2 fixtures continue to pass. Custom source/output IDs survive edits in both editors. |
| Actual GPU | Branching image/color blends with analytic linear/sRGB expectations; scalar/vector constants/math, UV, time, sine, color compose/luminance/mix, image sampling, connected source controls; every procedural source and all six compiled effects agree with chain fixtures within two output bytes. Compiler-generated passes repeat at fixed seed/time. |
| Compiler/race handling | Compilation actor records off-main execution. Controlled obsolete jobs cannot replace newer results. Real invalid Metal yields node-specific diagnostics. Invalid drafts preserve the last accepted frame; app self-test also compares actual GPU pixels before/after failure. |
| Resource behavior | Typed graph scheduling rejects excess live textures/passes before compilation. Existing chain resize/reuse fixtures pass; graph budget is up to eight scratch textures in each of three slots. No full-process memory/performance certification is implied. |
| App self-test | Existing core/project/source/effect lifecycle passes, plus graph search/add/duplicate/remove, grouped values/undo, unavailable targets/restore, layout outside undo, nonflattening, asynchronous adoption/error recovery, save/open of branching topology/values/seed/layout and graph output. |
| Native embedding harness | Real shared editor/runtime builds, compiles a value/image graph, restores an independent document/layout without auto-opening output, isolates two instances, retains output after detach, and tears down correctly. Layout-only mode explicitly skips screenshots. These are harness checks, not Studio One observations. |
| Actual VST3 processor fixtures | Unchanged stereo float/double byte pass-through, MIDI/CC/transport/isolation and legacy recall continue to pass. Extended graph state round-trips before an editor; truncation and malformed JSON preserve previous state. |
| Bounded state mailbox | Bounds/revision/isolation plus stale UI publication rejected after a host restore. UI and host copies try once; no spinning or audio callback calls were introduced. |
| Steinberg validator | 47 passed, 0 failed; native arm64 bundle and signature verification pass. |
| Grid/layout | Source lint plus measured default/minimum light/dark graph workspace, inspector top/bottom, errors and library, and shared native editor layouts pass. Captures are explicitly skipped; these do not prove appearance or focus. |
| Working-tree whitespace | git diff --check passes. |

Evidence is retained in docs/verification/phase4a/. The VST3 test script now selects full Xcode for both the package build and fixture generator; an initial command-line-tools macro-plugin failure exposed that missing environment propagation and was corrected. A native layout-probe lifecycle failure on inspector selection was corrected by scrolling to the inspector top without replacing the ScrollView identity; the final measured layouts pass.

## Limits and deferred observations

No active light/dark image was reviewed in this phase, no physical keyboard or VoiceOver flow was observed, and no actual Studio One graph editing/save/reopen was repeated. Existing Phase 3A Studio One evidence stays historical. External menu enablement, Command-Z/Shift-Command-Z from the graph editor, Show Output/close/reopen/Command-1 from actual keyboard input, host menu/undo behavior, graph wire drag hit-testing and accessible announcements remain unverified. App/harness actions and internal shortcut checks are labeled separately.

The compatibility probe still has its original fixed RGB/discovery host parameter bank. The extended envelope is backward compatible; it is not the complete production automation/undo/bypass/suspension/transport contract. Numeric node targets and unresolved-reference metadata are ready for later mapping adapters, but no production MIDI/audio mappings or presets have been added. Hardware input, system capture, actual macOS 26, soaks/performance, external display and distribution/notarization remain their named later milestones.

The implementation was completed under the user-authorized automated-only verification scope. No new phase is authorized by this record.
