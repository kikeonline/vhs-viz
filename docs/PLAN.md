# VHS implementation plan

Status: original plan approved on 2026-11-08; expanded on 2026-11-09. Phases 1–3 and the Phase 3A feasibility gate are complete. The user authorized Phase 3A implementation with “Implement next phase” after the planning-only revision. See PHASE-3A-VERIFICATION.md and decisions/0001-vst3-runtime.md for actual evidence and prototype limits. Phase 4 was authorized by “Implement next phase” on 2026-11-10 and is implemented and automatically verified; visual/keyboard checks are deferred at the user’s direction; see PHASE-4-VERIFICATION.md. Phase 4A was subsequently authorized and implemented; automated verification is recorded in PHASE-4A-VERIFICATION.md, with manual checks deferred by the user. The approved Signal design system was added on 2026-11-10. Phase 4B was authorized by “Implement next phase 4B” on 2026-11-10 and is implemented with automated verification; see PHASE-4B-VERIFICATION.md and S-047–S-051. Manual visual/keyboard/VoiceOver/Studio One acceptance remains deferred. On 2026-11-11 the user authorized the next work that does not require unlocking the Mac. Phase 5A is implemented and automatically verified (PHASE-5A-VERIFICATION.md); Phase 5B standalone device capture and Signal input UI were subsequently authorized and implemented; see PHASE-5B-VERIFICATION.md. Physical/permission/visual acceptance is deferred into Phase 4C. Phase 4C separately tracks unfinished desktop acceptance for a later attended session. Phase 6 was subsequently authorized on 2026-11-11 and is implemented with automated evidence (PHASE-6-VERIFICATION.md); live sharing/permission/playback acceptance remains in Phase 4C. Phases 7–9 remain unstarted.

## Product and compatibility target

Deliver `VHS.app` and `VHS.vst3` for macOS, initially native Apple Silicon. Primary host: Studio One 5.5.2 build 86528. No AU, Windows, VST2, AAX, other-host certification, or Intel/Rosetta delivery is required. VHS consumes audio and MIDI to generate visuals; it does not synthesize or process sound. Plug-in audio output passes input through unchanged.

