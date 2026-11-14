# VHS stories

Phases 1–3 approved and completed. Revised backlog covers standalone macOS + VST3 for Studio One 5.5.2, expanded on 2026-11-09 with a node-based shader editor, MIDI learn, presets, and external-display output. Unimplemented stories are `todo`; planning updates do not claim implementation. Phase 4B is implemented with automated checks (manual acceptance deferred), and every subsequent UI-bearing story automatically inherits the approved Signal system and standing UI acceptance checklist in PLAN.md. See PLAN.md for issue dependencies and compatibility scope.

## Phase 1 — Runnable native core

### S-001 Launch the control window
As a performer, I launch VHS and see a solid scene beside its color controls.
Screens: control-light.png, control-dark.png, control-minimum-light.png, control-minimum-dark.png
Acceptance:
- [self] Metal initializes and the live display loop runs without error.
- [snap] A native title bar, live preview, source description, and three labeled color sliders fit at default and minimum sizes.
- [snap] Light and dark modes use readable semantic system colors.
UX:
- Flow: launch VHS → Untitled Scene with Solid selected → adjust inline controls.
- Surface: one control window; no sidebar for the single source available in Phase 1.
- States: initialized scene appears immediately; Metal failure shows Unable to Render and the actionable error in the preview.
- Words: Live Preview, Source, Solid, Color, Red, Green, Blue.
- Access: native slider labels and values; natural keyboard focus order; no automatic text selection.
Status: done

### S-002 Change the solid color
As a performer, I move the color sliders and see the scene update immediately.
Screens: control-light.png, control-dark.png, output.png
Acceptance:
- [unit] Reducer changes the requested component without mutating the original snapshot or seed.
- [unit] Out-of-range and nonfinite component values are bounded safely.
- [self] Changed scene values reach the live frame and GPU readback.
UX:
- Flow: focus or drag Red, Green, or Blue → both views update → release commits the gesture.
- Surface: inline sliders with visible 0–1 numeric values, working in linear RGB.
- States: values have useful initial settings; boundaries are constrained by native controls.
- Words: component names remain the same in visible and accessibility labels.
- Access: keyboard-adjustable native sliders; meaning also conveyed by labels and numeric values.
Status: done

### S-003 Undo a color edit
As a performer, I undo or redo one committed edit, including a complete slider drag.
Screens: control-light.png
Acceptance:
- [unit] A multi-update drag produces one undo entry.
- [unit] Undo restores the initial value and redo restores the edited value.
- [unit] A new branch clears redo; no-op changes preserve history; undo during a drag commits then reverses it.
- [self] Published Undo/Redo availability and Command-Z/Shift-Command-Z dispatch follow current history, including after menu refresh.
UX:
- Flow: Edit > Undo Color Change or Command-Z → previous color; Shift-Command-Z → edited color.
- Surface: standard Edit menu; unavailable actions remain disabled.
- States: empty history disables Undo; branching disables Redo.
- Words: Undo Color Change, Redo Color Change.
- Access: keyboard shortcuts remain available from either window.
Status: done

### S-004 Open and reopen the performance output
As a performer, I show a separate output window and keep it live while editing.
Screens: output.png
Acceptance:
- [self] Show Output opens a resizable window with a live Metal surface.
- [self] Closing releases its surface and reopening preserves the current scene.
- [self] Resizing does not produce render errors.
- [snap] The output content contains only the scene.
UX:
- Flow: toolbar Show Output or Window > Show Output or Command-Shift-O → output; close → control remains; Show Output → same scene.
- Surface: separate native window because the content stays open beside the controls.
- States: existing output is brought forward rather than duplicated; closing stops its display loop.
- Words: Show Output, VHS Output, Show Control Window.
- Access: Show Control Window (Command-1) returns focus to the editor; native close, resize, and fullscreen affordances.
Status: done

### S-005 Render a deterministic frame
As a developer, I render a known scene at a fixed time and verify actual GPU pixels.
Screens: output.png
Acceptance:
- [unit] Fixed seed/time and scene produce repeatable GPU readback.
- [unit] All pixels match expected sRGB output within one code value, including non-square and resized textures.
- [unit] Black and white fixtures have exact opaque endpoints.
- [self] Live rendering runs alongside the shared-clock timer without GPU waits on the UI path.
UX:
- Surface: command-line test suite; no test or technical controls in the performance flow.
Status: done

### S-006 Build and inspect VHS repeatedly
As a developer, I build, launch, self-test, and snapshot VHS through documented commands.
Screens: control-light.png, control-dark.png, output.png, VHS-icon.png
Acceptance:
- [self] Release packaging includes the shader resource bundle and compiled icon.
- [snap] Icon reads in Default, Dark, Tinted, Clear, and small renditions.
- [self] Snapshot mode writes real-window PNGs and layout probe files then exits.
- [self] Grid lint and layout checks pass.
UX:
- Flow: build.sh → app bundle; tools/selftest.sh → checks; tools/snap.sh → snapshots.
- Surface: scripts outside the normal UI; errors exit nonzero.
Status: done

## Verification record

Phase 1 acceptance checks passed. See [PHASE-1-VERIFICATION.md](PHASE-1-VERIFICATION.md) for evidence and manual checks not performed. Phase 2 evidence is recorded in [PHASE-2-VERIFICATION.md](PHASE-2-VERIFICATION.md). Phase 3 evidence is in [PHASE-3-VERIFICATION.md](PHASE-3-VERIFICATION.md). Phase 3A feasibility evidence is in [PHASE-3A-VERIFICATION.md](PHASE-3A-VERIFICATION.md). Phase 4 is implemented and passes automated checks; active-window visual and external keyboard verification are deferred at the user’s direction in PHASE-4-VERIFICATION.md. Phase 4A is implemented and automatically verified (PHASE-4A-VERIFICATION.md); manual checks are deferred by user direction. Phase 5A is implemented with headless fixtures; Phase 5B and Phases 6–9 remain planned. Remaining attended checks are tracked in Phase 4C.

