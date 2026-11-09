# Phase 3A — Studio One feasibility verification

Date: 2026-11-09. Authorized by the user's “Implement next phase” instruction. Gate passed for the minimal prototype, with the limits below. This is not production VST3, production MIDI learn, effects, or graph completion.

## Environment

MacBook Pro Mac18,1 / Apple M6 / 16 GB; macOS 27.2 (26B7124). Studio One **Professional 5.5.2 build 86528**, actual **ARM64** process, not inferred from its universal executable. Initial process sample and the start-page version/edition were inspected. Xcode 27.2 (27B52), Swift 6.4.2, Apple clang 21, CMake 4.4.5; arm64-only plug-in, deployment target macOS 26. SDK 3.8.1 pinned to `3cdf9ca5d1f5b1b21e0a86832aa4abe55607bd96`. macOS 26 runtime remains unverified under #10.

## Reproduce

```sh
# Requires full Xcode, CMake, git/network for the first pinned SDK checkout.
tools/build-vst3.sh --install
tools/test-vst3.sh
tools/test.sh
./build.sh --debug
tools/selftest.sh
tools/probe-vst3-ui.sh
python3 tools/vst3-fixtures.py
```

The prototype installs to `~/Library/Audio/Plug-Ins/VST3/VHS Phase 3A.vst3`. Restart Studio One for a fresh scan. The SDK is downloaded into ignored `.build/vst3sdk`; no SDK source is vendored. The plug-in contains its dylib, shader bundle and MIT notice. No standalone VHS process is needed. To uninstall the probe, remove that one `.vst3` bundle while the host is closed. Do not overwrite an unrelated production plug-in.

Create an empty test song. Import `/tmp/VHS-phase3a-probe.wav` to a stereo audio track; insert Effects → VHS → VHS Phase 3A. Add an instrument track, choose **VHS Phase 3A** as its destination and **Visual MIDI 1** as its event input/channel destination. Import `/tmp/VHS-phase3a-notes.mid` to that track at bar 1. Mute the Main output if testing silently; the audio insert still receives track audio. Play from bar 1. The default bindings are peak → red, held velocity → green, host-mapped CC1 → blue. The base sliders remain separate from those live additions.

For learn, also import `VHS-phase3a-learn.mid` (CC74), or send an actual controller through the routed instrument track. In the probe choose Learn Blue, send/change a CC, inspect Channel/CC, Confirm or Cancel; Clear Learn restores CC1. Studio One chases controller values on playback start: arm after the initial chase or cancel/relearn a chased candidate. A specific CC74 candidate and successful confirmation were observed; a connected hardware controller was not tested. This feasibility assignment is runtime-only; persisted definitions, note learn, conflict/Omni handling and final UX remain Phase 7.

The local test song is `~/Documents/Studio One/Songs/VHS Phase 3A Probe/VHS Phase 3A Probe.song`; it contains two probe inserts and the MIDI route. Source audio was generated in `/tmp`, so regenerate the fixtures if needed. Do not use this disposable probe state as the production project format.

## Actual Studio One observations

