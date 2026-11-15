# Phase 4C — Attended desktop verification

Status: attended verification was authorized on 2026-11-15 with the Mac unlocked; session is in progress. It was previously deferred on 2026-11-11 until direct computer access was available. Separate from implementation of Phase 5A/5B; later feature phases may append their attended checks here without erasing earlier evidence. Preserve PHASE-4-VERIFICATION.md, PHASE-4A-VERIFICATION.md and PHASE-4B-VERIFICATION.md as historical evidence; this file tracks remaining work, not replacement passes.

## Session prerequisites

An unlocked interactive desktop, Screen Recording and Accessibility access. VNC disconnect may explain rapid relocking; that cause has not been proven. Leave the connection open if using VNC. Keep-awake prevented idle sleep but did not prevent the observed relock. Restore temporary accessibility/appearance settings afterward and use disposable project/song copies.

## Outstanding acceptance

| Work | Current evidence / required follow-up |
| --- | --- |
| VoiceOver | Actual parameter, numeric validation, node/port announcements and keyboard traversal remain unverified. Utility AppleScript control was disabled; speech-copy attempts timed out. VoiceOver was turned off after testing. |
| Accessibility settings | Bold Text and Reduce Motion animation timing remain unverified. Real Increase Contrast and basic usability with Reduce Motion passed in the prior session. |
| File panels / visual review | Open/Save panel screenshots timed out; finish review of applicable uncovered states. 215 captures exist but only representative captures were individually reviewed. |
| Standalone output | Resolved locally: Close Window/Command-W is exposed with key-window availability. Earlier actual foreground Command-W and the resumed full app self-test pass, including output close/reopen and scene preservation. Earlier native Edit-menu/undo/redo/Show Output/Command-1 evidence remains valid. |
| Host editor | Seed label wrapped as Se/ed. The shared seed group now retains its intrinsic horizontal size; build, embedding/state harness and all eight plug-in layouts pass. New visual/actual Studio One acceptance is still pending. Command-A/focus and keyboard/VoiceOver traversal remain unverified; no speculative shortcut fix was applied. |
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

## Phase 7 attended acceptance (added November 14)

Implementation and actual automated evidence are in PHASE-7-VERIFICATION.md. These checks remain unperformed:

- Inspect Mappings in standalone Chain/Nodes and the native host editor: light/dark/increased contrast, Bold Text, default/minimum/wide windows, long target names, empty/assigned/disabled/unavailable/waiting/no-input/candidate/conflict states, native popover placement and scrolling. Layout-only files do not certify appearance or readability.
- With keyboard and VoiceOver, select targets, enter valid/invalid contribution/curve/smoothing fields, Return/Escape, toggle enable/invert, Learn/Relearn/Confirm/Cancel/Replace Conflicts/Clear, dismiss the popover and verify focus returns correctly. Values/units/status must be spoken without frame-by-frame announcements.
- With physical audio and then actual System Audio playback, map all six analysis features to source/effect/graph targets. Verify ranges, inversion, curves and smoothing; stop/change/unplug/reconnect inputs and test no-data/silence. Base values, save data and undo must remain unchanged by live input. Record source/rate/channel configuration and actual latency/resource behavior.
- With a hardware MIDI controller, discover CC and notes, inspect channel/Omni, reject a filtered channel, confirm/cancel conflicts, clear/relearn and save/reopen. Check highest-note priority, note/velocity/gate release, velocity-zero note-on, all-notes-off and device loss without stuck modulation. Automated virtual-source delivery is separate evidence.
- In actual Studio One, use the proven hidden controller-assignment path and note bus. Start playback/live monitoring before Learn; identify/cancel chased candidates, confirm a live CC/note, save/quit/reopen the embedded definition in independent instances. The existing prototype supplies Peak + MIDI; production RMS/bands/transients, dynamic automation lanes and host undo acceptance remain Phase 8.
- After the new Window → Show Mappings command, observe actual Edit-menu enablement before/after a slider/mapping edit; Command-Z, Shift-Command-Z, Show Output, close/reopen output, and Command-1 from output. Dedicated mapping self-tests call model actions and are not menu/keyboard acceptance. Existing Studio One quit-time regression and all prior deferred acceptance remain open.