## Phase 2 — Reliable projects

Approved on 2026-11-08. One active project; output follows that project.

### S-007 Create a project without losing edits
As a performer, I choose New Project and start a fresh solid scene.
Screens: control-light.png, unsaved-light.png, unsaved-dark.png
Acceptance:
- [self] New resets identity, scene, file URL, and history after save/discard confirmation.
- [self] Cancel and cancelled/failed Save leave the current project intact.
UX:
- Flow: File > New Project / Command-N → Save / Don't Save / Cancel if edited → new Untitled project.
- Surface: native confirmation sheet only if there are edits to lose.
- States: pristine Untitled needs no prompt; error preserves current edits.
- Access: standard native alert buttons, Return saves, Escape cancels.
Status: done

### S-008 Save and Save As
As a performer, I save a project and continue editing it after reopening.
Screens: save-light.png, save-dark.png, saved-light.png, saved-dark.png
Acceptance:
- [unit] Versioned JSON round-trips identity, name, scene values, and seed.
- [unit] Temporary sibling write and atomic replacement preserve the previous valid file on injected write/commit failure.
- [self] Save establishes a baseline; edits during a save remain dirty; undo back to the baseline clears dirty state.
- [self] Save As switches the active URL only after success, retaining the original file.
UX:
- Flow: Command-S → native save panel for Untitled → saved title and clean state; Shift-Command-S chooses a new path.
- Surface: native save panel, restricted to .vhsproject.
- States: native edited indicator plus visible Edited text; cancellation is silent; failures offer an actionable error and retain unsaved changes.
- Access: panel keyboard navigation and standard buttons; Save/Save As in File menu.
Status: done

### S-009 Open a project safely
As a performer, I open a saved project without corrupting my current scene.
Screens: open-light.png, open-dark.png, open-error-light.png, open-error-dark.png
Acceptance:
- [unit] Reject malformed JSON, invalid values, oversized files, and unsupported schema versions.
- [self] Invalid files leave current state, history, URL, and saved baseline intact.
- [self] Valid files replace state and reset undo only after unsaved changes are resolved.
- [self] The same shared frame feeds preview and output after loading.
UX:
- Flow: File > Open Project / Command-O or Finder open → validate candidate → resolve edited current project → display loaded scene.
- Surface: native open panel or Finder document event; native error sheet on failure.
- States: unsupported future versions explain that a newer VHS is needed; cancellation preserves the current scene.
- Access: native file panel and .vhsproject document registration.
Status: done

### S-010 Rename a project
As a performer, I rename the project and, if saved, its file.
Screens: rename-light.png, rename-dark.png, rename-invalid-light.png, rename-invalid-dark.png
Acceptance:
- [unit] Empty, dot-only, too-long, and path-containing names are rejected.
- [unit] Renaming a saved file never overwrites a different existing file; failure leaves the original usable.
- [self] Unsaved rename changes the suggested save filename; saved rename changes the file and title while preserving unsaved scene changes.
- [self] Reopening an externally renamed file uses its filename as the visible title.
UX:
- Flow: File > Rename Project / Shift-Command-R → focused name field → Return renames; Escape cancels.
- Surface: short SwiftUI sheet with inline validation, Cancel, Rename.
- States: collision/I/O error stays in the sheet; existing filename is authoritative on open, with the JSON name updated on next save.
- Access: Project name label, initial name selected for replacement, keyboard submit/cancel.
Status: done

### S-011 Close or quit safely
As a performer, I close the editor or quit without silently losing edits.
Screens: unsaved-light.png, unsaved-dark.png
Acceptance:
- [self] Save, Don't Save, and Cancel gate editor close and application termination; failed/cancelled Save prevents departure.
- [self] Closing output never asks to save or changes document state.
- [self] Reopening the control window keeps the active project.
UX:
- Flow: native Close / Command-W or Quit / Command-Q → confirmation if dirty → close/quit only after resolution.
- Surface: native save-changes sheet; separate output remains an independent window.
- Access: standard close/quit shortcuts and confirmation choices.
Status: done

## Phase 3 — All procedural sources

Approved by the user after Phase 2. Effects and audio remain later phases.

### S-012 Select a procedural source
As a performer, I switch between Solid, Gradient, Noise, Oscillator, and Shape.
Screens: source-solid-light.png, source-gradient-light.png, source-noise-light.png, source-oscillator-light.png, source-shape-light.png (and dark variants)
Acceptance:
- [unit] Registry has stable source/parameter IDs, typed defaults, valid bounds/options, and no duplicates.
- [unit] Switching retains each source's settings, seed, and immutable original; switch and parameter edits undo/redo.
- [self] Source selection changes the shared frame and both live views continue drawing.
UX:
- Flow: Source picker → choose a source → controls and preview update immediately; Command-Z restores the previous source.
- Surface: native inline picker above a scrollable parameter inspector; preview/output stay visible.
- States: Solid is the default; selecting the current source is a no-op; switching ends a slider gesture and creates its own undo step.
- Words: Solid, Gradient, Noise, Oscillator, Shape; Undo Scene Change, Redo Scene Change.
- Access: labeled native picker; keyboard selection; inspector returns to its top on source change.
Status: done

### S-013 Edit generated parameters
As a performer, I edit numbers, colors, choices, and toggles using consistent controls.
Screens: source-*-light.png, source-*-dark.png, source-shape-minimum-light.png, source-shape-minimum-dark.png
Acceptance:
- [unit] Metadata drives type checking, bounds, defaults and persistence validation; bad runtime values cannot poison state.
- [self] Number gestures group into one undo step; color, choice, toggle, and seed changes undo/redo.
- [snap] Every source's generated controls fit or scroll at default/minimum sizes in light/dark.
UX:
- Flow: adjust native slider / color picker / menu / toggle / integer seed field → both renders update → undo restores the value.
- Surface: inline controls generated from registry metadata; native color panel for colors; exact UInt32 seed field on Noise.
- States: typed file values are rejected if invalid; UI numeric actions clamp to valid bounds; animation toggles freeze time at zero while retaining speed/phase.
- Words: source-specific names/units from metadata; colors are linear RGB content converted through the native color picker.
- Access: native labels and numeric values; no color-only status; keyboard traversal and scrolling.
Status: done

