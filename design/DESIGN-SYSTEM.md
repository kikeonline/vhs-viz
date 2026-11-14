# VHS design system

VHS / Signal was approved on 2026-11-10. [KIT.md](KIT.md) and [tokens.json](tokens.json) specify the design; the [HTML sheet](vhs-design-system.html) is a visual reference. Phase 4B implements the native baseline for current features. Every later UI-bearing phase uses it automatically. Actual visual, keyboard, VoiceOver and Studio One acceptance remains deferred under the user's automated-only direction; see [Phase 4B evidence](../docs/PHASE-4B-VERIFICATION.md).

## Shared native module

`Sources/VHSSignal` is imported by standalone, VHSGraphUI and VHSPluginUI. It has no app/runtime dependency or mutable theme singleton. Scene colors remain content; performance output is an unstyled Metal surface. System menus, alerts, file/color panels, window chrome and host ownership stay native.

The approved JSON is bundled unchanged at `Resources/tokens.json`. `tools/check-signal.sh` detects copy drift. Update both copies together. Runtime semantic colors, spacing, specified layout metrics, radii and type sizes read this data. Do not create another palette or spacing scale. `Resources.swift` resolves the plug-in's adjacent resource bundle independently of a DAW's Bundle.main; command-line development uses SwiftPM resources.

| Specification | Native API | Use |
| --- | --- | --- |
| themes.*.canvas/surface/raised/hover | Ink.canvas/surface/raised/hover | Workspace, inspector/rows, inputs/actions, pointer states |
| text/secondary/muted/divider/controlBorder | Ink.text/secondary/muted/divider/border | Text hierarchy, decorative divider, essential boundary |
| accent/focus | Ink.accent | Dynamic Mac accent override; Signal for Multicolor, active selection/focus |
| selection/error and graph image/scalar/vector | Ink.selection/error; Ink.color(type role) | State fill, invalid fields, typed wires/port glyphs |
| space | Space | Existing 4/8/12/16/20/24/32 scale; margin aliases xl |
| metric | Metric and Layout | Control/row/parameter/focus; editor and graph geometry |
| radius | Radius; Layout.previewRadius | Controls/nodes, panels, aspect-preserving preview |
| type | KitType | System title/section/body/label/meta and tabular value fonts |
| motion | Motion.hover/disclosure | Named easing; Reduce Motion returns no animation |
| icon vocabulary | KitIcon | SF Symbols for commands, status and typed ports |

`Layout` also retains named legacy renderer/editor dimensions absent from the specification (seed field, graph pan step, library size, preview reservation). These are layout contracts, not a second design scale. No raw colors, fonts, radii or durations belong in feature views. `Grid.swift` now lives in this shared module; its opt-in diagnostic registry is not product scene state.

## Controls and states

`signalTheme()` applies semantic text, native control tint, button style, canvas and Bold Text handling. `SignalButtonStyle` retains native Button behavior and supplies hover/pressed/disabled/inactive appearance plus additive keyboard focus. `SignalCanvasButtonStyle` preserves compact node/port geometry. `signalRow` supplies hover, selection fill/leading rule, inactive selection and accessibility selection traits. Native toggles, pickers, text fields and color panels retain system semantics.

`NumericParameter` is the generated source/effect/node and prototype RGB control. It pairs a native slider with a trailing exact-value field and separate unit. Sliders use registry precision for step size; symmetric signed ranges include a neutral tick. Return validates the complete finite number against registry bounds (whole numbers for seeds); invalid drafts remain visible with an inline explanation. Escape discards the draft. Leaving an uncommitted field does not edit the scene. Context-menu Reset restores the registry default. A continuous gesture begins/ends one edit; exact commit/reset is one action, with no-op history suppressed by the existing reducer. Host exact edits retain begin/value/end automation brackets.

The compact editor retains 20pt margins, a 280pt inspector and effects below preview at default/minimum/wide sizes. Inspector and effect list scroll independently. The optional wide chain rail is not used. Bypass stays explicit and editable; ordering/removal remain native keyboard-focusable commands. Source/effect summaries are help, not permanent inspector prose. Graph wires use type colors, glyphs and text, and native picker wiring remains available.

## Gallery and verification

`APP_KIT_GALLERY=1` opens the native gallery in the editor. Snapshot mode also captures each forced state separately: rest, hover, pressed, selected, focused, disabled, inactive, error and bypassed. `APP_SNAPSHOT_PAGES=signal` runs gallery and long-name/16-effect default/minimum/wide fixtures in all four appearance/contrast variants. Normal snapshots additionally cover all sources/effects, inspector bottoms, graph errors/library and native document dialogs. Use `APP_LAYOUT_ONLY=1` while the automated-only direction applies; it produces measured layout evidence and explicitly skips PNGs.

Run `tools/check-signal.sh`, `tools/grid-lint.sh`, the Swift layout checker, relevant regression suites and the shared editor harness. Layout data cannot prove appearance, actual keyboard behavior, contrast perception or assistive-technology announcements. Preserve outstanding acceptance in the phase verification record.

## Phase 7 mappings

The shared `MappingEditor` in VHSGraphUI reuses Signal type/color/spacing, native pickers/toggles/buttons and NumericDraft validation. The 480×560 scrollable popover metrics are `Layout.mappingWidth`/`mappingHeight`, following the existing native overlay metric convention; its contents remain accessible at minimum/wide editor sizes. Mapping contributions use exact native-unit fields with Return/invalid feedback/Escape, without an unhelpfully large-range slider. Live effective-value text uses tabular value type and no implicit animation. Native appearance/keyboard/VoiceOver acceptance is tracked separately from layout probes.
