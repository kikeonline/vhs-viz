# Phase 7 — Persisted audio/MIDI mappings and MIDI learn

Authorized on 2026-11-14 by “continue with next phase”. Implementation and available automated verification pass. Physical/system-audio, actual Studio One, native visual/keyboard/menu/VoiceOver acceptance remain deferred under the existing direction in [Phase 4C](PHASE-4C-VERIFICATION.md#phase-7-attended-acceptance-added-november-14). Production host sample analysis/automation/transport remains Phase 8. Phase 7A presets is next and requires separate authorization. Parent Phase 5 and prior desktop acceptance are still incomplete.

## Implemented

Schema 5 stores up to 128 stable UUID/parameter-key mapping definitions and sync choice in the immutable scene. Versions 1–4 migrate explicitly; malformed current definitions reject before replacement. Mapping edits use the reducer/history, preserving definitions through source/effect/graph edits, reorder, undo/redo and project/embedded host-state round trips. Unknown/deleted/connected targets remain visibly unavailable and never silently retarget.

The per-instance evaluator combines normalized RMS/Peak/Low/Mid/High/Transient, MIDI note/gate/velocity and CC into native-unit contributions. Range/inversion/curve, deterministic composition, monotonic frame-independent smoothing, highest-held-note priority/release, channel/Omni, controller reset and input-loss semantics are specified in [MAPPINGS.md](MAPPINGS.md). Effective values never overwrite base controls, dirty a document or append history. Preview/output share the same effective frame. Input switching clears contributions immediately and rejects stale audio/MIDI revision polls.

Standalone and the existing VST3 editor share Signal Mappings: target/input/channel/number, exact contribution/curve/smoothing fields, enable/invert, effective-value feedback and unavailable state. Learn/Relearn waits for CC/nonzero note-on, shows the actual detected channel/number, requires confirmation, supports Cancel/Clear/manual recovery, and requires explicit conflict replacement. Waiting and no-input are distinct. Numeric fields reuse NumericDraft validation, Return and Escape with inline errors. Native interactions/accessibility are implemented but not attended-certified.

Host CC discovery uses the Phase 3A fixed IMidiMapping bank and note bus. The temporary Learn Blue and implicit prototype offsets are replaced with explicit persisted definitions; empty mappings render base values. The native host harness exercises confirmed definitions/recall/isolation, without opening capture devices. The existing host adapter supplies Peak + MIDI; its RMS/bands/transient choices are disabled until the production sample handoff in Phase 8. Shared synthetic analysis fixtures cover all six features. The bounded 256-slot dynamic host automation contract is specified for Phase 8, without prematurely exposing new host parameters.

Arbitrary graph numeric values now use a bounded Metal uniform bank. Pipelines accept validated numeric changes while rejecting different topology, node order/kinds/identity, bypass or nonnumeric values. Live modulation does not request compilation; an invalid subsequent graph retains the prior effective values with its clock running. No callback code, capture permissions, audio pass-through, synchronous live GPU readback or GPU wait was introduced.

## Observed automated evidence

Environment: native arm64, macOS 27.2.1 (26B7131), Apple Swift 6.4.2, full Xcode selected by build/test tools. No physical audio, actual system-audio stream, MIDI hardware, permission prompt or Studio One session was exercised.

| Check | Actual result |
| --- | --- |
| `tools/test.sh` | PASS, exit 0: 100 Swift Testing functions: 38 core, 19 actual Metal fixtures, 19 shared input, 15 device/system in two suites, 5 bridge, 4 Signal. No compiler warnings/errors. |
| Mapping rules/persistence | PASS: additive composition/clamp-once, inversion/curve/range, disabled/invalid inputs, 60/144 Hz smoothing equivalence/release, highest note/channel/Omni, target reorder/delete/source switch, definition undo/redo, schema-4 migration and schema-5 round trip, invalid definition rejection, CC/note learn and explicit conflicts. |
| Shared input/device feed | PASS: normalized host-event and decoded MIDI byte fixtures agree; CC121/all-notes-off/filter/reset semantics; all six shared analysis outputs. Existing actual Core MIDI virtual-source service fixture additionally proves mapping gate state and Stop clearing. This is not MIDI hardware acceptance. |
| Actual GPU fixtures | PASS: one compiled branching graph responds to live scalar/source/effect numeric values, matches separately compiled effective output and returns to base on input release. RenderSession retains ready status across mapped frames and keeps prior effective values when a later graph fails. Existing source/effect/migration/resource/last-valid regressions pass. |
| Signed standalone build | `./build.sh --debug` PASS, exit 0; strict signature verification and Info.plist lint pass. Local `build/VHS.app` only; installed app was not replaced. |
| Mapping app self-test | PASS, exit 0, `--mapping-selftest`: common effective frame, unchanged base/history, definition undo/redo, CC/note learn/filter/cancel/confirm, file round trip, release. Calls real model actions on ephemeral state; no menu shortcuts or physical inputs are tested. |
| Input app regression | PASS, exit 0, `--input-selftest`: physical/MIDI/System Audio selections and transient state leave the document/history unchanged in isolated mode. |
| Mapping geometry | PASS: 84 layout-only files — nine empty/assigned/waiting/no-input/candidate/conflict/unavailable/disabled/host cases, top/bottom scroll positions, four appearance/contrast variants, plus default/minimum/wide toolbar layouts. Final live feedback uses a semantic minimum height after geometry caught an off-grid gap. No PNGs or visual review claimed. |
| Native plug-in harness | PASS, exit 0: shared CC/note learner, live frame without base/history changes, mapping definitions embedded/restored, undo/redo, two-instance isolation and output/editor teardown. Eight editor/graph appearance/contrast layout files pass; screenshots explicitly skipped. This is an embedding harness, not a new Studio One test. |
| VST3 regression | `tools/test-vst3.sh` PASS, exit 0: schema-5 graph+mapping fixture, actual processor/state tests, SDK validator 47 passed / 0 failed, strict signature and arm64 check. Expected install_name_tool signature warnings precede re-signing. Plug-in adapter callbacks/audio pass-through are unchanged. |
| Source/style checks | `tools/grid-lint.sh`, `tools/check-signal.sh`, `git diff --check` PASS. VST3 dylib links Accelerate through the shared input module, with no capture-device or ScreenCaptureKit dependency. |

Final logs and 92 raw geometry files are retained in [verification/phase7/](verification/phase7/). Layout data is not native appearance, actual contrast, focus, accessibility or hardware evidence. The initial GPU guard failure and live-feedback grid gap were corrected before the final passing runs. The new last-valid fixture initially removed an optional parameter connection, producing a valid chain; it now removes the required image source and exercises an actual compile-validation failure.

## Deferred acceptance and limits

Phase 4C retains actual source capture/playback and controller learn, permission/device loss/reconnect, Studio One chase/monitoring/song workflows, native popover/light/dark/contrast/Bold Text/scrolling review, keyboard/VoiceOver/focus behavior and performance/latency observation. No image captures, actual Edit-menu enablement, Command-Z/Shift-Command-Z, Show Output shortcuts, output close/reopen keyboard flow or Command-1 were manually checked after adding Show Mappings. Dedicated model tests do not substitute for these checks. Prior Studio One quit-time regression and macOS 26 verification remain open.

Host dynamic automation slots, production RMS/band/transient delivery, tempo/transport and full host undo/song acceptance belong to Phase 8; presets belong to Phase 7A. No release or production VST3 certification is claimed.
