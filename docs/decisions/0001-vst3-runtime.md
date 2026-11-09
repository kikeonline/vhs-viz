# Native VST3 runtime boundary — Phase 3A

Date: 2026-11-09. Scope: feasibility prototype, not the production plug-in or Phase 7 mappings.

## Decision and alternatives

Use Steinberg VST3 SDK 3.8.1 with a thin Objective-C++ adapter and a Swift dynamic library for the native editor/runtime. Retain VHSCore snapshots/reducer and VHSRenderer Metal pipeline. The prototype uses the SDK's non-distributable `SingleComponentEffect`; each combined component/controller owns its bridge and lazily created Swift runtime. This makes the processing-to-native-editor ownership directly testable in Studio One without IPC. It does not install the standalone app's menu tree, file controller, MenuState, capture adapters, or termination actions in the DAW.

A conventional separate AudioEffect/EditController was considered: it better supports distributed hosting, but requires an explicit processor/controller channel and different ownership for editor-closed output. No distributed-host requirement exists for the named Studio One target. Do not silently turn a combined component into a distributable class. Revisit separate components if a production host or lifetime requirement invalidates this boundary.

A JUCE 8 shell would supply plug-in wrappers, bus negotiation and host utilities, but adds another framework and packaging layer around the existing SwiftUI/Metal implementation. JUCE modules are dual licensed under AGPLv3/commercial terms; Steinberg's pinned SDK is MIT. No JUCE prototype or performance comparison was run; choosing the thin adapter reflects the working native-host probe, not a claim that JUCE cannot embed the editor. Primary references: [SDK repository](https://github.com/steinbergmedia/vst3sdk), [JUCE license](https://github.com/juce-framework/JUCE/blob/master/LICENSE.md).

## Version and build boundary

SDK commit `3cdf9ca5d1f5b1b21e0a86832aa4abe55607bd96` (3.8.1), including its pinned base/cmake/pluginterfaces/public.sdk submodules. `tools/build-vst3.sh` verifies that revision and fetches required submodules into ignored `.build/vst3sdk`. CMake 4.4.5, Xcode 27.2 (27B52), Swift 6.4.2, Apple clang 21; deployment target macOS 26, native arm64 only. The SDK's universal-build default is explicitly disabled.

`VHS Phase 3A.vst3/Contents/MacOS/VHSPrototype` links `@rpath/libVHSPluginUI.dylib`, copied to `Contents/Frameworks`. A loader-relative rpath resolves it without the app or build checkout. The SwiftPM renderer resource bundle and SDK MIT notice live in `Contents/Resources`. Shader lookup starts from the adapter's bundle, then uses the nested resource bundle's resource URL; it never starts from the DAW's Bundle.main. Both Mach-O files are locally ad-hoc signed after packaging. This is not a notarized distribution build.

## Ownership and lifetime

- VHSCore owns immutable value contracts, history and clock policy. `RenderSession` owns one renderer, clock, common frame and weak surface list; both standalone and the plug-in use it.
- The adapter owns a reference-counted C bridge, base parameter values, host stream state and one Swift runtime. No mutable instance singleton or separately running app is involved.
- The Swift runtime owns held notes, transient CC/peak/transport, a display timer, native hosting views and one output window. Editor removal destroys the editor view only. The runtime timer and output remain until instance termination.
- Removing/destroying an instance clears its edit callback and closes its output. Final Swift teardown is marshalled to the main queue if the host releases the component off-main. The retained bridge survives that hop. Host editor attachment/removal must occur on the main thread; unsupported attachment returns failure.
- Output never appears as a side effect of state restore. Show Output is explicit. Output is not tied to NSApp.terminate and no plug-in code terminates Studio One.

## Real-time boundary

`process` remains C++/C, with no Swift, AppKit, SwiftUI, disk access, rendering, GPU synchronization, mutexes or heap allocation. It copies stereo float/double samples without arithmetic; silence flags produce zero-filled silent outputs. Peak measurement only reads input. It publishes at most 512 note events and one block record plus a bounded number of declared parameter queues per call. MIDI offsets and project-sample timestamps are retained. The prototype uses free-running display time and observes tempo/play state; transport synchronization remains Phase 8.

A preallocated 256-slot SPSC queue transfers fixed C records to the 60 Hz main-thread consumer. Release/acquire index atomics protect payloads; 32/64-bit atomics must be lock-free at compile time. Full queue drops the new record, increments a counter, and the consumer clears held-note state after draining old note-ons. Event bursts beyond the inspection limit also request reset. More than 250 ms without block delivery clears held notes/peak. The prototype's peak/transport share the queue: a long UI stall can drop/coarsen display information, without delaying host audio. Production analysis must measure and select its sample handoff separately in Phase 5.

Base RGB values use atomic bit-pattern mailboxes, so automation does not touch Swift state or local undo. Swift only polls these on the display thread. UI changes call the host's begin/perform/end edit boundary through a control-thread callback. This is not full production gesture/host-undo certification. No live GPU readback was added.

## Proven routing and learn approach

Stereo main input/output plus one 16-channel event input, category `Fx|Analyzer`, works as a Studio One audio-track insert. An instrument track can target the inserted VHS instance's `Visual MIDI` event bus while the audio track supplies audio. No instrument category, synth output, sidechain, capture permission or IPC is needed for this probe.

VST3 CCs arrive as parameter changes through IMidiMapping, not assumed raw CC bytes in IEventList. The prototype reserves a fixed hidden discovery bank: `0x1000 + channel*128 + CC` for 16 channels × 128 controllers. Host delivery of CC1 and a previously unbound CC74 was observed. Learn Blue → move/play the controller → review channel/CC → Confirm/Cancel is a concrete working path; Clear Learn returns to the CC1 default. This probe assignment is runtime-only and deliberately is not the production persisted learner.

Studio One may chase prior controller values on playback start. Arm learn after that initial chase and inspect the candidate; Cancel/Relearn recovers a chased candidate. Production Phase 7 must distinguish/handle chase and waiting/no-input/conflicts, persist confirmed definitions, support note learn and channel/Omni, and prove real-controller monitoring. The phase gate does not count this prototype as those later acceptance tests. See [IMidiMapping contract](https://steinbergmedia.github.io/vst3_doc/vstinterfaces/classSteinberg_1_1Vst_1_1IMidiMapping.html).

## State and stable automation strategy

Prototype component state is little-endian UInt32 `0x56485331` magic plus three bounded finite Float64 base RGB values (28 bytes). Validate the entire candidate before updating any value. Live notes, CC, peak, host position/tempo and output visibility are excluded. DAW session state owns recall; no `.vhsproject` path is saved. Learn definitions, graph and project schema are intentionally not represented by this prototype state format.

Keep source automation IDs 0–2 fixed; ID 3 is the CC1 probe surface, and the hidden discovery range is fixed. Production must version its full host-state envelope and provide a bounded binding-slot table for dynamic node/effect controls, with stable target UUID/parameter keys saved in that envelope. Reorder never renumbers slots; deletion leaves a disabled unresolved binding and never silently retargets a host lane. Do not reuse the prototype class ID for an incompatible production state/parameter contract. Phase 7 specifies precedence; Phase 8 implements and certifies host automation, gestures, bypass, suspension and song undo.

## Evidence and limits

[Phase verification](../PHASE-3A-VERIFICATION.md) separates actual Studio One observations, direct processor fixtures, native harness checks and outstanding checks. macOS 26, third-party hosts, Intel/Rosetta, live hardware MIDI, long-session performance, distribution signing and production automation are not certified here.