### S-014 Render spatial and animated sources
As a performer, I create gradients, seeded noise, animated waves, and geometric shapes.
Screens: source-gradient-*, source-noise-*, source-oscillator-*, source-shape-*, source-output-*.png
Acceptance:
- [unit] Actual Metal fixtures check analytic gradient samples, seeded repeatability, time/seed variation, waveform/shape variants, aspect handling, and parameter extremes.
- [self] Every source reaches preview/output through the same immutable frame without GPU completion waits.
UX:
- Variants: Gradient Linear/Radial and Reverse; Noise Smooth/Cells, contrast, scale, two colors, seed, optional animation; Oscillator Sine/Triangle/Square, cycles, speed, angle, phase, two colors, Animate; Shape Circle/Rectangle/Triangle, position, size, rotation, softness, outline and width, fill/background.
- Geometry: positions are normalized from top-left; shape size is relative to the shorter output dimension so circles remain round; softness and outline width use the same scale.
- Time: speed in cycles/second for Oscillator and cells/second for Noise; Animate off evaluates time zero. Time is runtime-only and does not create dirty/undo entries.
Status: done

### S-015 Save all sources and open older projects
As a performer, I save my selected source and its settings and reopen the same scene.
Screens: source-*-light.png
Acceptance:
- [unit] Every source round-trips with inactive settings and seed; schema 1 Solid projects migrate to schema 2 without changing color/seed/identity.
- [unit] Malformed/missing/unknown parameters, wrong types, invalid choices, and unsupported versions are rejected without silently fixing files.
- [self] Save/Open restores the source and settings, resets history, and leaves preview/output live; invalid Open preserves current state.
UX:
- Flow: Save → quit/reopen or Open → selected source and settings restored; schema 1 loads normally and next Save writes schema 2.
- Surface: existing native project commands and panels; migration requires no extra dialog.
Status: done

## Phase 3A — Studio One feasibility (#11)

Authorized by the user with “Implement next phase”; completed at feasibility scope on 2026-11-09. See PHASE-3A-VERIFICATION.md for host evidence, automated checks and exclusions. This does not complete production VST3 or Phase 7 MIDI learn.

### S-016 Load VHS in Studio One
As a performer, I insert VHS in Studio One and route track audio and MIDI to the visuals.
Screens: verification/phase3a/studio-one-audio-midi-cc1.png, verification/phase3a/plugin-editor-light.png, verification/phase3a/plugin-editor-dark.png
Depends: S-015
Acceptance:
- [manual] Studio One 5.5.2 scans/loads native arm64 VHS on the reference Mac; record edition, architecture, toolchain, and OS/build.
- [manual] Actual audio plus routed note/velocity and one CC drive existing source controls; exact bus/category/routing is documented.
- [unit] Known input samples pass through unchanged; no synchronous GPU work occurs in the process callback.
UX:
- Flow: insert VHS → route audio/MIDI → open editor → Show Output. Prototype uses Solid source RGB controls and a native Metal preview. Stereo insert + Visual MIDI event bus routing was observed. Learn Blue detects/reviews a host-mapped CC; Confirm/Cancel/Clear are inline. Learn assignments are prototype-session-only.
Status: done

### S-017 Keep projection running when the editor closes
As a performer, I close the plug-in editor and keep the projection running.
Screens: verification/phase3a/studio-one-instance1-output.png, verification/phase3a/two-instance-windows.txt
Depends: S-016
Acceptance:
- [manual] Native SwiftUI/Metal editor reopens while output continues; two instances have independent scenes and output windows.
- [manual] Removing an instance closes only its windows/resources; song close and host quit complete without a crash or terminating Studio One from plug-in code.
UX:
- Closing the editor hides controls; closing output stops only that surface. Removing the instance releases both. No plug-in action quits the host.
Status: done

### S-018 Choose a proven shared-engine boundary
As a performer, I can develop both products using a demonstrated adapter architecture.
Screens: decisions/0001-vst3-runtime.md (decision artifact; no additional UI)
Depends: S-016, S-017
Acceptance:
- [self] Reproducible prototype build includes native libraries/shaders and a minimal state round trip.
- [manual] Tempo/playback context and song save/reopen are observed in Studio One.
- [self] Architecture record selects SDK/JUCE shell, versions/license, real-time handoff, stable automation-ID approach, runtime ownership, and routing/lifecycle constraints; unresolved gate failures remain explicit.
Status: done

## Phase 4 — Ordered effects (#5)

Authorized by “Implement next phase” on 2026-11-10. Implementation and automated checks pass; active-window visual/keyboard verification is deferred at the user’s direction. See PHASE-4-VERIFICATION.md.

### S-019 Apply a visual effect
As a performer, I add and adjust one of the six visual effects.
Screens: effects-inspector-light.png, effects-inspector-dark.png
Depends: S-018
Acceptance:
- [unit] Transform, blur, pixelate, threshold, colorize, and RGB split pass actual Metal fixtures at fixed time/seed and parameter boundaries.
- [self] Generated controls update shared preview/output and participate in undo.
UX:
- Flow: Add Effect → choose a type → selected effect appears → adjust inspector; Command-Z reverses the edit.
- Surface: native ordered list below Live Preview and an inspector on the right; Source returns to source controls.
- States: empty “Add an effect to change the source”; a 16-effect limit disables Add Effect; renderer failures use the existing error surface.
- Access: native labeled sliders/color pickers and keyboard-focusable controls; selection is local UI state.
Status: implemented — automated checks complete; visual/keyboard verification deferred by the user