Keep the macOS 26+ deployment target pending actual minimum-OS verification (#10). The inspected reference installation is MacBook Pro Mac18,1 / Apple M6 / 16 GB / macOS 27.2 (26B7124), with a universal Studio One 5.5.2 binary. Host architecture and end-to-end compatibility must be demonstrated, not inferred from installation. Failure on this combination reopens the deployment/adapter decision; upgrading the user's DAW is not an assumed requirement.

## Shared architecture

Retain Swift 6, SwiftUI/AppKit, Metal, immutable snapshots, stable parameter metadata, project migration, and deterministic GPU fixtures from Phases 1–3. The simple source/effect chain remains available. Phase 4A adds a typed shader graph with branching and image blending inside one scene; equivalent chain scenes migrate without visual changes. Every instance owns its scene, input state, clock, editor, and output lifecycle; preview/output within that instance share a frame.

Extract the reusable runtime from standalone AppModel ownership. VHSCore owns scene/value contracts, reducer/history, and clock policy; VHSRenderer owns Metal resources. A shared analysis/input boundary consumes standalone capture or host-fed samples/events. The standalone adapter owns physical audio, Core MIDI, ScreenCaptureKit, file commands, and app termination. The VST3 adapter owns host callbacks, buses, parameters, state serialization, and editor attachment. Do not reuse the app's global MenuState as shared plug-in instance state.

Start with a thin C++/Objective-C++ VST3 SDK adapter and a native Swift/Metal view. Phase 3A compares that route with a JUCE shell and records SDK/framework versions, licensing, build integration, and the selected boundary. No wholesale UI/renderer rewrite is planned. Do not assume the Swift package executable is already a loadable plug-in library.

Audio callbacks never call SwiftUI/AppKit, render, wait for the GPU, touch disk, allocate unbounded data, or block on locks. Use preallocated bounded buffers and a defined overflow policy to hand samples/events to analysis/control work; cross into Swift through a boundary whose real-time behavior is demonstrated. Retain event sample offsets and host timestamps, but visuals update at display rate: no sample-accurate video claim. Live GPU readback remains forbidden; synchronous readback is test-only.

Persist base scene values, mapping definitions, and clock/sync settings. Live audio analysis, held notes, MIDI controller values, host playback position, render time, and effective modulation values are transient and create no undo entries. Automation changes are host-managed base/control edits, not a stream of local scene-history entries. Define and test input precedence, mapping combination, note release, smoothing, and automation ownership in Phase 7 before exposing production controls.

Graph edits are immutable document changes. Graph validation and Metal compilation happen off audio/UI callbacks, and only successful executable graphs replace the last valid render at a frame boundary. Stable node/parameter IDs extend existing effect identities for MIDI and host automation. Presets package portable scene/graph/mapping/sync data; machine-specific input/display choices stay local.

## Phase and issue map

Existing issue numbers are preserved. The former Phase 8 readiness issue #9 becomes Phase 9 so production VST3 integration precedes release verification.

| Order | Phase | GitHub | Status / dependencies |
| --- | --- | --- | --- |
| 1 | Runnable native core | #2 | Complete |
| 2 | Reliable projects | #3 | Complete |
| 3 | All procedural sources | #4 | Complete |
| 3A | Studio One VST3 feasibility and shared runtime boundary | #11 | Complete; see Phase 3A verification |
| 4 | Ordered effects and scene editor | #5 | Implemented; active-window/keyboard verification pending |
| 4A | Node-based shader editor | #13 | Implemented; automated checks pass; manual checks deferred |
| 4B | Signal UI implementation for current features | — (local plan) | Implemented; automated and partial manual evidence recorded |
| 4C | Attended desktop verification and observed regressions | #10 / local plan | Deferred by user on 2026-11-11; see PHASE-4C-VERIFICATION.md |
| 5A | Shared audio analysis and MIDI engine | #6 | Implemented; headless fixtures and Thread Sanitizer pass |
| 5B | Standalone audio/MIDI adapters and Signal input UI | #6 | Implemented; automated checks pass; attended device/permission/UI acceptance in 4C |
| 6 | Standalone system audio capture | #7 | Implemented; automated checks pass; attended acceptance in 4C |
| 7 | Persisted audio/MIDI-to-visual mappings | #8 | Depends on #3, #5, #6, #13; system-audio acceptance also needs #7 |
| 7A | Factory and user presets | #14 | Depends on #8, #13 |
| 8 | Production VST3, automation, transport, and song recall | #12 | Depends on #11, #5, #6, #8, #13, #14 |
| 8A | External display and fullscreen output | #15 | Depends on #12; standalone work can follow #11 |
| 9 | Standalone/VST3 release and projection readiness | #9 | Depends on #7, #8, #12, #13, #14, #15, and outstanding #10 checks |

Phase 6 is standalone-only and does not block direct DAW audio/MIDI work. Follow the dependency graph when work can proceed independently. No implementation phase is silently approved by this table.

## Phases

- **Phase 1 — Runnable native core**
  - Establish Swift package targets for app, scene/state model, renderer, and tests; provide repeatable build and launch scripts.
  - Build a native control window with a solid-color control and live preview, plus a separate Metal output window that can be reopened and resized.
  - Introduce immutable scene snapshots, stable parameter identifiers, a reducer/action boundary, and undo/redo for committed parameter edits. Group continuous slider edits into one undo action.
  - Establish shared rendering time, an explicit test clock, color-space behavior, and frame resources without blocking the UI thread.
  - Add design tokens, the initial VHS icon, snapshot mode, and a minimal deterministic render fixture.
  - **Complete when:** VHS builds and launches; changing a solid color updates both views; undo/redo restores it; closing/reopening the output preserves the scene; a fixed-state GPU readback test passes; light/dark control-window snapshots have been reviewed.

- **Phase 2 — Reliable projects**
  - Implement New, Rename, Open, Save, and Save As with native menus, shortcuts, file panels, dirty-state indication, and save/discard/cancel handling.
  - Register `.vhsproject` as versioned JSON. Validate data, reject unsupported future versions, and define migrations for later schema changes.
  - Save to a temporary sibling file and atomically replace the destination. Keep the previous valid project intact on write or replacement failure.
  - Persist scene state and seed; reset undo appropriately on document replacement. Define rename behavior for the project title and existing file.
  - **Complete when:** a project survives app restart; rename and Save As behave consistently; corrupt or unsupported files leave the current document intact; simulated save failures preserve the last valid file and retain unsaved changes.

- **Phase 3 — All procedural sources**
  - Add solid, gradient, seeded noise, animated oscillator, and shape sources to a source registry.
  - Define typed parameter metadata and generate appropriate numeric, color, enum, and toggle controls.
  - Add source selection, sensible defaults, value validation, persistence, and undo behavior. Specify oscillator and shape variants in the phase's UX/story breakdown.
  - **Complete when:** every source can be selected, edited, saved, reopened, and undone; preview and output agree; fixed seed/time fixtures and bounded parameter cases pass.

- **Phase 3A — Studio One VST3 feasibility and shared runtime boundary**
  - Build a minimal native Apple Silicon VST3 and demonstrate scanning/instantiation in the installed Studio One 5.5.2; record edition, process architecture, OS/build, SDK/toolchain, and validation logs.
  - Demonstrate unchanged stereo audio pass-through plus host audio driving an existing source parameter. Route a Studio One instrument/MIDI track to VHS while VHS also receives track audio. Prove notes/velocity and at least one CC; test VST3 controller-to-parameter assignment rather than assuming raw CC bytes arrive.
  - Probe stereo insert plus event input first. If Studio One requires a different category or sidechain for simultaneous audio/MIDI, document the exact routing and validate it before choosing the production bus layout. Instrument classification must not accidentally promise sound generation.
  - Embed the current SwiftUI/AppKit/Metal editor, open a separate output, close/reopen the editor, and test continued output, two independent instances, and clean instance removal/host exit. Output closes on instance destruction; never terminate the DAW.
  - Probe the MIDI-learn workflow in Studio One, including how an unassigned CC is discovered or assigned through the host. Record any host limitation and a concrete learn workflow before promising the production UX.
  - Probe host tempo/playback delivery and a minimal state save/reopen. No dependency on a separately launched VHS app or IPC is assumed; revisit explicitly if hosting/window constraints demand it.
  - Record an architecture decision with adapter choice, resource loading/library packaging, ownership, real-time handoff, editor/output lifetime, and automation-ID strategy. Prototype evidence is not production completion.
  - **Complete when:** actual Studio One audio and MIDI change current visuals, pass-through is unchanged, editor/output lifecycle and two-instance isolation are demonstrated, minimal recall works, and the chosen implementation path has reproducible evidence. Unproven routing/lifecycle is a failed gate, not an assumed pass.

- **Phase 4 — Ordered effects and scene editor**
  - Implement transform, blur, pixelate, threshold, colorize, and RGB split as Metal passes with defined input/output behavior.
  - Support adding, selecting, removing, bypassing, and reordering effect instances, including repeated instances, with generated controls and keyboard-accessible ordering.
  - Give each effect instance a persisted stable identity so modulation and automation bindings survive reorder. Reuse intermediate textures and bound resource use during resize/chain edits.
  - Preserve undo, schema migration, deterministic rendering, and instance-safe engine ownership selected in Phase 3A.
  - **Complete when:** all six effects work alone/in combination; order changes rendering; chain edits and stable effect identities survive undo/file round trips; representative chains pass actual GPU fixtures.

- **Phase 4A — Node-based shader editor**
  - Add a node canvas with a searchable node library, typed input/output ports, connect/disconnect, selection, drag, pan/zoom, duplicate/delete, undo/redo, and keyboard/accessible alternatives to wire dragging.
  - Initial node library: existing procedural sources and effects plus constants, UV/time, scalar/vector math, color operations, and image blend/mix; exactly one final Output node. Multiple source branches may combine within one scene; independent scene crossfading remains separate.
  - Represent the graph as versioned immutable node/edge data with stable node/parameter IDs. Validate types, required inputs, missing nodes, cycles, and resource limits before committing an executable graph. Initial graphs are acyclic; feedback simulation is deferred.
  - Compile validated graphs into Metal shader functions/render passes off the UI and audio callbacks; debounce/cancel obsolete builds, bound nodes/passes/textures, and swap successful pipelines at a frame boundary. Compilation errors identify the offending node and keep the last valid render running in preview/output.
  - Expose eligible node parameters through the existing inspector, audio/MIDI mapping metadata, and stable host automation bindings. Rewire/reorder must not change IDs; deleting a node disables affected bindings visibly rather than retargeting them.
  - Keep the simple source/effect chain as a compatible editing mode for representable graphs. Explicitly migrate older projects to an equivalent graph and prove rendered output remains equivalent; arbitrary graphs cannot be silently flattened into a chain.
  - Persist graph topology, node values, seed and editor layout in versioned projects; embed the render graph and mappings in DAW state and presets. Validate imported graph data before compilation; graph selection/pan/zoom stays outside musical undo.
  - **Complete when:** A performer builds and reconnects a shader graph, sees live preview/output, recovers from invalid links or compilation failures without losing the last working render, and saves/reopens it. Existing source/effect scenes migrate with matching GPU fixtures. Graph parameters can be mapped and automated without unstable bindings.

- **Phase 4B — Signal UI implementation for current features (implemented; manual acceptance deferred)**
  - Implement the approved `design/KIT.md` and `design/tokens.json` in the native app, shared graph UI and existing VST3 feasibility editor. Use `design/vhs-design-system.html` as the visual reference, not a webview or replacement rendering engine. Scope is the features implemented through Phase 4A, including the prototype controls already present in the plug-in.
  - Establish a shared native token/component layer that both standalone and plug-in targets can import without depending on the app executable or a mutable global theme/runtime. Reuse `Space` and existing minimum-window metrics; add semantic adaptive surfaces, type, icons, control states, radii and motion. Follow system appearance/accent; Signal chartreuse is the approved brand option with correct foreground contrast. Provide dark/light and increased-contrast variants.
  - Build a native component gallery with forced rest/hover/pressed/selected/focused/disabled/inactive/error/bypassed states. Style real native controls and retain keyboard, VoiceOver labels/values and native menus/dialogs. Define any mapping from JSON design names to Swift roles in `design/DESIGN-SYSTEM.md`; avoid parallel token definitions that can drift.
  - Migrate the current toolbar/project dirty-state presentation, Chain/Nodes switching, five sources and generated numeric/color/choice/toggle/seed controls, six ordered effects and their inspectors. Use aligned exact-value fields, visible units, grouped continuous edits, discoverable reset, explicit bypass, keyboard reorder and accessible focus. Respect registry ranges/defaults/precision and immutable history; selection is not scene history.
  - Apply compact preview-plus-inspector layout with effects below preview at 1000×720 default and 880×500 minimum. Preserve source aspect ratio and reachable scrolling controls. Add the optional chain rail only at widths ≥1200pt when preview and inspector fit. Preserve existing graph minimum 1000×640, library/search, typed port shapes/labels/wires, selection/pan/zoom, accessible wiring alternatives, compile status and last-valid-scene recovery.
  - Apply the same design language to the current host-embedded editor while preserving its feasibility status, existing routing/discovery controls, instance isolation and host-owned window/menu behavior. Keep file/color panels, alerts, traffic lights and document shortcuts native. Keep the separate performance output content-only, with no styling overlay or scene-color-derived chrome.
  - Preserve project/host state, schema migrations, stable effect/node/parameter IDs, dirty state, grouped undo/redo, preview/output agreement, last-valid graph execution and nonblocking renderer/audio boundaries. No intentional scene/render algorithm, persistence schema, automation bank or input-routing changes belong to this UI phase.
  - Verify with the relevant app/shared-editor builds, core/Metal/bridge regression suites, app self-test, VST3 processor/validator/embedding checks for changed shared UI, grid lint and measured default/minimum layouts. Add meaningful checks for exact numeric commit/cancel/range/reset and undo boundaries; do not write tests that only restate styling constants. Exercise long names, scrolling, 16 effects and graph error states.
  - Prepare gallery/editor light/dark/increased-contrast snapshots and actual keyboard/menu/VoiceOver/Studio One observations when permitted. The existing automated-only direction remains in force until changed: use layout-only checks where needed, list manual/visual checks as deferred, and never treat layout data or HTML screenshots as native appearance evidence. Carry remaining #10 and prior-phase verification debt forward.
  - **Implementation complete when:** current standalone and shared plug-in features use the approved native Signal components/tokens; the gallery and current-feature layouts cover the component/state matrix; supported automated regression/layout checks pass; and `docs/PHASE-4B-VERIFICATION.md` records actual results and deferred checks separately. Visual/accessibility/host acceptance remains explicitly pending wherever observation is deferred. Future-feature controls are absent; later phases inherit the shared system automatically.

- **Phase 4C — Attended desktop verification**
  - Preserve historical evidence and complete only the outstanding desktop checks listed in PHASE-4C-VERIFICATION.md when the user has computer access.
  - Observed failures remain failures until reproduced and resolved or explicitly accepted; deferred checks are never counted as passes. This gate remains required before release, but does not block the authorized headless Phase 5A work.

- **Phase 5 — Shared audio analysis and standalone audio/MIDI inputs**
  - Split on 2026-11-11: **5A** is the shared engine, bounded callback queues, normalized MIDI and synthetic tests, with no UI or device access. **5B** implements device adapters, permissions, Signal input UI and attended hardware acceptance. Parent Phase 5 remains incomplete until both are accepted.
  - Implement reusable native Swift/Accelerate analysis for RMS, peak, low/mid/high bands, and transients, independent of device capture and host UI. Define windows, band boundaries, normalization, sample-rate adaptation, latency, and reset behavior.
  - Standalone: enumerate microphone/interface devices/channels by stable identity, handle permissions, disconnect/reconnect, unavailable devices, and sample-rate/channel changes; show input status/meters.
  - Standalone: enumerate Core MIDI hardware/virtual sources, select/reconnect sources, and normalize MIDI 1.0 note on/off, note number, velocity, and 7-bit CC with channel filters. Recognize velocity-zero note-on as note-off; reset held notes on disconnect/all-notes-off.
  - Feed the same bounded input/analysis boundary from host buffers/events; never open standalone devices from the plug-in. Test silence, tones, impulses, overload, buffer-size/sample-rate changes, event bursts, queue overflow, and recovery.
  - **Complete when:** actual standalone audio/MIDI sources drive meters/events, synthetic fixtures prove analysis and event semantics, inputs recover safely, and host-fed and device-fed fixtures agree within defined tolerances.

- **Phase 6 — Standalone system audio capture**
  - Retain System Audio (DAW, browser, apps) alongside physical inputs in the standalone Audio Input picker; it is an alternative to direct VST3 routing, not how the plug-in receives track audio.
  - Use SCContentSharingPicker/ScreenCaptureKit; verify the supported OS audio-sharing flow, release unused video immediately, and never save screen content.
  - Adapt samples to the shared analysis pipeline. Handle cancellation, denied/revoked permissions, stream termination/restart, switching sources, and resource release.
  - **Complete when:** standalone DAW/browser playback drives the shared meters/mappings; cancellation and capture termination leave rendering usable; no capture picker or screen/audio permission is required by VST3.

- **Phase 7 — Persisted audio/MIDI-to-visual mappings**
  - Map RMS, peak, bands, transients, MIDI note/gate/velocity, and CC to eligible numeric source/effect parameters through stable IDs, including graph node parameters. MIDI learn is required in standalone and VST3: select an eligible source/effect/node control, choose Learn, move a CC or play a note, inspect the detected channel/controller/note, then confirm or cancel. Include clear/relearn, explicit channel/Omni filtering, conflict replace/cancel, visible waiting/learned/no-input states, and manual assignment as a recovery path.
  - Prove the Studio One learn path in Phase 3A: VST3 controller assignments may require host-mediated learn rather than raw CC discovery. Document the actual workflow; do not silently substitute manual assignment for the requested learn feature. Persist assignments in projects/presets/song state, not live event values.
  - Provide output range, inversion, curve, smoothing, enable/disable, and live feedback. Define note priority/release and disconnect/all-notes-off behavior; no stuck modulation.
  - Specify deterministic precedence/combination of base values, host automation, MIDI, and audio, plus frame-rate-independent smoothing. Live input never overwrites persisted base values or floods undo. Mapping edits remain undoable.
  - Persist mappings and sync choices with explicit schema migrations. Handle removed/reordered effects, switched sources, missing devices, silence, and invalid/unknown targets safely.
  - Define a bounded, stable set of host automation IDs/bindings, including how dynamic effect instances map to them. Do not renumber host parameters when effect order changes. Phase 3A selects the strategy; Phase 8 implements the host surface.
  - **Complete when:** physical/system/host-fed audio and MIDI fixtures modulate the same scene; mapping edits survive file round trips; precedence, curves, ranges, smoothing, target lifecycle, note resets, and migration tests pass. Actual host UI/automation acceptance is completed in Phase 8.

- **Phase 7A — Factory and user presets**
  - Provide a preset browser with named factory examples, user presets, search, and explicit Load/Save Preset actions in standalone and VST3. Factory presets demonstrate the available node library and useful audio-reactive setups without requiring particular devices.
  - Presets carry a versioned graph/scene, base values, seed, mapping definitions and sync settings. Exclude live audio/MIDI/transport values, audio/MIDI device identities, external display identity, output visibility/fullscreen, and DAW-specific instance identity.
  - Loading validates/migrates the preset before an atomic scene replacement; preserve the current scene on malformed, oversized, unsupported or uncompileable presets. Define one undoable load in standalone and explicit host state/dirty notification in VST3; no modal save prompt or disk work in audio callbacks.
  - Save user presets atomically; support naming, duplicate/rename/delete, overwrite confirmation, and portable import/export with collision handling. Factory presets are read-only and can be copied to user presets.
  - Preserve host automation parameter IDs across loads; keep bindings stable where compatible and visibly disable unresolved graph targets rather than retargeting them. Persist MIDI learn assignments with deterministic channel/conflict behavior; device-specific selections remain local.
  - Embed the loaded preset content in .vhsproject and DAW state so later editing/deleting a library file does not change song recall. Never overwrite an external .vhsproject as a side effect of browsing or loading a preset.
  - **Complete when:** Factory and user presets can be found, loaded, saved and exchanged in both delivery modes, with safe errors and undo/host ownership. Presets restore graph and mapping definitions, and a saved song/project reopens identically without the preset library file.

- **Phase 8 — Production VST3, automation, transport, and song recall**
  - Package VHS.vst3 for native Apple Silicon/macOS using the Phase 3A adapter/bus layout. Receive host audio and MIDI together with unchanged mono/stereo pass-through where supported; verify in-place buffers, bypass, suspension, silence flags, sample formats, sample-rate and block-size changes.
  - Implement note events and CC through the SDK's supported controller/parameter path. Document Studio One routing for audio inserts, MIDI tracks, and live monitoring, including stopped-transport behavior and any demonstrated limitations.
  - Expose the stable automation surface with host begin/change/end edit gestures and tested host undo ownership. Restore IDs/bindings across scene edits, effect reorder, and plug-in updates; test automation record/playback with editor closed.
  - Add Free Run and Follow DAW clock modes. Read valid host timing fields, follow tempo/play/stop/seek/loop, and define fallback for absent context. Beat synchronization must be explicit; preserve existing seconds-based source behavior in Free Run. Stopped/follow mode holds musical time; missing context is visible and uses a documented fallback.
  - Save a self-contained versioned scene/graph/mappings/sync snapshot (including loaded preset content) into the DAW song; support validation, migration, state-before-editor and state-during-processing calls without disk access on the audio callback. Import/export .vhsproject explicitly; DAW session recall never depends on its path.
  - Replace standalone menu/termination assumptions with a host-owned editor. Each instance has independent state/output; editor closure does not end projection; instance removal/song close/host quit releases all resources. Do not auto-open projection windows during scanning/session restore.
  - Handle fast/offline DAW processing safely: audio pass-through remains correct; no attempt to render every audio block or produce exported video. Explain that DAW audio bounce does not export visuals.
  - **Complete when:** Studio One scans/loads VHS; audio and MIDI jointly drive visuals; automation and tempo/transport pass live checks; save/quit/reopen restores an independent scene per instance without external files; editor/output destruction and offline processing are safe; SDK validator and signal-integrity tests pass.

- **Phase 8A — External display and fullscreen output**
  - Add an Output destination picker listing connected displays by recognizable name and an explicit Show Output action. Each instance has one output destination; keep the editor on the working display and place a content-only borderless/fullscreen window on the chosen display.
  - Support a defined output aspect/resolution policy with Fit/Fill and letterbox/crop behavior, Retina/backing-scale changes, display rotation and refresh-rate differences. Preview and output share scene/time while rendering at their own sizes.
  - Provide Escape/Exit Full Screen and Show Control Window/Show Editor recovery without closing the document or DAW. Re-selecting a display moves the existing output instead of duplicating it; closing output leaves scene/playback intact.
  - Handle hot-plug, unplug, sleep/wake, and display reconfiguration. If the selected display disappears, hide its output safely and show a recoverable status in the editor; do not unexpectedly cover the remaining editor/DAW display. Reconnect requires explicit Show Output.
  - Remember preferred destination as local per-instance/session UI state with a safe unavailable-display fallback; never embed machine-specific display IDs in portable presets or treat window placement as musical scene history. Do not auto-open fullscreen during scanning/song restore.
  - Verify standalone and Studio One output with editor closed, two independent instances, shared-display contention (warn/require explicit choice), instance removal/song close/host exit, and no audio-thread or GPU-completion blocking.
  - **Complete when:** On actual external-display hardware, both standalone and VST3 can select a destination, project content-only fullscreen with correct aspect/scale, exit/reopen safely, recover from unplug/reconnect and sleep/wake, and keep DAW audio/rendering stable. Evidence records display model, connection, resolution/refresh, OS and host.

- **Phase 9 — Standalone/VST3 release and projection readiness**
  - Integrate and verify Phase 4A graphs, Phase 7A presets/MIDI-learn restoration, and Phase 8A external-display output in both delivery modes. Show FPS/frame-time definitions and CPU/GPU timings where supported, outside performance output.
  - Profile representative branching graphs, presets, and full effect chains on the reference M6 Mac: target sustained 60 FPS at 1080p; measure 4K separately. Record DAW audio dropouts, analysis-to-display latency, CPU/GPU, memory/resource growth, multiple-instance cost, and editor-closed output behavior.
  - Run extended standalone/Studio One audio+MIDI/render soaks, rapid input/device changes, host play/stop/loop/seek, song reload, instance add/remove, and persistence fault tests. Verify signal transparency/zero added audio latency and never claim sample-accurate video.
  - Complete keyboard, accessibility, errors/empty states, light/dark review, and actual macOS 26 runtime testing tracked in #10. Keep tested macOS 27.2/Studio One results separate from minimum-OS claims.
  - Build repeatable app and .vst3 artifacts, install the plug-in in the standard macOS VST3 location, validate scanning after install/update, and document uninstall/routing/troubleshooting. Define signing/notarization for distribution separately from local ad hoc development; package required native libraries and shaders.
  - **Complete when:** standalone create/edit/capture/MIDI/map/save/reopen/project and Studio One insert/route/automate/sync/save/reopen/project workflows pass with named hardware/OS/host versions, performance evidence, no unperformed checks marked passed, and documented remaining limits.

## Effort and sequencing

Earlier limited-scope estimate: 6–10 engineer-weeks for audio/MIDI + standalone/VST3 integration on one Mac/host, including a 3–5 working-day feasibility gate. This is not a commitment or the estimate for the entire remaining visual-effects backlog. The newly required node editor/compiler and preset library are additional scope; the earlier number must not be presented as the total for this expanded plan. Re-estimate after Phase 3A and a graph compiler/UI prototype; include dedicated external-display and MIDI-learn verification. It excludes Windows/AU/other DAWs/Intel certification, sound generation/processing, and video export. Re-estimate after Phase 3A using observed routing, native view hosting, and instance-lifecycle results. SDK/build integration and a potential lower deployment target are explicit estimate risks.

## Standing UI requirement — Signal

The user approved Signal on 2026-11-10 and requested automatic adoption from now on. Phase 4B migrates the current features first. Every later phase that adds or changes UI includes Signal implementation in its own scope; no separate styling authorization or cleanup phase is needed. Phases 4B, 5A and 5B are implemented; Phase 6 is implemented with automated evidence; Phase 7 is next and needs its own authorization. Parent Phase 5 acceptance and Phase 4C remain pending. Preserve phase/issue identities and the outstanding manual acceptance.

Before implementing UI, read `design/DESIGN-SYSTEM.md`, `design/KIT.md` and `design/tokens.json`; reuse the native semantic components introduced by 4B. Each UI-bearing phase must cover:

- Applicable component states, readable precision/units, system appearance/accent, light/dark and increased contrast, keyboard/accessible equivalents and reduced motion.
- Default/minimum/wide layout and scrolling for the affected standalone/shared/host surfaces; preview aspect and content-only output.
- Existing document/history, stable parameter identity, instance/lifecycle and renderer/audio constraints.
- Native gallery/snapshot/layout and interaction evidence appropriate to the change. Record observed passes separately from deferred manual/visual/host checks under the user's existing verification direction.

Do not add presets, mapping/learn, input, telemetry, transport or external-display controls solely because the reference kit contains future recipes. Introduce them when their functional milestone is implemented, using Signal then.

## Implementation workflow

Expand each authorized phase into checkable stories and UX notes before coding. Keep completed phase evidence intact. The 2026-11-09 expansion added backlog only. Phase 4 was subsequently authorized and implemented on 2026-11-10; its active-window visual/keyboard checks are deferred at the user’s direction. Use relevant Swift, native design, build/verification, test, layout, audio integration, and performance skills when implementation begins. Independent modules may use supervised workers only after phase authorization and agreed interfaces/ownership; no workers are needed for this planning change.

Record actual Edit-menu availability, Command-Z/Shift-Command-Z, Show Output, output close/reopen, and Command-1 from output after standalone command changes. For VST3 also verify that host commands/undo remain correct and editor closure never terminates the host. Hardware, permission, Studio One routing, external displays, and VoiceOver checks require observed evidence; snapshots/unit tests alone are insufficient.

## Technical references

- [VST3 SDK](https://github.com/steinbergmedia/vst3sdk) — adapter API, samples, build and validator; pin the chosen version in Phase 3A.
- [VST3 ProcessContext](https://steinbergmedia.github.io/vst3_doc/vstinterfaces/structSteinberg_1_1Vst_1_1ProcessContext.html) — host timing validity and transport.
- [VST3 IMidiMapping](https://steinbergmedia.github.io/vst3_doc/vstinterfaces/classSteinberg_1_1Vst_1_1IMidiMapping.html) — controller-to-parameter assignments; CC delivery must be tested in Studio One.
- [JUCE audio/MIDI plug-in tutorial](https://juce.com/tutorials/tutorial_create_projucer_basic_plugin/) — alternative adapter shell, not a commitment to rewrite native UI.
- [Apple Core MIDI](https://developer.apple.com/documentation/coremidi) — standalone MIDI endpoints/events.
- [Apple AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine) — standalone physical audio.
- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) and [SCContentSharingPicker](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker) — standalone system audio.
