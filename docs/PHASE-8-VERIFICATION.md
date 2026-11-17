# Phase 8 — Production VST3 host integration

Authorized on 2026-11-17 by “Continue with next phase, the screen will be locked.” The production code and headless fixtures are implemented. Actual Studio One and native acceptance remain pending; this phase is not fully accepted or release-certified. Existing Phase 4C and #10 gates remain open. No screen unlock, app activation, hardware, sharing or installed-bundle replacement was attempted.

## Implemented behavior

- Native Apple Silicon `build/VHS.vst3`, version 0.8.0, with a new production class ID, `VHSHostUI` Swift module/dylib and production-only Objective-C bundle marker. These distinguish it from the installed feasibility probe; old and new source state contracts are not silently conflated. Local packaging starts from a clean bundle.
- Matching mono/stereo buses, float32/float64 byte-preserving pass-through, zero audio latency, null/silent channel handling, in-place support, explicit bypass, setup/suspension discontinuity handling and offline-safe behavior. Supported analysis sample rates are 8–192 kHz; oversized analysis blocks/gaps reset the bounded handoff while valid host audio still passes unchanged.
- Shared audio-analysis worker fed by preallocated C++ sample-copy buffers and the existing C queue. RMS, peak, low/mid/high bands and transient are enabled in host mappings. No Swift/UI/FFT/disk/locks/GPU waits are called by process(). Queue overflow and stale/offline/bypassed inputs release live contributions.
- The existing 256-slot contract in MAPPINGS.md: IDs 0x2000…0x20ff, explicit UUID/key bindings, lowest never-bound exposure, retirement on clear, explicit rebind, capacity error without mutation, and stable unavailable targets after graph/preset changes. Bound controls send host begin/value/end gestures; editor-closed playback uses the atomic value bank without creating local undo entries. Host values precede audio/MIDI offsets; bound slots win over legacy RGB lanes.
- Free Run remains seconds. Follow DAW explicitly uses quarter-note beats as animation seconds; musical position is preferred, with valid sample-position/tempo fallback. Stops, seeks/loops, missing/stale context and offline contexts have defined hold behavior. Host transport is a separate latest atomic snapshot, unaffected by event-queue backlog.
- Versioned, self-contained host documents embed project graph/preset/base values/seed/mappings/sync/layout and bindings. Binary state also captures slot values and bypass before any editor exists. Legacy RGB/project states migrate; invalid/truncated state is rejected before mutation. State decoding never creates an editor, compiles a graph or reads a library/project file.
- Signal Host Controls, full host mapping choices, explicit project import/export preserving instance ownership and shared node/preset editing. The local Scene menu does not install standalone application commands. C++ final-reference release from a worker defers controller/UI destruction to the main queue; the audio worker retains its bridge through drain/teardown. Editor detachment retains the instance runtime/output until instance teardown.

Exact UX, routing, parameter IDs and binary/JSON format: [HOST.md](HOST.md). Phase 8A external-display/fullscreen/reconnect and Phase 9 release/performance work are not implemented here.

## Fresh headless verification

Environment: macOS 27.2.1 (26B7131), arm64, full Xcode selected. This is not actual macOS 26 runtime acceptance. Evidence is under [verification/phase8](verification/phase8/).

| Check | Result |
| --- | --- |
| `tools/test.sh` | **120 Swift Testing functions passed**: 47 core, 22 actual Metal renderer, 19 shared input, 15 device/system, 7 bridge, 6 host-runtime and 4 Signal |
| `tools/test-vst3.sh` | Real processor/state/concurrency fixtures passed; Steinberg SDK validator **47 passed / 0 failed**; strict bundle signature and arm64 checks passed |
| Thread Sanitizer | **7 bridge tests passed**, including 20,000-event producer/consumer and 20,000-context coherent snapshot stress; no TSan race report |
| `./build.sh --debug` | Signed local standalone app built; it was not opened or installed |
| Signal/grid/diff checks | Shared specification/styling lint, grid lint and `git diff --check` passed |
| Production linkage | Bundle ID `com.kike.vhs.vst3`; executable links `@rpath/libVHSHostUI.dylib`, with that distinct install name and a single current host dylib in Frameworks |

The six host-runtime tests construct the actual runtime without NSApplication windows/timer polling. They exercise host gesture ownership and playback without an editor, binding persistence/unavailability across presets and undo, state restore before editor creation, independent instances, project import/export and library-independent content, actual shared analysis signals feeding visuals, beat-clock updates, stale note/audio/timing release, and lowest-never-bound/retired/capacity allocation. A Metal fixture proves external clock changes actual oscillator pixels while Free Run retains the existing seconds clock.

The C++ fixtures use the production processor, not a mock reducer: stereo float/double NaN/byte equality, in-place/silence/zero block handling, 96 kHz mono pass-through and queued analysis sample parity, three CC points with retained offsets, highest automation-slot value playback/recall without an editor, bypass recall, offline transparency and legacy migration. They also perform **40 validated state restores/snapshots during 2000 processing blocks** without an editor. The concurrent bridge tests additionally verify coherent latest context and transactional restore controls/revision. This is not an actual DAW audio null/bounce test or long resource soak.

Reproduction:

```sh
tools/test.sh
tools/test-vst3.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test \
  --scratch-path .build/phase8-tsan --sanitize=thread --filter VHSRealtimeTests
./build.sh --debug
tools/check-signal.sh
tools/grid-lint.sh
```

The SDK validator emits expected diagnostics when probing rejected sample rates outside 8–192 kHz, and informational warnings about hidden writable MIDI-controller parameters. `install_name_tool` warns that edits invalidate intermediate signatures; packaging signs afterward and final strict verification passes. Neither these expected messages nor the 47/0 result establish Studio One acceptance.

## Pending attended acceptance

- Studio One scan/load/routing with the new production class ID; audio plus live notes/velocity/CC with monitoring, including stopped transport and controller chase. The earlier feasibility routing is a reference, not evidence for this build.
- Live automation record/playback and DAW undo ownership, dirty indication, parameter refresh, lane/binding stability, and MIDI learn conflict/cancel/recall using actual controllers. Bridge gesture tests are not observed DAW undo behavior.
- Play/stop/tempo/loop/seek behavior and beat-unit comprehension in the actual host.
- Save/quit/reopen two different instances after removing external project/preset files; host-state callback ordering under actual Studio One processing.
- Projection continuing with the editor closed, native editor focus, instance removal/song close/host exit, and coexistence with the installed feasibility probe. The source/thread fixtures do not certify GUI resource lifetime, host quit or resource soaks. The Phase 4C clean-baseline Studio One quit crash remains unresolved.
- Native light/dark/increased-contrast and minimum/default/wide layout, keyboard/responder/menu behavior, file-panel/slot-picker focus, and VoiceOver for the new controls. No new screenshots/layout captures or full standalone GUI self-test were run while locked; existing phase evidence remains intact.
- Physical/system-input, permission, external-display and actual macOS 26 checks remain as previously tracked. Performance, latency/resource measurements, packaging/notarization and release certification remain Phase 9.

No production checkbox requiring actual host/native acceptance is counted passed. Phase 8A is the next feature implementation and needs its own authorization. The user subsequently authorized committing/pushing the implementation and updating documentation/roadmap status. The accompanying commit records the production code and headless evidence; issue #12 stays open for actual host/native acceptance. Existing `.agents/`, `.claude/` and `skills-lock.json` were left untouched.