### S-020 Reorder and bypass effects
As a performer, I change the chain order and compare its output.
Screens: effects-chain-light.png, effects-chain-dark.png
Depends: S-019
Acceptance:
- [self] Repeated effects can be selected, bypassed, reordered, and removed; keyboard ordering and undo restore the chain.
- [unit] Stable effect instance IDs survive reorder and file round trips; order-sensitive GPU fixtures differ as expected.
UX:
- Flow: select an effect → toggle Bypass, Move Up, Move Down or Remove Effect → live result; Command-Z restores the chain.
- Surface: inline list controls and context menu; repeated effects have numbered positions.
- Access: Move Up/Down are native buttons usable with Tab/Space and accessible labels; boundary actions are disabled.
Status: implemented — automated checks complete; visual/keyboard verification deferred by the user

### S-021 Reopen an effect scene
As a performer, I save the complete effect chain and reopen it.
Screens: effects-restored.png
Depends: S-020
Acceptance:
- [unit] Explicit schema migration preserves older scenes; invalid effect records leave current state intact.
- [self] Save/reopen restores effects/settings/identities and resource use stays bounded during repeated resize/chain edits.
UX:
- Flow: Save Project → reopen → complete ordered chain and identities return; older projects open with an empty chain.
- States: malformed/oversized/unknown effect data is rejected before replacing the current project.
- Surface: existing native file dialogs and recoverable error alerts.
Status: implemented — automated checks complete; visual/keyboard verification deferred by the user

## Phase 4A — Node-based shader editor (#13)

Authorized by “Let’s go with next phase” on 2026-11-10. Implementation and automated verification complete; visual/keyboard and actual Studio One checks remain deferred by the user. See PHASE-4A-VERIFICATION.md.

### S-037 Build a shader graph
As a performer, I connect typed shader nodes to create a visual.
Screens: nodes-canvas-light.png, nodes-canvas-dark.png
Depends: S-018, S-021
Acceptance:
- [self] Search/add/connect/disconnect/duplicate/delete, selection, pan/zoom and graph undo/redo work with exactly one final Output node.
- [unit] Port types, required inputs, cycles, unknown nodes and node/pass/texture limits reject invalid executable graphs with actionable node-specific errors.
- [snap] Canvas, node library and inspector fit/scroll at minimum sizes in light/dark; keyboard and accessible wiring alternatives are exposed.
UX:
- Flow: Nodes → Add Node → search/select → connect matching ports by dragging or the inspector’s input picker → edit; Duplicate/Remove and Undo recover edits. Surface: canvas and searchable library popover beside a scrolling inspector. Empty graph always contains one Output. Pan/zoom/node placement are saved UI layout outside musical undo. Native node list and wiring pickers provide keyboard/accessible alternatives.
Status: implemented — automated checks pass; manual visual/keyboard/Studio One checks deferred by user

### S-038 Preview graph edits without interrupting output
As a performer, I see valid shader edits immediately and recover from compilation errors.
Screens: nodes-compile-error.png, nodes-live-output.png
Depends: S-037
Acceptance:
- [unit] Constants, UV/time, scalar/vector math, color, existing source/effect nodes and blend/mix render through actual Metal fixtures, including branching graphs.
- [self] Compile off UI/audio callbacks; stale jobs cannot replace newer results, and successful builds swap at frame boundaries.
- [self] Invalid links or shader compilation failure identify the node and leave the last valid preview/output running without GPU waits.
UX:
- Flow: edit → Compiling → current graph at the next frame, or node-specific error with last valid output retained. No modal compile errors. Error names the node and the port/limit; obsolete builds cannot replace current state.
Status: implemented — automated checks pass; manual visual/keyboard/Studio One checks deferred by user

### S-039 Open existing scenes as graphs
As a performer, I reopen an older source/effect scene without changing its look.
Screens: nodes-migrated-chain.png
Depends: S-038
Acceptance:
- [unit] Explicit project migrations create equivalent graph nodes/edges with stable identities; old/new actual GPU fixtures match within defined tolerance.
- [self] Simple chain editing remains available for representable graphs; a branching graph cannot be silently flattened and lose nodes.
UX:
- Flow: Open older project → equivalent source/effect graph → Chain or Nodes. Chain is available only when the complete graph is representable; a branching graph explains why Chain is unavailable and is never flattened.
Status: implemented — automated checks pass; manual visual/keyboard/Studio One checks deferred by user

### S-040 Save and map node parameters
As a performer, I save my graph and map its controls without losing connections.
Screens: nodes-parameter-inspector.png, nodes-restored.png
Depends: S-039
Acceptance:
- [unit] Topology, values, seed and editor layout round-trip; stable node/parameter IDs survive move/rewire/reopen and reject malformed data.
- [self] Eligible node parameters use shared mapping metadata; deleted targets are visibly disabled rather than retargeted, and pan/zoom does not enter musical undo.
- [manual] Graph preview/output and parameter edits work inside standalone and the VST3 editor; production mapping/automation is accepted in S-027/S-030.
UX:
- Flow: select node → inspect typed parameters and stable target keys → edit/save/reopen. Selection is transient; layout is persisted separately. Missing target resolution is explicit and never falls back to another node. Shared graph UI is embedded in the plug-in probe; production mapping/automation remains Phase 7/8.
Status: implemented — automated checks pass; manual visual/keyboard/Studio One checks deferred by user

## Phase 4B — Signal UI implementation for current features

Added on 2026-11-10 after user approval of Signal. Authorized by “Implement next phase 4B”; implemented before Phase 5. Covers existing features through 4A and the existing VST3 probe UI; no future input, preset, mapping or display-management features. Apply `design/KIT.md` and `design/tokens.json`. Automated-only verification direction persists; manual/visual/host observations stay deferred unless the user changes it. Actual evidence and deferred acceptance are recorded in PHASE-4B-VERIFICATION.md.