## Attended session — November 15 (in progress)

The user authorized verification and foreground input. [Session notes and evidence](verification/phase4c/2026-11-15/SESSION.md) distinguish actual observations from pending work.

- Studio One shutdown **failed again on a clean start page with no VHS image loaded**. The November 15 crash and pre-quit map match the host coreaudio.bundle +0x94f0 signature. The underlying host defect remains unresolved; no clean shutdown acceptance is claimed.
- Actual standalone Edit menu states, slider changes, Command-Z/Shift-Command-Z, Show Output, mouse close/reopen and Command-1 passed. Missing File Close/Command-W was reproduced; a source fix now exposes Close Window with window-aware availability, and actual foreground Command-W closes output. The initially pending automated close-shortcut self-test subsequently passed in the resumed session below; the fix and evidence are included in this progress checkpoint.
- Native Save As completed against a disposable /tmp project; it reopened with base values and mappings. The dark native panel was visually reviewed. Light panel and remaining file states are not yet accepted.
- The real microphone permission prompt, denial recovery message, Settings link, re-grant and required Quit & Reopen were exercised. Capture stayed Off on restart; explicit Start delivered built-in microphone samples at 44.1 kHz mono. Live meters and RMS mapping varied while the saved project/base value stayed unchanged. Stop reached Off. This does not accept external interfaces, calibrated levels, all formats or physical MIDI.
- Mapping numeric fields passed actual focus/select-all/invalid Return/Escape/valid Return/Undo checks. No VoiceOver speech or full keyboard traversal pass is claimed yet.
- System Audio reached the native picker. Its WindowManager overlay could not be accessed through either computer-use connection. The user has been asked to select Display/Entire Screen and Share; live system-audio capture/playback acceptance is pending that action. No stream success is inferred from the picker state.
- The 100-function unit/GPU/input regression suite, debug signed build, grid lint and Signal source checks pass. Native appearance/host/hardware gates remain separate.

No installed app or VST3 bundle has been replaced. Original song data is unchanged; a disposable host-song copy is prepared. Original local VHS preferences are backed up for restoration after this session. No phase is marked fully accepted by this partial session.

## Resumed session — November 15

Authorized by “continue phase 4c”. See the resumed section in [SESSION.md](verification/phase4c/2026-11-15/SESSION.md) and adjacent `*-resumed.log` files.

- The existing System Audio selection reported Cancelled rather than a confirmed stream. Escape dismissed Inputs and returned focus to Chain. No live system-audio acceptance is claimed.
- `tools/selftest.sh` now passes through `SELFTEST done`. The Close check recorded active=true, key=VHS Output, outputKey=true, enabled=true, then verified Command-W releases output without changing the scene; subsequent output, document, source, effects, graph, input and mapping regressions pass. The earlier failed close attempt was caused by its unusable focus context and is preserved as historical evidence.
- Fixed the recorded Seed label wrapping by retaining the shared seed label/field group's intrinsic horizontal size. Signed debug build passes. `tools/test-vst3.sh` passes real processor/state fixtures, validator **47/0**, bundle signature and arm64 checks. The installed app/plug-in and original song remain unchanged.
- The native visual embedding run could not make its first capture window key and exited with an explicit failure. `loginwindow` was reported as frontmost at that checkpoint; a later IORegistry read said IOConsoleLocked=No, so stable attended access is not established from either observation alone. No screenshots or physical-keyboard pass is inferred from background AX actions.
- The separate layout-only embedding run passes through `PLUGIN SELFTEST done`: mapping/learn/state/isolation/output lifecycle and all eight light/dark/contrast editor/graph layouts. This is harness/geometry evidence, not visual or Studio One acceptance. Grid lint, Signal specification checks and `git diff --check` pass.

Await stable unlocked desktop access and, for real sharing, the user's native sharing-picker selection. Physical hardware availability is also pending a user reply. VoiceOver, new native Seed rendering/select-all, sharing/playback, physical MIDI/interface, actual host lifecycle and all other unperformed gates stay open. The Studio One quit-time failure is unchanged; this resumed run did not repeat a known crashing quit.
