# Phase 4 — Ordered effects verification

Date: 2026-11-10. Authorized by “Implement next phase” after the code-backed phase overview. **Implementation and automated verification are complete. The user explicitly directed “Continue with automated checks only”; active-window visual and external keyboard/menu checks are deferred and remain unverified.** Phase 4A is not authorized or implemented.

## Implemented

- Transform, Blur, Pixelate, Threshold, Colorize and RGB Split as ordered Metal passes. See EFFECTS.md for coordinates, units, filtering, default values, color space and limits.
- Add/select/remove/bypass/move effects, repeated instances, generated numeric/color inspectors and native keyboard-focusable ordering buttons/context menus. Selection is transient UI state.
- Persistent UUID + local parameter key identity, structural undo/redo and grouped numeric gestures; source changes preserve the chain.
- Schema 3 effects; explicit schema 1/2 migration; strict malformed/bounds/type/count/UUID validation before document replacement.
- Per-renderer, instance-safe resources: three frame slots, at most two intermediate textures each, size-aware reuse, replacement of obsolete sizes and nonblocking saturation. No plug-in audio callback changes, live GPU waits or live readback.
- Dedicated app self-test and effect snapshots/layout probes. Default control height is 720 points; minimum remains 880×500. Preview reserves room for the effects section and maintains 16:9.

The feasibility VST3 editor/state remain deliberately limited to Solid/RGB recall. Shared renderer/core changes are available to future production integration; this phase does not expand the probe into a production effect/automation surface.

## Checks performed

| Check | Result |
| --- | --- |
| `./build.sh --debug --install` | Pass; Swift build without compiler warnings, locally ad-hoc signed VHS.app, copied to ~/Applications/VHS.app. |
| `tools/test.sh` | **25 core + 13 Metal GPU + 3 bridge tests pass** (41 tests; parameterized cases additional). |
| GPU fixtures | Analytic threshold/softness, pixelate cells, colorization, RGB offsets, transform translation/rotation/scale, constant preservation and spatial spread of blur. Order-sensitive blur/threshold chains differ. Fixed seed/time repeatability, all numeric/color boundaries, opaque output, all-bypassed identity and 16-effect chain pass. |
| Migration fixtures | Schema 2 → 3 preserves actual GPU pixels for all five sources. Core checks cover schema 1, complete settings/IDs/order round trip, strict rejection of malformed effects, invalid actions and chain limits. |
| Resource fixtures | Resize/long-chain edits retain at most six scratch textures; repeated single-size and alternating two-size rendering stops reallocating. Three simultaneous leased slots exhaust safely and become available after release. These are pool tests, not whole-process memory/performance certification. |
| `tools/selftest.sh` | Pass, including all previous app/project/source checks and new effect actions, grouped edit undo/redo, repeated instances, identity/selection, save/reopen, malformed-file preservation, 12 live resize/chain edits and matching preview/output snapshots. Ends `SELFTEST done`. |
| `tools/test-vst3.sh` | Actual processor fixtures pass; Steinberg validator **47 passed, 0 failed**; packaged bundle signature verifies; native arm64 binary. No new Studio One manual certification is claimed. |
| `tools/grid-lint.sh` | Pass. |
| `APP_LAYOUT_ONLY=1 APP_SNAPSHOT_PAGES=effects … tools/snap.sh` + layout checker | Pass for 24 effect inspectors (six types × default/minimum × light/dark), plus two repeated/bypassed chain layouts. Image capture is explicitly skipped in this mode. |
| `git diff --check` | Pass. |

Logs and final effect layout measurements are in `docs/verification/phase4/`. Full VST3 validator output was generated at `/tmp/VHS-phase4-vst3.log`; the retained summary includes the processor assertion result, validator totals and architecture. Prior phase evidence is untouched.

## Deferred observed checks (user direction)

The initial capture attempts failed while the display was unavailable. Waking it allowed some images, but the windows were inactive. Those images are **not reviewed acceptance evidence**. `Verification.capture` now rejects any non-active/non-key window (or a parent without a key attached sheet). Computer Use also reported `cgWindowNotFound`; Orca could not obtain the VHS accessibility window. No permission setting was changed. The user was asked to make the desktop available; independent code/tests continued.

The user’s automated-only direction overrides the build-and-verify skill’s requirement to review active-window snapshots before completion. No additional desktop access or confirmation is required for this delivery. Deferred checks may be performed later if requested:

On an unlocked available desktop:

1. Run `caffeinate -disu env APP_SNAPSHOT_PAGES=effects APP_SNAPSHOT=/tmp/VHS-phase4-shots tools/snap.sh -AppleShowScrollBars Always`. Review every default/minimum light/dark inspector, chain and effect output; verify active traffic lights, legibility, focus, scrolling and clipping. Run the layout checker against those captures.
2. Use the actual UI to add repeated effects, select rows, adjust sliders/colors, bypass, move up/down with Tab/Space, remove and undo. Confirm focus and accessibility labels and inspector scrolling at minimum size.
3. Observe external Edit-menu enablement before/after an effect slider edit, Command-Z/Shift-Command-Z, Show Output, output close/reopen and Command-1 from output. Existing app self-tests exercise these command actions, but do not prove external menu enablement. AppCommands declarations were not changed.
4. Record any later visual/layout/keyboard fixes and observed results without treating this automated-only delivery as proof of those checks. The current build is already installed at ~/Applications/VHS.app.

VoiceOver and actual macOS 26 verification remain open under #10. Performance/soak measurements, production host automation, production MIDI learn, full host scene recall, external-display hardware and notarization remain later milestones; none are counted as performed here.