### S-047 Establish shared native Signal foundations
As a performer, I get a consistent readable instrument surface in standalone and the embedded editor.
Screens: signal-gallery-light.png, signal-gallery-dark.png, signal-gallery-high-contrast.png
Depends: S-040
Acceptance:
- [self] Standalone, VHSGraphUI and the existing plug-in editor consume a shared native token/component layer; no dependency on the app executable or shared mutable instance state.
- [snap] Gallery covers applicable rest/hover/pressed/selected/focused/disabled/inactive/error/bypassed states, semantic type, icons, color, radius and motion in both appearances and increased contrast.
- [self] System appearance/accent overrides and Reduce Motion/Bold Text/contrast settings are respected; native controls retain labels, values and focus semantics. Actual assistive-technology behavior requires observation, not inference from code.
UX: Readable neutral chrome, restrained Signal brand option, scene-independent color, native menus/dialogs and window interactions. This is native SwiftUI/AppKit, not the HTML sheet embedded in the app.
Status: implemented — automated checks pass; native visual/keyboard/VoiceOver/Studio One acceptance deferred by user

### S-048 Perform precise edits in the current source/effect inspector
As a performer, I edit existing visual controls precisely and understand the active effect chain.
Screens: signal-source-light.png, signal-effect-dark.png, signal-effect-bypassed.png
Depends: S-047, S-021
Acceptance:
- [self] Five sources and six ordered effects retain generated numeric/color/enum/toggle/seed controls and registry bounds/defaults/precision.
- [unit] Exact numeric commit/cancel/range/reset and continuous edits preserve dirty-state and grouped undo/redo contracts; no-op edits and selection do not add scene history.
- [self] Add/select/repeat/bypass/reorder/remove retain stable identities; bypass is explicit and editable; keyboard ordering remains available through commands.
- [snap] Labels, tabular values, units, focus and invalid-input feedback remain readable at minimum sizes, with long names and 16 effects.
UX: Select source/effect → generated inspector → drag or type exact value → commit or Escape cancel. Bypass skips processing without losing values. Native color panels preserve linear-light scene conversion.
Status: implemented — automated checks pass; native visual/keyboard/VoiceOver/Studio One acceptance deferred by user

### S-049 Apply Signal to the current scene workspace
As a performer, I keep a useful preview while reaching project and effect controls.
Screens: signal-editor-default-light.png, signal-editor-minimum-dark.png, signal-editor-wide.png
Depends: S-048
Acceptance:
- [self] Project name/Edited, native File commands/shortcuts, atomic save protections and Chain/Nodes mode availability retain existing semantics.
- [snap] 1000×720 default and 880×500 compact chain layouts retain 20pt margins, 280pt inspector, effects below preview, independent scrolling and source aspect ratio. Optional wide chain rail only appears at ≥1200pt when content fits.
- [self] Preview/output share the existing render state; close/reopen output preserves the scene. Output contains only rendered content, never theme/status overlays.
- [manual] Actual Edit menu enablement, Command-Z/Shift-Command-Z, Show Output/close/reopen and Command-1 work from the redesigned editor; log deferred observations separately.
UX: Stable perimeter controls, preview first, one selected inspector, no dormant future-feature navigation.
Status: implemented — automated checks pass; native visual/keyboard/VoiceOver/Studio One acceptance deferred by user

### S-050 Apply Signal to the current graph and host editor
As a performer, I read connections and recover from graph errors consistently in both existing editors.
Screens: signal-nodes-light.png, signal-nodes-dark.png, signal-nodes-error.png, signal-plugin-editor.png
Depends: S-047, S-049, S-040
Acceptance:
- [self] Existing graph library/search, node operations, typed connect/disconnect, selection, layout/pan/zoom, generated inspector, undo and accessible wiring alternatives retain behavior and stable IDs.
- [snap] Graph 1000×640 minimum fits/scrolls; node/wire type uses shape and labels as well as color; focus/selection/bypass/error remain distinct. Compile diagnostics stay in the editor and last-valid output continues.
- [self] Existing shared-editor harness retains independent instances and editor/output attachment lifetime; no host audio callback, parameter bank, persistence schema or render algorithm changes are introduced by styling.
- [manual] Actual Studio One editor interaction/keyboard/menu behavior and graph accessibility remain separately observed or deferred; prototype UI is not presented as completed production VST3.
UX: Familiar shared components in the host-owned window, no standalone menu/traffic-light imitation, and existing probe capabilities retain their prototype labeling.
Status: implemented — automated checks pass; native visual/keyboard/VoiceOver/Studio One acceptance deferred by user

### S-051 Verify Signal migration and make it the ongoing baseline
As a developer, I can implement the next feature using the same native system and trustworthy evidence.
Screens: signal-gallery-states.png, signal-minimum-inspector-bottom.png
Depends: S-048, S-049, S-050
Acceptance:
- [self] Relevant builds, core/Metal/bridge suites, app self-test, grid lint/measured layouts, and changed shared-editor/VST3 embedding/processor/validator checks pass; investigate failures instead of replacing existing fixtures with styling assertions.
- [snap] Native gallery and current-feature editor snapshots cover appearance/contrast/size/state matrix when permitted. Layout-only results and HTML references are never counted as native visual approval.
- [manual] Keyboard/VoiceOver/native visual/Studio One observations are performed when permitted or explicitly recorded as deferred under existing user direction, preserving prior #10/phase verification debt.
- [self] PHASE-4B-VERIFICATION.md records implementation scope, actual results, remaining acceptance and limits; DESIGN-SYSTEM.md maps specification roles to shared native tokens/components. Subsequent UI-bearing phases use them automatically.
UX: Future input/mapping/preset/sync/output controls are introduced only in their functional phase, using Signal then. No separate redesign request is required.
Status: implemented — automated checks pass; native visual/keyboard/VoiceOver/Studio One acceptance deferred by user

## Phase 4C — Attended desktop verification

Deferred by the user on 2026-11-11 until computer access is available. See PHASE-4C-VERIFICATION.md for the remaining matrix, observed failures and preserved evidence. This is a verification gate, not permission to implement unrelated features.

## Phase 5A — Shared input engine (#6)

Authorized on 2026-11-11 by the request to continue the next phase without unlocking the Mac. No device access, UI or host callback integration in this slice.

