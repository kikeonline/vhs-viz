# Phase 6 — Standalone system-audio capture

Authorized on 2026-11-11 by “Implement next phase”. Implementation and available automated checks pass. Live sharing/permission/playback and native appearance/accessibility acceptance remain deferred at the user's direction into [Phase 4C](PHASE-4C-VERIFICATION.md#phase-6-attended-acceptance-added-november-11). No actual system-audio capture is claimed from this locked-desktop run.

## Implemented

System Audio is an option in standalone Inputs. Choose Audio to Share opens the native SCContentSharingPicker for an application/display; only a selected filter can create a stream. Existing shared meters consume the audio through VHSSystemIO's bounded native PCM receiver. Microphone capture is disabled; no screen, camera, recording or clip-buffer output is registered. Non-audio callbacks return before sample inspection. No screen/audio recording is saved.

Picker observers and streams retain their own request generation; stale updates, cancellation, completion and termination cannot act on a newer request. Native receivers are disabled and the sample queue is barriered before the discontinuity reset. Each receiver retains its queue owner through in-flight callbacks. Physical capture cannot start until system teardown completes; system startup first stops physical capture. Shared audio revisions also keep an older status poll or delayed microphone authorization from affecting the newer source.

Off, Picking, Starting, Capturing, Cancelled, Denied, Failed, Ended and Stopping are explicit. No-data expires to Waiting rather than fabricated silence. Denial offers the native Screen & Audio Settings pane; retries are explicit. Source-kind preference is local and never starts sharing after launch or project recall. Project schemas, mapping controls, undo, output content and VST3 callbacks are unchanged. Only standalone depends on VHSSystemIO.

[SYSTEM-AUDIO.md](SYSTEM-AUDIO.md) describes ownership, format/capacity limits, source switching, cancellation, privacy and API references. Usage descriptions for screen/system audio were added to the signed standalone bundle.

## Observed automated checks

Environment: native arm64, macOS 27.2.1 (26B7131), Swift 6.4.2, full Xcode. GUI acceptance remains deferred; no live sharing picker, SCStream, permission request or real system-audio playback was performed. The native cancellation fixture queues Present and Stop within one MainActor closure, rejecting the stale request before any picker is instantiated.

| Check | Actual result |
| --- | --- |
| tools/test.sh | PASS, exit 0: 88 Swift Testing functions — 30 core, 17 actual Metal renderer fixtures, 5 bridge, 4 Signal, 17 shared input, 8 prior device, 7 new system-audio functions. Final run has no compiler warnings/errors. |
| Native PCM fixture | PASS: synthetic CMSampleBuffers traverse the same C receiver used by SCStreamOutput. Planar/interleaved anti-phase stereo preserves RMS/band energy and frame timestamps; irregular mono input, overflow/reset and rate changes recover. Native buffers are copied into the shared queue, not analyzed on the callback. |
| Invalid/non-audio input | PASS: disabled receivers, defensive video/microphone paths, nil/untyped/invalid buffers, unsupported integer/channel formats, invalid timestamps and oversized frames reject safely. No image output was captured. Core Media requires the exact one/two-buffer list byte length on this OS; the initially failing one-buffer fixtures pass after that fix. |
| Native cancellation/isolation | PASS: idle sessions own independent queues; Present then Stop cancels before the main queue can instantiate a picker, reaches Off, and releases cleanly. Stale cross-source requests and requests after terminal service shutdown cannot present a picker. Terminal-state policy requires an explicit new request. These tests do not execute a real stream's asynchronous start/stop or live picker callbacks. |
| Thread Sanitizer | PASS, exit 0: all 15 device/system functions in two suites, including synthetic native PCM, cancelled native request, real Core MIDI virtual-source delivery/stop/reconnect and existing controls. No Thread Sanitizer reports or suppressions. This does not certify actual ScreenCaptureKit callback scheduling. |
| Signed app | ./build.sh --debug PASS, exit 0; strict signature verification and Info.plist lint pass. NSScreenCaptureUsageDescription and NSAudioCaptureUsageDescription are included; existing microphone description remains. No install/restart of the user's app or probe. |
| App input self-test | PASS, exit 0: physical/MIDI/System Audio choices and transient values leave document/history unchanged in isolated mode, then clean app termination. No permission/capture/defaults writes occur in fixtures. It is not an active-stream quit or keyboard/menu test. |
| System Audio geometry | PASS: 100 layout-only fixtures — eleven system states (including captured silence/no-data), top/bottom scrolling, four appearance/contrast variants and default/minimum/wide toolbar layouts. Final denial state includes the privacy-settings action. |
| Physical-input geometry regression | PASS: 84 existing input state/scroll/appearance/toolbar fixtures with the extended source picker. Raw probes and checker output retained. Neither geometry set contains PNGs or establishes native appearance, real contrast settings, VoiceOver, focus return or actual picker positioning. |
| Styling/C/diff checks | tools/check-signal.sh, tools/grid-lint.sh and git diff --check pass. Native target passes clang -fobjc-arc -fblocks -Wall -Wextra -Werror -fsyntax-only. No callback path enters Swift/UI/rendering, reads/writes disk, spins on locks or waits for GPU work. No timing/performance measurement is claimed. |
| VST3 regression | tools/test-vst3.sh PASS, exit 0: graph fixture, real processor/state tests and validator 47 passed / 0 failed, strict signature and arm64 check. Expected install_name_tool signature notices precede re-signing. The UI dylib's direct dependency list contains no ScreenCaptureKit/CoreMIDI/AudioToolbox link; native capture targets are absent from its package dependencies. No new actual Studio One session was run. |

Final logs and all 184 measured geometry files are in [verification/phase6/](verification/phase6/). Layout runs explicitly skipped every image. The signed debug app is at build/VHS.app; the installed app/probe were not replaced.

## Not yet accepted

Phase 4C retains actual sharing picker/consent/revocation, DAW/browser playback and format/scope, physical/system source handoff, OS sharing stop/termination, sleep/wake, active-capture Quit, sustained resource/latency behavior, native light/dark/contrast/Bold Text, keyboard/Escape/focus return, VoiceOver and VST3 permission isolation checks. Those require an attended unlocked desktop. Unit tests and native PCM fixtures are not actual source or permission acceptance.

Prior Studio One quit-time failure, macOS 26 runtime verification and production VST3 certification remain open. Phase 7 is next and requires separate authorization.
