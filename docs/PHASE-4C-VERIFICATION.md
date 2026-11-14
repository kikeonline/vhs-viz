# Phase 4C — Attended desktop verification

Status: deferred by user on 2026-11-11 until direct computer access is available. Separate from implementation of Phase 5A/5B; later feature phases may append their attended checks here without erasing earlier evidence. Preserve PHASE-4-VERIFICATION.md, PHASE-4A-VERIFICATION.md and PHASE-4B-VERIFICATION.md as historical evidence; this file tracks remaining work, not replacement passes.

## Session prerequisites

An unlocked interactive desktop, Screen Recording and Accessibility access. VNC disconnect may explain rapid relocking; that cause has not been proven. Leave the connection open if using VNC. Keep-awake prevented idle sleep but did not prevent the observed relock. Restore temporary accessibility/appearance settings afterward and use disposable project/song copies.

## Outstanding acceptance

| Work | Current evidence / required follow-up |
| --- | --- |
| VoiceOver | Actual parameter, numeric validation, node/port announcements and keyboard traversal remain unverified. Utility AppleScript control was disabled; speech-copy attempts timed out. VoiceOver was turned off after testing. |
| Accessibility settings | Bold Text and Reduce Motion animation timing remain unverified. Real Increase Contrast and basic usability with Reduce Motion passed in the prior session. |
| File panels / visual review | Open/Save panel screenshots timed out; finish review of applicable uncovered states. 215 captures exist but only representative captures were individually reviewed. |
| Standalone output | Command-W did not close output. Reproduce, fix if required, and verify actual Edit menu availability, Command-Z/Shift-Command-Z, Show Output, close/reopen and Command-1. Other recorded output and edit checks already passed. |
| Host editor | Seed label wrapped as Se/ed. Command-A did not select the seed field; typing appended. Reproduce and correct applicable layout/focus behavior, then check actual host menus/shortcuts and keyboard/VoiceOver graph traversal. |
| Studio One shutdown | FAILED: four quit-time crashes. Two pre-quit maps resolve the failing PC to Studio One coreaudio.bundle +0x94f0; one session had no VHS image loaded. Underlying defect unresolved. Verify a clean baseline and relevant lifecycle paths before accepting host shutdown; do not assume VHS teardown caused it. |
| Hardware / minimum OS | Actual macOS 26 runtime, physical MIDI/controller routing, performance soak and external display acceptance remain future gates (#10 and respective feature phases), not completed by Phase 4C synthetic tests. |

## Evidence and safety of test data

See PHASE-4B-VERIFICATION.md and verification/phase4b/manual/ including sanitized crash summaries. The original Studio One probe song remains unchanged. A reboot removed the temporary disposable song, raw maps and older probe backup; retained map excerpts are in the summaries. The installed signed probe remains Phase 4B (UUID 7FC54F4D-2F8F-3ECE-9241-8D04BE796473). No product source fix was made during crash investigation.

Phase 4C is pending; no additional acceptance is claimed by moving this checklist.

## Phase 5B attended acceptance (added November 11)

Implementation/automated evidence is in PHASE-5B-VERIFICATION.md. These checks remain unperformed:

- Inspect the real Inputs toolbar popover and gallery fixtures in light/dark/increased contrast at default/minimum/wide window sizes, long input names and scroll positions. Check actual popover positioning, Escape/focus return, keyboard selection/Start/Stop and VoiceOver names, values and no-data vs silence. Exercise Bold Text and Reduce Motion; meter values must remain readable without color.
- From a signed app, grant, deny, restrict/revoke and re-grant microphone permission. Cancel a pending request via Stop; no late result may start capture. Check Open Microphone Settings and the usage description.
- Use a real microphone/interface, select mono/stereo channels including an interface with more than two channels, verify calibrated live meters and silence/clipping. Switch devices/rates/channel counts; unplug/reconnect, sleep/wake, no-data/error recovery and permission revocation while rendering. Record sample rate/buffer size/channel configuration and audio-to-meter latency/resources.
- Use hardware MIDI for notes, velocity-zero release, CC and channel/Omni filtering. Unplug while notes are held and reconnect the selected source. Virtual-source automated tests passed, but are not this hardware acceptance.
- Verify Stop, repeated Start/Stop, closing/reopening Inputs/control/output and application Quit with active inputs; save/discard/cancel must remain correct and no callback/port survives teardown. Recheck existing Edit menu, undo/redo and output shortcuts as a regression checklist; no new menu commands were introduced.
- Relaunch with saved local source/channel choices; selections remain local and capture stays off. Open/save a project while input is active: no device identity/live values enter the file or undo history. Confirm VST3 still has no standalone device/permission UI.

No new Studio One shutdown acceptance, macOS 26 compatibility, actual input latency/performance, or physical-device pass is implied by the headless fixtures.

## Phase 6 attended acceptance (added November 11)

Implementation and headless evidence are in PHASE-6-VERIFICATION.md. Live capture remains unperformed:

- From Inputs, select System Audio and choose app/display content in the real SCContentSharingPicker. Verify what source/mix is actually shared for browser and Studio One playback, with real meters, silence and pause/resume. Record OS, sharing mode and audio format. No production VST3 routing acceptance is implied.
- Test native picker presentation, cancellation, retry, permission denial/revocation/re-grant, Open Screen & Audio Settings and OS sharing indicators. Stop while picking/starting/capturing, then choose again. Confirm stale callbacks never restart a stopped session or replace a newer choice; no unsolicited share starts on launch/project/song recall.
- Change physical → system → physical while rendering/output is open. Confirm the old capture is released before the next source starts, no stale meter data or held inputs, and MIDI remains independent. Stop sharing from macOS, close the shared content, sleep/wake and terminate the stream; recovery stays inline and requires explicit retry.
- Review native Inputs layouts in light/dark/increased contrast, Bold Text and minimum/wide sizes; keyboard/VoiceOver/Escape/focus return around the OS picker. The fixture windows are geometry evidence, not screenshots of the native sharing picker.
- Verify actual idle/playback CPU/memory/latency, sustained streaming, sample/rate changes and repeated sharing start/stop, including Quit with capture active. The app registers only audio output, drops non-audio callbacks defensively, and writes no recordings; confirm resource release under the actual framework.
- Confirm standalone System Audio never requests microphone access, and VHS in Studio One still invokes no standalone capture picker or screen/audio permission. ScreenCaptureKit code is not a plug-in dependency.

No live sharing picker, ScreenCaptureKit stream, permission prompt or system-audio playback test was performed in the locked-desktop run. Prior Studio One shutdown failure and macOS 26 acceptance stay open.
