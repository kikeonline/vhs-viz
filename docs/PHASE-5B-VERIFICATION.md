# Phase 5B — Standalone audio/MIDI adapters and Signal inputs

Implementation authorized by “Let go with next phase” on 2026-11-11, after implemented Phase 5A. Implementation and available automated checks pass. Parent Phase 5 physical/permission/visual acceptance remains pending in [Phase 4C](PHASE-4C-VERIFICATION.md), under the user's instruction to continue without unlocking the Mac. No unperformed check is marked passed.

## Implemented scope

- Standalone-only AUHAL microphone/interface enumeration, stable UID selection, mono/adjacent stereo channel selection, explicit Start/Stop and in-context microphone permission request. Denied/restricted/missing/invalid-channel/capture-error/no-data states retain an actionable input UI. Usage description is bundled in the app.
- Standalone-only Core MIDI source enumeration and stable unique-ID selection, explicit Start/Stop, Omni/channel filtering, protocol-1 input callback feeding Phase 5A note/CC normalization, last event/held-note status and stop/disconnect reset.
- Worker actor owns catalog refresh, native controls, queues and DSP; publishes value snapshots to the main actor at bounded cadence. Callback contexts publish readiness with release/acquire, use bounded/preallocated C handoffs, and quiesce before disposal. No callback invokes Swift/UI/DSP/rendering or waits for GPU completion.
- Reconnect policy retains a selected identity, never substitutes a default. Format/endpoint changes reconfigure; stale configuration/permission results cannot override a newer Stop. Terminal shutdown prevents late Start/configuration requests.
- Inputs toolbar popover uses shared Signal type/colors/spacing/buttons and the new reusable SignalMeter. RMS/Peak dBFS, normalized bands/transient, missing-data dash, measured silence and textual clipping/loss status. Inputs and meters never appear in performance output or the existing VST3 editor.
- Device/channel choices are local UserDefaults data; no launch auto-start, project schema change, input-value dirtying or musical undo entries. Existing save/discard/cancel is preserved and app termination awaits input teardown. Verification schedules termination after leaving its MainActor task, avoiding a nested terminateLater loop holding that task.

See [INPUTS.md](INPUTS.md) for ownership, capacity, supported formats, timing and recovery details; [INPUT-ENGINE.md](INPUT-ENGINE.md) retains the shared DSP/MIDI contract. This phase does not implement mappings/MIDI learn, system-audio capture, production host feeding, presets or display management.

## Observed automated evidence

Environment: native arm64, macOS 27.2.1 (26B7131), Swift 6.4.2, full Xcode selected via DEVELOPER_DIR. Desktop remained locked (IOConsoleLocked = Yes). Test virtual sources were temporary and disposed. No microphone permission request or physical capture was made by verification; installed app/probe and the user's running app were not replaced/restarted.

| Check | Observed result |
| --- | --- |
| tools/test.sh | PASS, exit 0: 81 Swift Testing functions — 30 core, 17 actual Metal renderer fixtures, 5 existing bridge, 4 Signal numeric, 17 shared input, 8 device tests. No compiler warnings/errors in the final run. |
| Selection/channel fixtures | PASS: stable identity with changed native IDs, no fallback to an identically named source, duplicate-ID rejection, invalid/missing channels, bounded channel choices and off/unavailable/stale-configuration/shutdown policy. |
| Native audio enqueue fixture | PASS: actual C conversion/enqueue path matches all shared interleaved-reference signals for anti-phase stereo; preserves end timestamp, rejects nonfinite/fractional/out-of-range times, resets readiness on loss. This does not execute AudioUnitRender against hardware. |
| Actual Core MIDI callback | PASS: temporary protocol-1 virtual source enters the native input port and shared engine, delivers notes on the selected channel and filters another channel. Stop clears state and disposes the port; sending afterward does not restore held notes. |
| Actual virtual-source lifecycle | PASS: deleting a source clears a held note and reports Unavailable; recreating it with the same stable unique ID reconnects and accepts new notes. Physical hot-plug is still unperformed. |
| Thread Sanitizer | PASS, exit 0, all 8 device test functions including actual native callbacks/stop/unplug/reconnect. Initial run detected callback-context initialization publication races; explicit ready release/acquire handoffs fixed them. Final run has no Thread Sanitizer warnings and uses no suppressions. Audio hardware callbacks were not executed. |
| Signed debug app | ./build.sh --debug PASS, exit 0. build/VHS.app strict signature verification and Info.plist lint pass; microphone usage description included. No install/open of the user's running app. |
| Isolated app input self-test | build/VHS.app/Contents/MacOS/VHS --input-selftest PASS, exit 0: selections and transient values leave document/history unchanged, then clean asynchronous app termination. No device poll/permission/defaults writes in this mode. This does not test actual keyboard/menu or active-capture UI quit. |
| Layout fixtures | PASS: 84 measured layout files, 34–35 probes per file including internal input groups, in light/dark and forced increased-contrast appearances; nine input states with top/bottom scroll positions plus default/minimum/wide editor toolbar fixtures. Fixed the divider's one-point stack-gap violation. APP_LAYOUT_ONLY=1 explicitly skipped every PNG. Geometry is not native appearance/contrast/VoiceOver acceptance. |
| Signal/grid/C audit | tools/check-signal.sh and tools/grid-lint.sh pass. Native Objective-C/C adapter passes clang -fblocks -Wall -Wextra -Werror -fsyntax-only. Callback review found no app allocation, blocking lock, retry loop, disk, Swift/UI/render/GPU calls; bounded AudioUnitRender and queue operations remain. No measured callback deadline/latency claim. |
| VST3 regression | tools/test-vst3.sh PASS, exit 0: graph-state fixture and real processor/state tests; validator 47 passed / 0 failed; strict signing and arm64 check pass. Expected install_name_tool invalidation notices precede re-signing. No new Studio One session or shutdown acceptance. |
| Diff whitespace | git diff --check passes. |

Final logs and measured geometry are retained in [verification/phase5b/](verification/phase5b/). The generic GUI/output self-test and native screenshots were not substituted for the isolated input check; actual keyboard/menus/output/visual tests remain pending.

## Remaining acceptance

[Phase 4C](PHASE-4C-VERIFICATION.md#phase-5b-attended-acceptance-added-november-11) contains the attended checklist: real native popover appearance/position/focus/Escape, keyboard and VoiceOver, Bold Text/Reduce Motion/Increase Contrast, actual permission grant/deny/restriction/revocation, physical multi-channel audio and format/hot-plug/sleep recovery, hardware MIDI, active capture stop/quit and save/discard/cancel, preference recall without auto-start, actual input latency/resources and unchanged document/history/output behavior.

The prior Studio One quit-time failure remains unresolved; validator success does not change that failure. Actual macOS 26 compatibility, hardware performance/soak and production VST3 certification remain future gates. Phase 6 requires separate authorization.
