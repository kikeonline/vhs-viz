# VHS

VHS is a native macOS real-time visual performance instrument for building procedural scenes and projecting GPU-rendered visuals that can react to audio.

## Replaces
A separate visual scene editor and performance output workflow. No reference application has been specified.

## Main jobs
1. Build a scene from one procedural source and an ordered chain of effects, with immediate visual feedback.
2. Perform through a separate output window while editing in the control window.
3. Connect microphone, audio-interface, or system audio to visual parameters and save the setup as a project.

## Data
- Project: schema version, identity, name, scene, and audio mappings.
- Scene: selected source, typed parameters, ordered effect instances, and deterministic noise seed.
- Parameter definition: stable identifier, type, range, default, and modulation eligibility.
- Audio mapping: analysis signal, target parameter, range, curve, and smoothing.

## Shape
Swift 6, SwiftUI control window, AppKit window integration where needed, and Metal rendering. Proposed baseline: macOS 26+. Local, offline, file-based projects; no account or server. The existing repository path remains the project root.

## System hooks
Physical audio input through Core Audio/AVAudioEngine; system audio through ScreenCaptureKit and the macOS sharing picker. Separate projection window with fullscreen and external-display support. Microphone and system capture permissions handled in context.

## Reference
The user's feature specification. This checkout has no existing app implementation to migrate.

## Look
Native Mac controls with system accent, consistent design tokens, keyboard support, accessible labels, light and dark appearances, and a VHS app icon. Performance output contains only rendered content.

## Required scope
Project creation, rename, open, atomic save; immutable runtime snapshots and undo/redo; solid, gradient, noise, oscillator, and shape sources; transform, blur, pixelate, threshold, colorize, and RGB split effects; generated controls, effect ordering, and preview; physical and system audio capture; RMS, peak, three frequency bands, and transient analysis; persisted mappings with curves and smoothing; FPS and frame-time metrics; deterministic rendering tests.

## Not in version one
Node graphs or scene mixing; video recording/streaming and third-party plugins; cloud sync, accounts, and collaboration. These are proposed boundaries, not reductions to the requested features.

## Native audio decision
Implement the requested AudioWorklet analysis behavior natively in Swift/Accelerate. AudioWorklet itself belongs to the browser platform and will not be embedded in the native app.

## Status
Plan approved on 2026-11-08. Phases 1–3 are implemented and functionally verified; Phases 4–8 have not started. Accessibility and macOS 26 runtime checks remain tracked in GitHub #10.