### S-052 Analyze audio through a bounded shared boundary
As an engine adapter, I supply mono/stereo samples without performing analysis on the callback.
Acceptance:
- [unit] Preallocated SPSC queues preserve samples and timestamps across planar/interleaved producers, reject bounded overload atomically, and recover on gaps.
- [unit] Silence, calibrated tones/bands, stereo phase inversion, impulses, nonfinite samples, rate/channel/block changes and reset follow INPUT-ENGINE.md.
- [unit] Independent instances and simultaneous producer/consumer use retain bounded storage and order.
Status: implemented — headless fixtures and Thread Sanitizer pass; see PHASE-5A-VERIFICATION.md

### S-053 Normalize MIDI and recover safely
As an engine adapter, I supply MIDI 1.0 bytes to a shared worker without UI or document edits.
Acceptance:
- [unit] Running status, packet splits, note on/off, velocity-zero release, channels, CC, system messages and malformed input follow INPUT-ENGINE.md.
- [unit] All-notes-off, reset, disconnect, filtering and queue overflow clear held notes; offsets/timestamps are retained.
- [unit] MIDI/audio engine state is transient and independently owned; no device APIs or document/history dependencies.
Status: implemented — headless fixtures and Thread Sanitizer pass; see PHASE-5A-VERIFICATION.md

## Phase 5B — Standalone analysis and audio/MIDI adapters (#6)

Authorized on 2026-11-11 by “Let go with next phase”. Implement the standalone adapters and Signal UI with automated checks; attended acceptance stays deferred at the user's direction. Shared-engine acceptance belongs to S-052/S-053; actual devices, permissions, status/meters and end-to-end routing remain below. Synthetic producer equivalence is not proof of a real device or host adapter.

### S-022 Choose an audio input
As a performer, I select my microphone or interface channels in the standalone app.
Screens: audio-input-light.png, audio-input-dark.png, audio-input-unavailable.png
Depends: S-018, S-051
Acceptance:
- [manual] Permission grant/deny, real interface selection, disconnection/reconnection, and sample-rate/channel changes recover without interrupting visual rendering.
- [self] Selection uses stable device IDs; unavailable inputs and silence have explicit meter/status states.
UX:
- Flow: toolbar Inputs → choose Audio input and Channels → Start Audio → request microphone access once → Listening/Silent/Waiting for samples, or inline recovery → Stop Audio. No automatic capture on launch.
- Surface: scrollable native popover, because these are related choices tied to a toolbar control. Popover dismissal keeps explicit capture running; Stop Audio ends it.
- States: Off, Requesting access, permission denied/restricted with Open Microphone Settings, unavailable selected UID retained, device/start error with Retry, format changes restart the selected source, zero input is Silent rather than missing data. Source identity and channel choice stay local; nothing enters scene history.
- Access: native pickers/buttons and labelled status; long names wrap or expose help; Escape dismisses. VoiceOver/keyboard/native appearance acceptance is deferred to Phase 4C.
Status: implemented — automated/native virtual-MIDI and layout fixtures pass; physical/permission/visual acceptance deferred to Phase 4C

### S-023 Read audio levels and bands
As a performer, I see level, frequency-band, and transient signals from my input.
Screens: audio-meters-light.png, audio-meters-dark.png
Depends: S-022
Acceptance:
- [unit] Silence, calibrated tones, impulses, level changes, and sample-rate/block-size changes validate documented RMS/peak/bands/transient analysis.
- [unit] Device-fed and host-fed fixtures agree within defined tolerances; bounded queue overload/reset behavior is tested.
- [self] Capture/processing callbacks perform no UI, disk, blocking lock, or GPU completion work.
UX:
- Flow: Start Audio → named RMS/Peak dBFS and Low/Mid/High/Transient normalized meters; Stop Audio clears live values.
- States: no-data dash while waiting/off/disconnected, measured zero labelled Silence, clipped/invalid/drop status in text as well as color. UI polls at 15Hz; no per-frame VoiceOver announcements.
- Surface: same Inputs popover, shared semantic Signal meters. No meters or input UI appear on performance output or in the VST3 probe.
Status: implemented — automated/native virtual-MIDI and layout fixtures pass; physical/permission/visual acceptance deferred to Phase 4C

### S-024 Choose a MIDI source
As a performer, I select a hardware or virtual MIDI source in the standalone app.
Screens: midi-input-light.png, midi-input-dark.png, midi-input-unavailable.png
Depends: S-018, S-051
Acceptance:
- [manual] Core MIDI hardware/virtual sources can be selected and hot-plugged; app recovers from source loss.
- [unit] Note on/off, note number, velocity, channel filters, and 7-bit CC normalize correctly; velocity-zero note-on releases the note.
- [unit] All-notes-off, disconnect, and queue overflow cannot leave a stuck held-note state.
UX:
- Flow: Inputs → choose MIDI source and Omni/channel → Start MIDI → last supported event and held notes → Stop MIDI. Source loss clears notes and shows Unavailable; reconnect retries only a previously explicitly started source.
- States: Off, Waiting for MIDI, receiving event details, unavailable/changed endpoint, reset on channel/source changes or packet loss. MIDI learn/mapping is not exposed yet.
- Access: native source/channel pickers, explicit Start/Stop, textual event/channel/value status. Endpoint identity is local, excluded from projects/presets; no new global shortcuts.
Status: implemented — automated/native virtual-MIDI and layout fixtures pass; physical/permission/visual acceptance deferred to Phase 4C

## Phase 6 — Standalone system audio (#7)

Authorized on 2026-11-11 by “Implement next phase”. Implement without presenting live sharing/permission UI during automated verification; attended acceptance remains in Phase 4C.

