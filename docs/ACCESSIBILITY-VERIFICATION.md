# Issue 10 verification

Status: **3 of 5 checks passed; issue remains open.** Tested 2026-11-08 local / 2026-11-09 UTC on Apple M6 (Mac18,1), macOS 27.2 (26B7124), installed VHS release from Phase 2 (`4177469`). No app source changes were needed for the three completed checks.

## Keyboard-only RGB navigation and undo — passed

Enabled macOS Keyboard Navigation with Control-F7 (AppleKeyboardUIMode 0 → 2). Created a pristine Untitled project. Used Tab to reach Red, then Green and Blue, and Shift-Tab to traverse backward. Sliders were focused by keyboard only, not AXSetValue or programmatic focus. Right Arrow changed each native slider by 0.05.

- Red: 0.24 → 0.29 → 0.34. One Command-Z restored 0.29; another restored 0.24. Two Shift-Command-Z operations restored 0.34.
- Green: 0.08 → 0.13; undo restored 0.08 and redo restored 0.13.
- Blue: 0.62 → 0.67; undo restored 0.62 and redo restored 0.67.
- Shift-Tab returned Blue → Green → Red. Four undo operations restored all original values. Each discrete key adjustment has its own undo entry. Continuous mouse gestures remain covered by the existing unit/app tests.

The repeatable external check is [tools/accessibility-check.applescript](../tools/accessibility-check.applescript). It checks the focused AXSlider and its read-back numeric value after real key events, and refuses to replace an edited project. Requires System Events Accessibility access, Keyboard Navigation enabled, and the VHS control window. It takes foreground focus. Run with `osascript tools/accessibility-check.applescript`.

The passing transcript is [keyboard-menu.txt](verification/issue10/keyboard-menu.txt). The script leaves the scene at its original values, with redo available.

## Actual Edit-menu enablement — passed

System Events inspected the running app externally. At each checkpoint it opened the actual Edit menu and read the AX enabled state of Undo Color Change and Redo Color Change; Escape closed the menu. This does not infer menu state from model state or screenshots.

| State | Undo | Redo |
| --- | --- | --- |
| New clean project | Disabled | Disabled |
| Two Red keyboard edits | Enabled | Disabled |
| One undo | Enabled | Enabled |
| All undone | Disabled | Enabled |
| All redone | Enabled | Disabled |
| Original scene restored at end | Disabled | Enabled |

The same script and transcript record assertions for every row. The Orca provider still reports no menubar capability, but System Events successfully supplied the missing external inspection.

## Increase Contrast — passed

In System Settings → Accessibility → Display, Increase contrast was initially off. Enabled the real switch, confirmed AX Value 1 and `com.apple.universalaccess increaseContrast=1`, then ran `APP_SNAPSHOT=/tmp/VHS-contrast-shots tools/snap.sh -AppleShowScrollBars Always`.

Reviewed the control at default and minimum sizes in both light and dark appearances. Labels, component values, status, sliders, toolbar icon, and divider remained clear; no clipping. System secondary text and boundaries increased in contrast. Scene color remained content. The output fixture remained the scene only. Captures and four control layout measurements are in [verification/issue10](verification/issue10); all eight generated control/Rename layout measurements also passed the existing layout checker.

## VoiceOver — not verified

Started VoiceOver and inspected its first-use welcome UI. Attempted actual cursor navigation and `last phrase` announcement readback using the installed VoiceOver AppleScript dictionary. Temporarily enabled “Allow VoiceOver to be controlled with AppleScript” in VoiceOver Utility and verified the preference via its AX checkbox. VoiceOver announcement queries repeatedly timed out (`AppleEvent timed out`, -1712); cursor commands did not yield a verifiable reading sequence. A running VoiceOver process and an ordinary AX tree do not establish what VoiceOver announces. This check remains unchecked.

Preliminary AX inspection confirmed native AXSlider roles, values, bounds 0…1, and channel-specific descriptions. This is not an audit of VoiceOver spoken labels or reading order. The current AX tree omits the Metal surface itself; its preview/output description should be checked during the remaining VoiceOver pass.

Remaining procedure: with a working VoiceOver session, navigate the control window from its first item through preview/source/color controls and status, confirm each channel name/value and useful reading order, then Show Output and verify its accessible identity and return to Control with Command-1. Record actual announcements and fix any issues found. No VoiceOver pass is claimed here.

## macOS 26 — unavailable

This host is macOS 27.2. No macOS 26 VM/runtime was found in the local applications and searched VM/image locations. Xcode's available simulators are iOS 27.2, not macOS. A macOS 26 deployment target and successful runs on 27.2 do not prove macOS 26 compatibility.

Remaining procedure on an actual macOS 26 Mac/VM with full Xcode: build/install; run `tools/test.sh`, `tools/selftest.sh`, snapshots and layout checks; test project save/reopen and native commands; record OS/hardware/results. The user was asked whether such an environment is available; none has been provided. This task remains unchecked.

## Restoration

Restored Keyboard Navigation to its original AppleKeyboardUIMode 0 and Increase Contrast to 0. VoiceOver is stopped (no running VoiceOver process). Verified VoiceOver Utility's AppleScript control checkbox is back to its original 0; the welcome-dialog preference was unchanged. RGB scene edits were undone. No project files were overwritten or removed.

No release rebuild, core/GPU test rerun, or icon review was required: this work adds an external test script, evidence, and documentation, with no app implementation or asset changes.