| Check | Observed result / evidence |
| --- | --- |
| Fresh native scan | Scan result `0x00000000`, class data YES. Listed under VST3/Analysis, version 0.3.1, class `{80722923-863C-4290-A50F-11B8071A3A01}`. See `studio-one-initial-scan-observation.md`; `studio-one-scan.txt` records a later cached-class launch. |
| Native editor and shader loading | SwiftUI sliders and the existing Solid Metal source render inside Studio One. An initial nested-resource path defect caused generic knobs; fixed before the successful native checks. No app/IPC/capture device was involved. |
| Stereo audio plus notes/velocity/CC together | `studio-one-audio-midi-cc1.png` shows peak 0.250, velocity 0.756 (96/127), CC1 0.252 (32/127), 120 BPM / Playing, with the effective visual changed. Instrument track targets the audio insert's event bus; no sidechain or instrument classification was needed. |
| Host CC discovery and confirmation | `studio-one-learn-cc74.png` shows Channel 1 / CC74 after Learn Blue; Confirm changed the assignment to Blue: Channel 1 / CC74 (`studio-one-learn-confirmed.png`). Delivery used IMidiMapping → parameter queues, not raw CC assumptions. |
| Editor close/reopen | Closed the native editor, started track playback, observed the output change with the editor absent, then reopened the editor. Output and per-instance render timer continued. |
| Two independent instances | First base Red changed to 0.34, second remained 0.24. Both opened separate output windows. Captures `studio-one-instance1-output.png`, `studio-one-instance2-output.png` and `two-instance-windows.txt`. |
| Minimal song recall | Saved two instances, quit Studio One, reopened the song. First Red restored 0.34, second 0.24; live CC/notes and learn candidate reset. `studio-one-recalled-instance1.png`, `studio-one-recalled-instance2.png`. `recalled-windows.txt` contains no output windows. |
| Instance removal | With both outputs reopened, removed the second insert through its native host tab menu. Output 6501 disappeared; output 6496 and the first editor remained. Compare `before-removal-windows.txt` and `after-removal-windows.txt`. |
| Song close and host exit | Closed the modified test song, discarded only the removal test, and observed only the Studio One start window with no output windows (`after-song-close-windows.txt`). Then normal host Quit completed; no remaining studioapp process. Earlier quit/reopen with two instances also completed. |

The first instance can report historical queue overflow when its editor has never opened: the bounded handoff accumulated while no Swift consumer existed. Opening it drains bounded old data and resets notes. This counter measures dropped visual/input records, not audio dropouts; no audio callback waits for the UI. Production input telemetry/analysis is later work.

## Automated and visual checks

- `tools/test-vst3.sh`: Steinberg validator **47 passed, 0 failed** against the packaged arm64 bundle. Actual processor fixtures prove bit-preserving stereo float/double copying (including NaN payload), in-place operation, silence handling, zero-sample flush, MIDI offsets/timestamps, CC discovery IDs/records, transport, isolation, minimal state recall and truncated-state rejection. Byte transparency is proven at the actual processor boundary; a Studio One rendered-bounce/null comparison was **not** performed.
- `tools/test.sh`: **22 core, 9 actual Metal, 3 bridge tests passed**. Bridge tests include capacity/overflow/recovery, independent mailboxes, invalid values and 20,000 concurrent producer/consumer records with ordered payloads.
- Standalone debug build and `tools/selftest.sh` pass after extracting `RenderSession`; source save/open/undo, shared frames and output lifecycle still pass.
- Standalone `tools/snap.sh` completed; default/minimum light/dark control and source layouts pass `tools/check-layout.swift`. Existing control light/dark images were reviewed; preview, labels and inspector remained intact.
- `tools/probe-vst3-ui.sh` passes the real native runtime/editor/output harness: per-instance values/notes, CC candidate/offset, host context, overflow reset, two outputs, close/reopen, detach with output retained, teardown. It explicitly checks each capture window is key. `plugin-editor-light.png` and `plugin-editor-dark.png` were reviewed: readable native controls, aligned column, aspect-correct purple Solid preview, no clipping or unintended focus ring. Six probes in two areas pass for each appearance. These harness checks are labeled separately from Studio One observations.
- Grid lint and `git diff --check` pass. No live GPU readback or audio-to-UI call was added.

Standalone command declarations were not changed. External Edit-menu enablement before/after a slider, Command-Z / Shift-Command-Z and Command-1-from-output were **not manually repeated** in this phase; earlier Phase 3 evidence remains intact. Native plug-in slider changes and output actions were exercised. VoiceOver, keyboard-only full host navigation, macOS 26, real hardware MIDI/live monitoring, transport seek/loop/sync policy, host bounce nulling, production bypass/suspension/automation/undo, soaks, performance and distribution signing remain unverified/later acceptance. None are counted as performed here.

## Decision

See [0001 — Native VST3 runtime boundary](decisions/0001-vst3-runtime.md) for SDK/JUCE comparison, packaging, ownership, lifetime, bounded handoff, recall and stable automation-ID strategy. S-016–S-018 are complete at feasibility scope. Phase 4 is next and is not implemented or implicitly authorized by this record.