### S-025 React to system audio
As a performer, I select system audio as the standalone analysis source.
Screens: system-audio-picker.png, system-audio-denied.png
Depends: S-023
Acceptance:
- [manual] DAW/browser playback drives shared meters via the OS sharing picker; cancellation, permission denial/revocation, and stream termination leave the app usable.
- [self] Switching physical/system input releases the previous capture; unused video is discarded and no screen content is saved.
- [manual] VST3 host-fed audio works without invoking this picker or capture permissions.
UX:
- Flow: Inputs → Audio input: System Audio → Choose Audio to Share… → native app/display sharing picker → existing meters. Stop Audio ends the session. Changing to a physical source ends system capture before physical capture can begin; nothing auto-starts on launch.
- Surface: existing Signal Inputs popover, with the native sharing picker for source selection. No custom list of windows/screens, no preview or stored screen content.
- States: Off, Choose in sharing picker, Starting, Listening/Silent, Cancelled, permission denied/revoked, sharing ended and capture error. Cancellation leaves System Audio selected and off; choose again explicitly to retry. No automatic restart of a revoked or user-stopped share.
- Access: native picker/button names, status text and existing labelled no-data/silence meters; escape/cancel returns to Inputs. Device channels are replaced by a read-only stereo format for System Audio. Native keyboard/VoiceOver/appearance acceptance stays deferred.
Status: implemented — automated/native PCM/cancellation/layout checks pass; live sharing, permission and playback acceptance deferred to Phase 4C

## Phase 7 — Audio/MIDI mappings (#8)

All stories below are planned; implementation has not started.

### S-026 Map audio to a visual control
As a performer, I map an audio signal to a source or effect parameter.
Screens: audio-mapping-light.png, audio-mapping-dark.png
Depends: S-021, S-023, S-040
Acceptance:
- [unit] Range, inversion, curve, smoothing, enable/disable, and multiple-mapping composition obey documented bounds and frame-rate-independent rules.
- [self] Physical audio modulates visuals while base values/undo history remain unchanged; repeat with system audio after S-025.
Status: todo

### S-027 Learn a MIDI controller mapping
As a performer, I select a source/effect/node control and learn a CC or note assignment.
Screens: midi-learn-light.png, midi-learn-dark.png
Depends: S-024, S-026
Acceptance:
- [self] Learn waits for a CC/note, shows detected input/channel, and confirms one assignment; cancel, clear/relearn, channel/Omni filtering, no-input status and conflicting-assignment replace/cancel are covered.
- [unit] Note/gate/velocity bindings have explicit release/priority behavior; MIDI-learn definitions survive project/preset/song serialization and undo without saving live event values.
- [manual] Studio One learn workflow is demonstrated in Phase 3A and accepted in S-030; host-mediated assignment is documented if unassigned CC discovery is unavailable.
- [unit] Documented precedence of base/host automation, MIDI, and audio is deterministic; silence/disconnect/all-notes-off recover safely.
- [manual] A real standalone MIDI controller drives a mapped source/effect parameter without writing live event values into project data.
Status: todo

### S-028 Restore my performance mappings
As a performer, I reopen a project with audio/MIDI mappings intact.
Screens: mappings-restored.png, mapping-missing-target.png
Depends: S-027
Acceptance:
- [unit] Mapping definitions/sync settings round-trip with explicit schema migrations; missing/deleted/reordered targets are handled safely.
- [self] Mapping edits undo/redo; continuous analysis/MIDI values never dirty the document or enter undo.
- [self] Stable host automation bindings are specified without renumbering existing IDs on chain reorder.
Status: todo

## Phase 7A — Factory and user presets (#14)

Planned on 2026-11-09; implementation has not started.

### S-041 Find and load a preset
As a performer, I browse factory/user presets and load a look.
Screens: preset-browser-light.png, preset-browser-dark.png, preset-error.png
Depends: S-028, S-040
Acceptance:
- [self] Search and explicit Load choose factory/user presets in standalone and VST3; factory examples cover node graphs and audio-reactive scenes without requiring named devices.
- [unit] Version/type/size/graph validation and compile failure preserve the prior scene; load commits only after successful validation/compilation.
- [self] Loading is one standalone undoable scene replacement; VST3 notifies host state changes without conflicting with host undo or overwriting an external project.
Status: todo

### S-042 Save and organize user presets
As a performer, I save, name, duplicate, rename, delete and exchange my presets.
Screens: preset-save.png, preset-overwrite.png, preset-library.png
Depends: S-041
Acceptance:
- [unit] Atomic writes, failed save/import, malformed data and naming/collision cases preserve valid presets; factory examples remain read-only.
- [self] Save/duplicate/rename/delete and import/export work; overwrite/delete require explicit confirmation and factory presets can be copied to user presets.
Status: todo

### S-043 Recall presets independently of the library
As a performer, I reopen a project or song even after its preset file is gone.
Screens: preset-song-restored.png
Depends: S-042
Acceptance:
- [unit] Portable presets include graph/base values/seed/mappings/MIDI-learn/sync, excluding live values, device/display identity and window visibility.
- [unit] Stable host parameter IDs survive load; unresolved graph bindings are disabled visibly rather than mapped to another control.
- [self] Project/DAW serialization embeds preset content; rename/delete/change of the library file does not alter saved scene recall; actual Studio One reopen is checked in S-032.
Status: todo

## Phase 8 — Production VST3 (#12)

All stories below are planned; implementation has not started.

### S-029 Feed DAW audio and MIDI to VHS
As a performer, I use Studio One audio and MIDI together to drive the visual engine.
Screens: vst3-routing.png, vst3-input-status.png
Depends: S-018, S-028, S-043
Acceptance:
- [manual] Documented Studio One routing delivers notes/velocity/CC and audio together using the proven event/audio bus layout; test live monitoring and stopped transport.
- [unit] Supported mono/stereo/sample formats, in-place buffers, bypass, silence, suspension, sample-rate/block-size changes, and offline processing preserve unchanged audio output.
- [self] Plug-in never opens capture devices or requests standalone audio/system permissions; SDK validator passes.
Status: todo

