# VHS implementation plan

Status: approved on 2026-11-08. Phases 1–3 complete; subsequent phases require the user's direction.

## Planning basis

The checkout contains skills and no app source. Treat the supplied feature list as the target specification. Proposed baseline: macOS 26+, Swift 6, SwiftUI/AppKit, Metal/MetalKit, Core Audio/AVAudioEngine, ScreenCaptureKit, and Accelerate. Keep the repository at its current path.

The editor is a fixed chain: one selected source followed by zero or more ordered effects. The preview and output share the same scene snapshot, clock, and renderer. Render size may differ. Project data, transient runtime state, and effective audio-modulated values have separate ownership.

AudioWorklet behavior is implemented natively rather than through an embedded web runtime. User-editable base values are persisted; continuously changing audio values are neither saved nor added to undo history.

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

- **Phase 4 — Ordered effects and scene editor**
  - Implement transform, blur, pixelate, threshold, colorize, and RGB split as Metal passes with defined input/output behavior.
  - Support adding, selecting, removing, bypassing, and reordering effect instances, including repeated instances of the same effect.
  - Generate effect parameter controls using the same registry and support keyboard-accessible ordering alongside drag interactions.
  - Reuse intermediate textures and bound resource use during resize and chain edits.
  - **Complete when:** all six effects work alone and in combination; effect order visibly changes rendering; chain edits support undo and file round trips; representative chains pass deterministic render checks.

- **Phase 5 — Physical audio capture and analysis**
  - Enumerate microphones and audio interfaces in Audio Input; select a physical device and appropriate channels using stable device identities.
  - Handle permission requests, unavailable inputs, device disconnect/reconnect, channel layout, and sample-rate changes.
  - Feed bounded audio buffers to native DSP for RMS, peak, low/mid/high bands, and transient detection. Define band boundaries, windowing, normalization, and transient behavior explicitly.
  - Display input status and meters. Keep capture callbacks free of UI work, disk access, and blocking synchronization.
  - **Complete when:** microphone and interface audio drive meters; synthetic silence, tones, impulses, and level changes validate analysis; device changes recover without crashing or stopping visual rendering. Hardware and permission checks are recorded separately from automated checks.

- **Phase 6 — System audio capture**
  - Add **System Audio (DAW, browser, apps)** alongside physical inputs in Audio Input.
  - Open `SCContentSharingPicker` for display selection and configure the stream for audio capture, matching the OS-provided audio-sharing controls.
  - Adapt captured samples into the same analysis pipeline; release unused video samples promptly and never save screen content.
  - Handle cancellation, denied/revoked permission, stream termination, switching inputs, and restart. Explain Screen & System Audio Recording permission where the user encounters it.
  - **Complete when:** DAW and browser/YouTube playback drive the same meters; cancellation and capture termination leave the app usable; switching between physical and system audio releases the previous capture session. Verify the exact picker flow on the supported macOS release.

- **Phase 7 — Persisted audio-to-visual mappings**
  - Map RMS, peak, band levels, and transients to eligible numeric source/effect parameters through stable target identifiers.
  - Provide output range, inversion, documented curve choices, smoothing, and enable/disable controls with live feedback.
  - Compute effective values at render time without overwriting base values; define combination behavior for multiple mappings to one parameter and time-based smoothing independent of frame rate.
  - Persist mapping edits and make them undoable. Handle deleted effects, changed sources, missing devices, and silence safely.
  - **Complete when:** physical and system audio visibly modulate scenes; mappings survive save/reopen; curve, bounds, smoothing, and target-lifecycle tests pass; silence and capture interruption recover predictably.

- **Phase 8 — Performance and projection readiness**
  - Finish fullscreen/external-display output behavior, display disconnect recovery, aspect handling, and output-window lifecycle.
  - Show FPS and frame-time metrics with explicit definitions, including CPU/GPU timing where supported, without putting editor UI into the output.
  - Profile representative scenes and full effect chains. Initial target: sustained 60 FPS at 1080p on the documented reference Mac; measure 4K separately and document limits.
  - Finish keyboard navigation, accessibility, empty/error states, light/dark review, app packaging, and operational documentation.
  - Run an extended capture/render soak, resource-growth checks, persistence fault tests, and deterministic fixtures at fixed seeds/times. Use numerical tolerances for GPU differences rather than claiming cross-device bit identity.
  - **Complete when:** the entire create → edit → capture → map → project → save → reopen workflow passes; frame-time evidence and tested hardware/OS are recorded; remaining limits are explicit.

## Orca orchestration

Use Orca CLI supervised workers after approval where tasks have clear ownership. Keep Phase 1's state/render/window interfaces together under the primary integrator. After that, independently scoped source/effect implementations, persistence work, and audio DSP work may run in separate Orca worktrees against agreed contracts and fixtures.

Each worker gets a self-contained task, files it may change, dependencies, acceptance checks, and required evidence. The coordinator reviews and integrates changes, resolves shared interfaces, and validates the combined app. Native permission dialogs, real audio hardware, and projection behavior need hands-on verification and cannot be proven by worker unit tests alone. Do not launch implementation workers before Phase 1 is approved.

## BAMA workflow

Phase 1 completed the following workflow: `user-stories` to expand approved Phase 1 into checkable stories and `ux-design` notes, then `new-mac-app` to scaffold. Use `mac-design`, `design-system`, and `app-icon` from the first window. Apply `swift-swiftui`, `test-mac-app`, `layout-grid`, and `build-and-verify` as implementation proceeds; use `os-integrations` and `performance` for capture and rendering work.

## Technical references

- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) — system content/audio capture and recommended system picker.
- [Apple SCContentSharingPicker](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker) — OS-managed selection and capture-session UX.
- [Apple AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine) — native audio engine and input node.
