# Phase 5A — Shared input engine verification

Implemented on 2026-11-11 following the user's instruction to continue the next phase without unlocking the Mac and save desktop verification for later. Phase 5 was split into headless shared-engine work (5A) and standalone device adapters/Signal input UI (5B). S-052/S-053 cover this slice. Parent Phase 5 remains incomplete.

## Implementation

- VHSInput library: worker-owned AudioAnalyzer and MIDIInput, transient Sendable value snapshots, no document/history/UI/renderer dependencies.
- Preallocated C SPSC audio and MIDI queues: atomic publication, whole-block acceptance, fixed capacity and timestamp/offset retention. Generation-based loss/disconnect recovery skips stale queued data, including MIDI notes whose release was lost.
- Swift/Accelerate RMS/peak, independent stereo channel power, adaptive Hann/DFT bands and normalized onset score. Warm-up, rate/channel/timeline resets, nonfinite samples and overload semantics are specified in [INPUT-ENGINE.md](INPUT-ENGINE.md).
- MIDI 1.0 stream normalization: running status and split messages, realtime interleaving, note/CC values, zero-velocity release, channel filters, channel-mode releases, resets and instance isolation.

No UI or commands changed. No device permissions requested, physical sources opened, project schema/mappings added, installed app/probe replaced or Studio One session started. The existing probe's process callback and bridge semantics are unchanged; the new engine awaits adapters.

## Observed automated results

Environment: native arm64, macOS 27.2.1 (26B7131), Swift 6.4.2, full /Applications/Xcode.app/Contents/Developer selected for builds/tests. This does not establish macOS 26 runtime compatibility.

| Check | Actual result |
| --- | --- |
| tools/test.sh | PASS: 73 Swift Testing functions: 30 core, 17 Metal renderer, 5 existing realtime bridge, 4 Signal numeric, 17 new input functions (including parameterized tone/band/channel cases). Actual Metal fixtures ran. No compiler warnings/errors in this run. |
| Input DSP fixtures | PASS: silence/warm-up/time, calibrated tones at 8/22.05/44.1/48/96/192 kHz, all bands, impulses/onset/recovery, DC exclusion from bands, invalid/over-range samples, rate/channel/time gaps. |
| Queue and layout fixtures | PASS: interleaved irregular blocks vs planar 8192-frame stereo blocks yield identical snapshots; anti-phase preserves energy; silent second channel halves power. Whole-block rejection, stale-data recovery, metadata rejection and queue wrap are covered. Synthetic layouts are not actual host/device adapters. |
| MIDI fixtures | PASS: all 16 channels, note/CC normalization, fragmented/running status and timing, realtime/system/malformed streams, filtering, channel-mode/reset behavior, bursts, lost release/disconnect recovery and separate instances. |
| Thread Sanitizer | PASS: all 17 input test functions under swift test --sanitize thread in a separate scratch directory, including 10,000-record concurrent audio and MIDI producer/consumer queue-wrap tests. No Thread Sanitizer race reports. This is not a hardware capture soak. |
| ./build.sh --debug | PASS: local build/VHS.app built and ad hoc signed; no install/open requested. |
| tools/test-vst3.sh | PASS: generated graph fixture, real processor/state fixtures and Steinberg validator 47 passed / 0 failed; strict signature verification and arm64 bundle check succeeded. Expected install_name_tool signature-invalidation notices precede re-signing; no compiler warnings/errors. |
| Diff whitespace | git diff --check passed. |

Raw command logs are retained in [verification/phase5a/](verification/phase5a/). Build/test scripts completed with exit status 0. Callback code was reviewed for bounded copies/loops, lock-free atomics and absence of allocation, locks, Swift/UI/render calls; no measured callback-deadline or input-to-display latency claim is made.

## Deferred work and acceptance boundaries

Phase 5B must implement physical audio/Core MIDI enumeration, stable selections, permissions, hot-plug/reconnect, actual adapters and shared Signal input status/meters. Wire engine snapshots through explicit worker ownership and publish values safely to control/UI; do not run DSP on capture callbacks. Production host feeding is still Phase 8, and physical adapters never belong in the plug-in. Analysis/MIDI values must remain transient when mappings arrive in Phase 7.

Outstanding Phase 4/4A/4B attended checks and actual observed failures are preserved separately in [PHASE-4C-VERIFICATION.md](PHASE-4C-VERIFICATION.md). Studio One quit-time failure remains unresolved; the validator passing does not change its failed acceptance. No new native screenshots, VoiceOver, Bold Text, host keyboard checks, physical device tests, minimum-OS verification or hardware performance claims were made in this locked-desktop slice.
