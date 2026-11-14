# VHS

VHS is a macOS real-time visual performance instrument delivered as a native standalone app (`VHS.app`) and a VST3 plug-in (`VHS.vst3`). Audio and MIDI drive procedural scenes and a separate Metal projection output. Studio One 5.5.2 is the primary DAW target.

## Replaces
A separate visual scene editor and performance output workflow. No reference application has been specified.

## Main jobs
1. Build a scene using the simple source/effect chain or a node-based shader editor, with immediate visual feedback.
2. Perform through a separate output window while editing in the control window.
3. Connect microphone, audio-interface, or system audio to visual parameters and save the setup as a project.
4. Receive track audio and routed MIDI inside Studio One, follow DAW tempo/transport, automate visual controls, and restore the scene with the song.
5. Learn MIDI controller/note assignments to source, effect, and node parameters in standalone and Studio One.
6. Browse factory presets, save/organize user presets, and exchange portable looks.
7. Select an external display and project content-only fullscreen while keeping controls on the working display.

## Data
- Project: schema version, identity, name, scene, audio/MIDI mappings, and synchronization settings.
- Scene: source/effect chain or typed shader graph, stable node/parameter IDs, connections, values, and deterministic seed.
- Preset: named, versioned portable graph/scene, values, seed, audio/MIDI mapping definitions and sync settings; factory or user-owned. Device/display identities and live input values are excluded.
- Parameter definition: stable identifier, type, range, default, and modulation eligibility.
- Audio mapping: analysis signal, target parameter, range, curve, and smoothing.
- MIDI mapping: channel/note/controller selection, target, range, and response. Live notes, levels, and controller values are transient.
- DAW state: versioned, self-contained scene and mapping snapshot per plug-in instance; no external project file required to reopen a song.

## Shape
Swift 6, SwiftUI/AppKit, and Metal remain the shared native foundation. A thin VST3 adapter connects the host to the shared engine; select direct SDK/C++/Objective-C++ integration or a JUCE shell after the Phase 3A feasibility test, rather than rewriting the app. Baseline remains macOS 26+, with Apple Silicon as the initial delivery target. Local and offline; no account or server. The repository path remains unchanged.

## System hooks
Physical audio input through Core Audio/AVAudioEngine; system audio through ScreenCaptureKit and the macOS sharing picker. Separate projection window with fullscreen and external-display support. Microphone and system capture permissions handled in context.
Standalone MIDI uses Core MIDI. The VST3 receives audio, MIDI events/controller assignments, automation, and transport from the host; it does not open physical capture devices or request microphone/system-capture permission. Audio passes through unchanged; VHS generates visuals, not sound.

## Reference
The user's feature specification and the existing Phase 1–3 implementation. Reference installation inspected locally: MacBook Pro Mac18,1, Apple M6, 16 GB RAM; macOS 27.2 (26B7124); `/Applications/Studio One 5.app`, version 5.5.2 build 86528, universal arm64/x86_64 executable. Installed architecture does not prove the host's running mode or compatibility; verify those in Phase 3A.

## Look
Approved design direction: VHS / Signal (`design/DESIGN-SYSTEM.md`, `design/KIT.md`, `design/tokens.json`). Precise, restrained, electric: neutral instrument chrome around a dominant visual canvas, shared native semantic components, system appearance/accent overrides, keyboard/accessibility and light/dark/increased-contrast states. Native Mac menus, dialogs and window behavior remain. Phase 4B implements shared VHSSignal components for current features, including the graph editor and existing plug-in probe UI; manual acceptance remains deferred. Every later UI-bearing phase adopts Signal automatically within its feature scope. Performance output contains only rendered content.

## Required scope
Project creation, rename, open, atomic save; immutable runtime snapshots and undo/redo; solid, gradient, noise, oscillator, and shape sources; transform, blur, pixelate, threshold, colorize, and RGB split effects; generated controls, effect ordering, and preview; physical and system audio capture; RMS, peak, three frequency bands, and transient analysis; persisted mappings with curves and smoothing; FPS and frame-time metrics; deterministic rendering tests.
Also required: a node canvas with typed ports, branching/blending, live Metal compilation, last-valid-render recovery, undo, save/reopen and chain migration; factory/user preset browser, search, save/rename/duplicate/delete and import/export; selectable external-display fullscreen with Fit/Fill, escape/recovery and hot-plug handling in both delivery modes; standalone MIDI input and MIDI learn in standalone and VST3; macOS VST3 with host audio and MIDI input, tempo/transport synchronization, stable automation controls, embedded song recall, independent instances, and output rendering while the plug-in editor is closed.

## Not in version one
Audio Units, Windows, VST2, AAX, other DAW certification, and Intel/Rosetta delivery; audio synthesis/effects; independent scene crossfading; graph feedback/simulation; video recording/streaming and hosting third-party plug-ins; cloud sync, accounts, and collaboration. VHS itself being a VST3 is required and is distinct from hosting other plug-ins. MIDI 2.0, MPE, SysEx, program-change scene banks, and standalone MIDI-clock synchronization are deferred.

## Native audio decision
Implement the requested AudioWorklet analysis behavior natively in Swift/Accelerate. AudioWorklet itself belongs to the browser platform and will not be embedded in the native app.

## Status
Original plan approved on 2026-11-08; revised for the user's standalone + macOS VST3 requirement. Phases 1–3 are implemented and functionally verified. Phase 3A was subsequently authorized by “Implement next phase” and passed at prototype scope; see PHASE-3A-VERIFICATION.md. Phase 4 was authorized on 2026-11-10 and is implemented and automatically verified; visual/keyboard checks are deferred at the user’s direction (PHASE-4-VERIFICATION.md). Phase 4A was subsequently authorized and implemented with automated verification (PHASE-4A-VERIFICATION.md); manual checks remain deferred. Phase 4B — Signal UI implementation — was inserted as next on 2026-11-10 after design approval; the user subsequently authorized “Implement next phase 4B” and migration is implemented with automated checks (PHASE-4B-VERIFICATION.md), with manual acceptance deferred. On 2026-11-11 the user authorized the next work without unlocking the Mac. Phase 5A shared audio-analysis/MIDI engine is implemented with headless tests (PHASE-5A-VERIFICATION.md); Phase 5B device adapters/Signal input UI were subsequently authorized and implemented with automated/virtual-source/layout checks (PHASE-5B-VERIFICATION.md); actual hardware/permission/native visual acceptance remains in Phase 4C. Phase 6 system-audio capture was subsequently authorized and implemented with automated evidence (PHASE-6-VERIFICATION.md), with live sharing/permission/playback acceptance in Phase 4C. Phases 7–9 (including 7A and 8A) remain unstarted. Remaining attended verification is separated into Phase 4C (PHASE-4C-VERIFICATION.md). Scope expanded on 2026-11-09; see issues #13–#15. The initial scope revision authorized planning/issues only; the subsequent instruction authorized Phase 3A; the subsequent 2026-11-10 instructions authorized Phase 4 and then Phase 4A. Accessibility and actual macOS 26 runtime checks remain tracked in GitHub #10.