### S-030 Automate visuals in Studio One
As a performer, I record and play visual automation in the DAW.
Screens: vst3-automation.png
Depends: S-029
Acceptance:
- [manual] Stable exposed controls record/play automation with correct begin/end gestures and host undo behavior, including with the editor closed.
- [manual] In Studio One, learn a CC/note for a source/effect/node parameter using the proven host workflow; cancel/clear/conflict handling and song recall pass without disrupting automation.
- [unit] Parameter IDs and effect bindings remain stable after reorder/reload; CC follows the supported VST3 controller-to-parameter path.
Status: todo

### S-031 Follow song playback and tempo
As a performer, I synchronize animated visuals with the Studio One timeline.
Screens: vst3-sync-light.png, vst3-sync-dark.png
Depends: S-029
Acceptance:
- [unit] Free Run preserves existing seconds-based motion; Follow DAW handles valid/missing context, tempo, stop, seek, and loop with a defined fallback.
- [manual] Studio One play/stop/tempo/loop/seek produce the specified visual timing; video is display-rate, not sample-accurate.
Status: todo

### S-032 Restore VHS with my song
As a performer, I reopen a Studio One song and recover each instance without external project files.
Screens: vst3-song-restored.png
Depends: S-030, S-031, S-043
Acceptance:
- [unit] Versioned host state validates/migrates scene/graph, loaded preset content, MIDI-learn definitions, mappings, sync and automation bindings, including state-before-editor/state-during-processing calls.
- [manual] Save, quit, and reopen a song containing two different instances; each restores independently with no external .vhsproject and no unsolicited output windows.
- [self] Explicit project import/export shares scene/mapping semantics with standalone while preserving host session ownership.
Status: todo

### S-033 Keep host and projection windows independent
As a performer, I edit and project without disrupting Studio One.
Screens: vst3-editor-closed-output.png, vst3-two-instances.png
Depends: S-032
Acceptance:
- [manual] Output continues while the editor is closed; reopening and removing instances, song close, and host quit release the correct resources.
- [manual] Host menus/shortcuts/undo remain correct; standalone app quit/file commands are not installed into the host menu tree.
- [self] No shared mutable app singleton leaks scene, MIDI, undo, clock, or output between instances.
Status: todo

## Phase 8A — External display and fullscreen output (#15)

Planned on 2026-11-09; implementation has not started.

### S-044 Choose an output display
As a performer, I select an external display while keeping controls on my working screen.
Screens: output-display-picker-light.png, output-display-picker-dark.png
Depends: S-018, S-033
Acceptance:
- [manual] Actual connected displays appear by recognizable name; explicit Show Output opens one content-only output on the selected screen in standalone and Studio One.
- [self] Changing destination moves the same instance window; session restore never auto-opens fullscreen and portable presets contain no display ID.
- [manual] Two instances remain independent; selecting an already-used display warns and requires an explicit choice.
Status: todo

### S-045 Project fullscreen with the right aspect
As a performer, I fill or fit visuals to the projector and exit fullscreen safely.
Screens: output-fullscreen-fit.png, output-fullscreen-fill.png
Depends: S-044
Acceptance:
- [manual] Fit letterboxes and Fill crops predictably across aspect, Retina/backing scale, rotation and refresh-rate changes; record hardware/configuration.
- [manual] Escape/Exit Full Screen and Show Control Window/Show Editor recover controls; editor-closed output, close/reopen and instance destruction preserve host audio/lifecycle.
- [unit] Aspect/viewport transforms agree with renderer fixtures while preview/output share scene/time at independent sizes.
Status: todo

### S-046 Recover when the projector disconnects
As a performer, I unplug/reconnect an output display without losing my set.
Screens: output-display-unavailable.png
Depends: S-045
Acceptance:
- [manual] Unplug, sleep/wake and display reconfiguration hide unavailable output and show a recoverable editor status; the remaining DAW/editor screen is not covered unexpectedly.
- [manual] Reconnect plus explicit Show Output restores the destination; no stuck fullscreen, duplicate windows, crash or audio interruption in either delivery mode.
- [self] Display preference is local UI/session state, not preset content or musical undo; missing destinations have a defined safe fallback.
Status: todo

## Phase 9 — Delivery and projection readiness (#9)

All stories below are planned; implementation has not started.

### S-034 Project reliably in both modes
As a performer, I perform fullscreen on an external display from standalone or VST3.
Screens: projection-fullscreen.png, projection-display-disconnected.png
Depends: S-025, S-028, S-033, S-046
Acceptance:
- [manual] Actual fullscreen/display disconnect, aspect, close/reopen, and editor-closed output workflows pass in both delivery modes.
- [manual] Keyboard/VoiceOver/light-dark checks and actual macOS 26 verification close remaining #10 gaps; unperformed checks stay unverified.
Status: todo

### S-035 Measure performance during a set
As a performer, I monitor performance without putting editor overlays in the output.
Screens: performance-light.png, performance-dark.png
Depends: S-034
Acceptance:
- [manual] Reference-Mac 1080p/60 FPS target and separate 4K measurements record CPU/GPU, audio dropouts, latency, memory, and multiple-instance cost.
- [self] Extended capture/MIDI/render and host lifecycle soaks record bounded resources and deterministic fixture results; zero added audio latency/signal transparency are verified.
Status: todo

### S-036 Install the app and plug-in
As a performer, I install VHS and load its VST3 in Studio One.
Screens: vst3-installed.png
Depends: S-035
Acceptance:
- [self] Repeatable native arm64 app/.vst3 builds include shaders/libraries; documented install/update/uninstall handles the standard macOS VST3 location.
- [manual] Fresh scan/update and complete standalone/Studio One save/reopen/projection workflows pass on named OS/host/hardware.
- [self] Signing/notarization/distribution policy and known limits are documented separately from ad hoc local builds; audio bounce is explicitly not video export.
Status: todo

## Later / excluded from this release

AU, Windows, VST2, AAX, Intel/Rosetta delivery, other DAW certification, sound generation/audio effects, video export/streaming, third-party plug-in hosting, MIDI 2.0/MPE/SysEx, program-change scene banks, and standalone MIDI-clock sync. Standalone system audio remains required.
