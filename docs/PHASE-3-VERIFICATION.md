# Phase 3 verification

All procedural sources is functionally complete. Verified 2026-11-08 local / 2026-11-09 UTC on Apple M6 (Mac18,1), macOS 27.2, Xcode 27.2. The release app is installed at `~/Applications/VHS.app`. Phase 4 has not started.

## Result

Solid, Linear/Radial Gradient, Smooth/Cells seeded Noise, Sine/Triangle/Square Oscillator, and Circle/3:2 Rectangle/Triangle Shape render through the shared Metal pipeline. The source registry owns stable IDs, typed defaults, bounds, choices, precision and conditional control availability. The inspector generates sliders, native color pickers, choices, toggles and an exact UInt32 seed field. Source changes retain inactive settings and support undo; numeric drags remain grouped. Animate uses the common clock without changing saved state or history.

Project schema 2 stores the selected source, all source settings and seed. Schema 1 Solid documents migrate while preserving identity/name/color/seed. Malformed typed parameters, missing/unknown keys, invalid choices/ranges, and future versions are rejected. See [SOURCES.md](SOURCES.md) and [PROJECT-FORMAT.md](PROJECT-FORMAT.md).

## Automated checks

- `./build.sh --install`: release build, signing and install passed with zero compiler warnings.
- `tools/test.sh`: **22 core and 9 renderer test functions passed**, including parameterized cases. Core covers registry/default completeness, type/range constraints, inactive settings, source/gesture undo, all parameter types, save round trips, schema 1 migration, malformed current files, and existing atomic-save fault tests.
- Actual Metal tests cover fixed seed/time repetition for all sources, analytic sRGB gradient samples/reversal/radial center, seed and interpolation variation, animated/frozen noise, all oscillator waveforms/time periods/freeze, shape variants/outline/non-square aspect, and parameter extremes at long times. The renderer suite also asserts the Swift/MSL 112-byte uniform layout. Analytic channel checks use one code-value tolerance; cross-device bit identity is not claimed.
- `tools/selftest.sh` passed through `SELFTEST done`. Existing command routing, document replacement, native close, output lifecycle and menu-refresh regressions remain green. Added checks exercise each source's typed edits and undo/redo, Save/Open and fresh history, actual live preview/output drawable progression, both views drawing the same restored scene, and animation producing no dirty/history entries. Native color conversion checks sRGB 0.5 → linear 0.21404114 and a linear-color round trip.
- Final snapshot run captured **56 PNGs**: each source in light/dark at default/minimum sizes, scrolled inspector bottoms, five source outputs, native RGB color panels, and project/dialog regressions. Reviewed all affected surfaces. Long inspectors scroll; Source stays available. Fine values show three decimals. Controls that do not apply are disabled while retaining their values. No unintended clipping or alignment defects found.
- `tools/grid-lint.sh` and all **36 layout captures** passed. Source probe counts: Solid 17/7 areas; Gradient 21/7; Noise 22/7; Oscillator 24/8; Shape 30/10. Native color/file panel internals use system layout.
- `git diff --check` passed.

## External native interaction checks

Used Orca Computer Use plus System Events where native popup menus/floating panels were outside the provider's menu inventory. Inspected fresh AX values, actual window transitions, rendered pixels, and saved JSON; synthetic input delivery alone was not treated as a pass.

1. Opened the real Source picker and observed all five choices. Selected Gradient; its generated controls appeared. Changed its Style to Radial.
2. Opened Start color's native panel, selected RGB Sliders, entered Hex `4080C0`, and committed the focused field. The color well read back sRGB 0.25098/0.501961/0.752941. Undo restored the previous color; redo restored the edit. Saved JSON held linear RGB 0.0512694567/0.2158605158/0.5271151662, matching the color conversion.
3. Selected Noise → Cells; entered and committed seed 42. Selected Oscillator → Square and turned Animate off. Selected Shape → Triangle and Outline. Source selection undo returned to Oscillator and redo restored Shape.
4. Show Output rendered the outlined triangle. Closing/reopening output retained the scene. Command-1 from output restored control focus, verified through AXFocusedWindow. Repeated these lifecycle checks against the final release.
5. Saved through the native Save panel to an owned temporary `Native Sources.vhsproject`; title/status became Native Sources/Saved. Inspected the JSON: schema 2, selected Noise/Cells, seed 42, and inactive Radial/color, Square/frozen oscillator, and Triangle/outline settings retained.
6. Quit and opened that project through LaunchServices in a **fresh process**. Correct Noise/Cells controls, seed 42, Saved state, and rendered preview returned. [Native restart capture](verification/phase3/native-restart.png) and the saved sample are included.
7. Opened the existing Phase 2 schema 1 fixture through a native file event. It displayed Solid, RGB 0.44/0.08/0.62, filename title and Saved state. The fixture was not overwritten. Unit tests separately verify migrated identity and UInt32 seed preservation and schema 2 re-encoding.
8. Final metadata UI checks: Radial disabled Angle; frozen Noise disabled Speed. Restored inactive Shape showed Softness 0.005 and Outline width 0.020; turning Outline off disabled its width, undo restored it. Undid test edits and returned to saved Noise.
9. Ran the external `tools/accessibility-check.applescript` against the final release with temporary Keyboard Navigation enabled. All RGB Tab/Shift-Tab, arrow adjustment, Command-Z/Shift-Command-Z and real Edit-menu enabled-state assertions passed with the new Undo/Redo Scene Change titles. Clean false/false; edited true/false; one undo true/true; all undone false/true; all redone true/false. Restored Keyboard Navigation to its original mode 0.

## Capture environment and remaining limits

An early capture attempt failed after the Mac locked. `CGSSessionScreenIsLocked=1` confirmed the cause; unrelated apps' AX windows were also unavailable. No permission bypass was attempted. After the Mac was unlocked, final captures and native checks passed. The snapshot script now activates its exact PID through System Events instead of selecting another installed/test copy by bundle ID. It needs an unlocked GUI, Screen Recording and System Events Accessibility access.

VoiceOver announcements/navigation and an actual macOS 26 runtime remain unverified in GitHub #10; this phase does not mark them passed. Full keyboard-only traversal of the native color panel/all generated choice flows was not audited; the external keyboard regression covers RGB sliders, while source/variant/color/seed interaction was verified with native AX plus keyboard input. Increase Contrast was previously reviewed in #10; a fresh Increase Contrast audit for every new source is not claimed here. Icons were unchanged and were not re-reviewed. No long-duration performance, 4K, hardware-audio or external-projector claims are made.

Evidence, full passing logs, saved sample, native captures and layout measurements are in [verification/phase3](verification/phase3). Source/evidence remain local until explicitly published; GitHub task updates include a self-contained summary.
