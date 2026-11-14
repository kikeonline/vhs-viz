# VHS / Signal design kit

Version 0.1 · Approved by the user on 2026-11-10 · Design specification for future UI work.

**Precise. Restrained. Electric.** A quiet instrument panel around a vivid visual canvas. Start with the [visual reference sheet](vhs-design-system.html), [research](research/DAW-AND-PLUGIN-UI.md) and [machine-readable tokens](tokens.json).

This approved specification defines the design direction; it does not represent a runtime theme or authorize unfinished product milestones. Existing source tokens and native controls remain authoritative until migrated. The reference sheet illustrates interaction and anatomy; it is not the SwiftUI implementation. Graphs, presets, mappings, host sync and external-display management are future/ongoing design patterns and require their own implementation verification.

## 1. Foundations

The preview is the primary content. Source and effect controls are the secondary layer. Project, output and performance status remain at the perimeter. Each surface has a job; use dividers and spacing before adding a container. Keep gradients, glow, distortion and scanlines inside rendered content. No glass over the preview, fake hardware, dashboard cards, oversized headers, permanent inspector prose or decorative meters.

### Color architecture

Three layers: raw palette → semantic meanings → component states. `tokens.json` is the specification source for sample values. Future Swift code should expose semantic `Ink`, `Metric`, `KitType`, `Radius` and `Motion` roles; views must not read raw palette values. Do not add duplicate spacing definitions: retain the existing `Space` scale.

| Meaning | Dark | Light | Use |
| --- | --- | --- | --- |
| canvas | #141719 | #E9ECE8 | Workspace backing, canvas gutter |
| surface | #1C2023 | #F5F7F2 | Inspector, chain, toolbar |
| raised | #262B2E | #FFFFFF | Fields, popovers, unselected buttons |
| hover | #30373B | #DFE5DA | Pointer highlight |
| text | #F1F3EE | #1B211B | Labels, current values |
| secondary | #ADB6BB | #4F5B52 | Descriptions, units |
| muted | #99A4AA | #5A665C | Nonessential metadata, still readable |
| divider | #3B4348 | #C4CDC3 | Decorative rules only |
| controlBorder | #77858D | #768375 | Essential control boundaries |
| accent / accentText | #D5F36B | #476000 | Primary action, selected indicator, focus |
| onAccent | #172006 | #FFFFFF | Label on accent-filled button |
| selection | #303B1D | #E0EAC9 | Selected row background |
| success | #7ED9AD | #216744 | Connected / healthy, with label |
| warning | #F2C66D | #795000 | Recoverable issue, with icon and text |
| error | #FF9D95 | #A32D26 | Failed operation / invalid entry |

Light and dark increased-contrast values are fully specified in JSON. The default appearance follows macOS. The reference sheet's explicit appearance controls are for comparison, not proposed product settings. In production use semantic native labels/backgrounds for system-owned surfaces and named adaptive colors for custom surfaces. Do not freeze native alert, menu, file panel or color picker appearance to these hex values.

**Accent policy:** follow the Mac accent by default. Signal chartreuse is the approved brand option when the Mac uses Multicolor or when the person explicitly selects the brand accent. An explicit macOS accent choice wins. Resolve selection/focus/button foreground contrast for every supported accent; do not assume all accents can use the chartreuse foreground. Scene RGB and color swatches are document content, never chrome theme inputs. Status colors and graph type colors are semantic and independent of accent.

### Geometry

| Role | Value (pt) | Rationale |
| --- | --- | --- |
| Spacing | 4 / 8 / 12 / 16 / 20 / 24 / 32 | Reuses `Space.swift`; 20pt content margins |
| Control / small control | 32 / 28 high | Compact desktop targets with legible labels |
| Icon / hit area | 16 / 32 | Distinguishes visual size from click target |
| Parameter group | 60 minimum high | Label/value line, 8 gap, slider target |
| Effect row | 44 minimum high | Name, order and independent bypass target |
| Radius: controls / rows | 4 / 4 | Crisp instrument silhouette |
| Radius: panels / preview | 8 / 8 | Preserves existing preview radius |
| Toolbar / status | 48 / 28 high | Stable perimeter without excessive chrome |
| Inspector | 280 wide | Matches existing app; can grow with text needs |
| Optional wide chain rail | 216 wide | Only at ≥1200pt window width |
| Focus | 2 stroke, 2 offset | Outside bounds; never clipped |
| Graph node | 200 wide; 32 header; 24 port row | Matches graph layout tokens; hit target can exceed port glyph |

Use 1pt rules aligned to the backing scale, not an assumed one-device-pixel stroke. Control boundary tokens meet a stronger contrast requirement than decorative dividers. Pills are reserved for concise status tags; routine buttons remain rectangular. No shadows in the base workspace; native overlays own their elevation.

### Typography and icons

| Role | System font size / weight | Use |
| --- | --- | --- |
| title | 20 / semibold | Sheet titles, not repeated inside every panel |
| section | 13 / semibold | Inspector/module headings |
| body | 13 / regular | Explanations and normal rows |
| label | 12 / medium | Parameter labels, controls |
| meta | 11 / regular | Timing, resolution, shortcut hints |
| value | 12 / medium, tabular digits | Numeric fields and meters |

Use SF Pro via system font APIs; use monospaced digits rather than monospacing every label. SF Mono is acceptable for explicit IDs, shader diagnostics and code. The reference sheet uses platform font fallbacks. Presentation-only 40pt headings must not enter the app inspector. Uppercase is limited to short section eyebrows; ordinary controls use sentence case. Honor Bold Text and enlarged text; row heights are minima, and labels can wrap.

Icons: semantic `KitIcon` names backed by SF Symbols, regular weight, 16pt, consistent optical bounds. Suggested mappings: source `waveform`, effects `slider.horizontal.3`, graph `point.3.connected.trianglepath.dotted`, output `rectangle.on.rectangle`, bypass `power`, warning `exclamationmark.triangle`, error `exclamationmark.circle`. Verify symbol availability on macOS 26. No emoji as app icons. Every icon-only control has a label, tooltip and 32pt target. Native traffic lights, menus, sheets and window interactions remain native.

### Motion

`hover` 80ms ease-out; `selection` immediate; `disclosure` 120ms ease-out; tooltip delay 600ms. Reduce Motion sets decorative durations to zero. No perpetual status pulse, moving selected rows or animated numeric units. Live rendering follows the engine clock; UI easing must not smooth parameter values behind the user's hand. UI motion preferences do not silently alter the artwork.

## 2. Layout recipes

**Compact chain editor:** default 1000×720, minimum 880×500. Keep 20pt outer margins and a 280pt inspector. Preview occupies the flexible left region; source and ordered effects sit below it and can scroll. Preserve the preview aspect ratio with neutral letterboxing. Inspector scrolls independently; source/effect selection stays reachable. Do not squeeze or scale all UI to fit. Output access stays in the toolbar.

**Wide chain editor:** at ≥1200pt, optionally put the 216pt ordered chain rail left of the preview and retain the 280pt inspector right. At 1440pt this leaves approximately 824pt for preview after margins and two 20pt gaps. Rails remain fixed while the preview grows. Avoid an empty permanent library sidebar.

**Graph editor:** respects the existing 1000×640 graph minimum. Canvas is the main workspace, inspector 280pt, optional small preview 240pt. Node library opens on demand. Pan/zoom applies to graph content, never to inspector labels. Fit selection and keyboard add/connect/remove must be available through named commands. Selecting a node reveals its parameters without opening a modal editor. A type-incompatible connection is rejected with a local explanation. Preserve a valid image while compilation fails.

**Preset browser (planned):** a temporary browser replaces part of the workspace, with Factory/User scope, search, named thumbnail rows and explicit load/save actions. Previewing is opt-in; avoid surprising live output changes on arrow-key navigation. Protect unsaved edits. Keep device/display identity and transient levels out of portable presets.

**Performance output:** only the rendered image. No logo, FPS counter, cursor hints, error badges, source names or editor controls. Output window closure does not close the project. External display disconnect recovery belongs in the editor when that feature ships.

**Plug-in:** same component family inside a host-owned window. Do not draw standalone traffic lights, project path chrome, physical audio-device pickers or microphone permission prompts. Show “Host audio”, “Host MIDI” and “Host tempo” only when real host data is available; distinguish stopped, unavailable and disconnected. Automation comes from the host; no fake transport buttons that imply control of the DAW. Song recall is per instance. Closing the editor must not imply the output stops.

## 3. Shared state contract

All interactive parts must cover rest, hover, pressed, selected/on, keyboard focus, disabled and window-inactive states in both appearances and increased contrast. Focus is additive: a selected row can also have a focus ring. Error is additive to editable fields. Distinguish disabled controls (no activation) from bypassed effects (still editable).

| State | Fill / border | Text / behavior |
| --- | --- | --- |
| Rest | raised / controlBorder for inputs; surface for rows | text; stable geometry |
| Hover | hover; preserve essential border | text; no selection or value change |
| Pressed | selection / accent boundary | text; no movement or scale effect |
| Selected / on | selection + 2pt accent leading rule, or accent fill for primary action | text or onAccent; programmatic selected state |
| Focus | rest/selected + 2pt focus outer ring | visible without hover; never clipped |
| Disabled | surface / divider | muted + native disabled semantics; explanatory help when useful |
| Inactive window | surface, neutral leading rule | keep selected identity; suppress bright active accent |
| Invalid | normal field + error boundary and error message | preserve typed text until corrected/cancelled |

Do not communicate bypass, error, modulation or port compatibility through color alone. Disabled controls should not be made unreadable by a blanket opacity multiplier.

## 4. Component contracts

| Part | Anatomy and metrics | Additional states / interaction |
| --- | --- | --- |
| Toolbar | 48pt, project name + Edited, contextual status, Show Output at trailing edge | Native button, shortcut Shift-Command-O. Output “Open” is distinct from external display “Connected”. Preserve filename/dirty semantics. |
| Action button | 32pt high; 12pt horizontal inset; 4pt radius; optional 16pt icon + 8pt gap | One accent-filled action per local group. Pressed uses selection with text foreground; focus independent. Destructive action is text/error until confirmation is required by actual data loss. |
| Segmented view control | 32pt, 4pt radius, equal segments and visible group boundary | Selected segment uses selection + accent indicator; arrows move selection; no new product tabs before features exist. |
| Effect row | 44pt minimum; order 24pt, name flexible, bypass target 32pt | Selecting edits inspector. Independent “Bypass [effect] [order]” toggle, “Bypassed” text and dashed/struck order mark. Selected+bypassed remains readable. Reorder via visible Move Up/Down commands, drag optional. Remove is undoable; do not hide it exclusively on hover. 16-effect maximum has reason text. |
| Source selector | Native menu/picker, 32pt target | Source change preserves inactive settings and one undo action. Explain unfamiliar sources through help, not permanent paragraph blocks. |
| Numeric parameter | Label left; editable tabular value + unit right; slider below; 60pt group | Slider + text field, shared range. Drag is one undo group; Shift fine-adjust (proposed), arrow increments from parameter metadata, double-click track/thumb reset (proposed), context menu Reset as discoverable alternative. Return commits field; Escape cancels; invalid input gets inline feedback. Unit remains outside the editable text. Native accessibility exposes value/unit/range. |
| Bipolar parameter | Numeric parameter plus center tick and signed value | Neutral center is explicit; fill extends from center, not from minimum. Respect true registry range; do not invent negative values. |
| Toggle / bypass | Native Toggle styled as compact checkbox or switch; minimum 32pt target | Checked state has visible mark and text. Use “Bypass” with checked=skipped consistently. Space activates focused toggle. Retain settings during bypass. |
| Color field | Named label, 24pt content swatch in 32pt target | Native color picker; scene color can use any hue. Accessible color name/value; preserve linear-light scene conversion. Swatch never changes editor accent. |
| Menu / popover | Native menu for commands, custom content only when needed | Arrow navigation, Escape dismissal, focus return. Tooltip is help, never the only control label. |
| Status tag | 24pt visual height, icon + short state text | Read-only, not a pill button. “Rendering”, “Output open”, “Bypassed”, “Host stopped” have distinct labels. No invented nominal FPS. |
| Meter / telemetry | Value and unit paired; compact graph optional | Label which input is measured. No-data dash differs from measured zero. Visual level display updates at bounded UI cadence (proposed 15Hz); underlying analysis/rendering unaffected. Avoid VoiceOver announcements every frame. |
| Node | 200pt width, 32pt header, 24pt port rows, 4pt radius | Header label + type; selected accent edge; compilation status icon+text. Ports have names, types and ≥24pt hit targets. Scalar circle, vector diamond, image square, plus type text; future bool/color types need separate labels. Shapes and text remain distinguishable without color. |
| Wire | 2pt line, 4pt selected emphasis, endpoints align to ports | Incoming compatible port highlights on drag. Keyboard selection/connect is equivalent. Nonselected wires subdued but readable. Selected path uses type token plus outline/pattern; errors add symbol+message. |
| Inline notice | Icon, short title, one clear next action | Render: “Unable to render” / Retry. Graph: “Using last valid scene” / Show error. Device: “Input disconnected” / Choose input. Do not overlay errors onto projected content. |
| Empty region | One sentence + contextual action | Chain: “No effects yet” / Add Effect. Search: “No presets match…” / Clear search. Never replace a valid initial preview with onboarding. |
| Dialog / file lifecycle | Native alert, sheet, file panel and Edit menu | Save/discard/cancel protection uses existing document rules. Scene gestures use existing undo grouping; navigation/selection is not scene history. |

Graph type colors: image blue, scalar chartreuse/green, vector violet. Values and increased-contrast variants live in JSON. Type labels and port shapes are mandatory, since scalar color can coincide with the chosen accent.

## 5. Accessibility and performance acceptance

- Text targets ≥4.5:1 against its actual surface, large text ≥3:1; essential boundaries, focus and meaningful graphics ≥3:1. `divider` is decorative and exempt; never use it as the only input outline.
- Keyboard order follows toolbar → source/chain → canvas → inspector. Use native Full Keyboard Access behavior and no Tab interception that traps focus. Context commands have menu equivalents. Test in standalone and host before claiming shortcut support.
- VoiceOver announces parameter name, value, units and bypass state; reports node names, port directions/types and connection changes. Keep diagnostics accessible outside the canvas.
- Increase Contrast changes custom colors; Reduce Transparency preserves opaque readability; Bold Text does not truncate labels. Enlarged text may grow rows and scroll panes.
- No UI gesture waits for GPU completion. No aesthetic post-processing in editor chrome. Both preview and output show the shared runtime result; the illustrative HTML scene is not an engine reference.
- Verify long project/effect names, localization, 16 effects, min/default/wide windows, 1×/2× backing scale, bright scenes, selected+bypassed rows, inactive windows, dirty projects, render failure and last-valid graph recovery.
- During migration run the project's required build/layout/snapshot/menu checks. Review actual Edit menu enablement, Command-Z/Shift-Command-Z, Show Output, close/reopen output and Command-1. A design mockup does not establish runtime accessibility or performance.

## 6. Implementation handoff

Scheduled as **Phase 4B**, the next phase after implemented Phase 4A, before audio/MIDI Phase 5. See `docs/PLAN.md` and stories S-047–S-051. The current graph editor and existing VST3 probe UI are included. Every later phase must reuse Signal automatically for its own UI. The phase order/stories are planned; this kit does not claim native migration is complete.

1. Add semantic adaptive color/type/control-state wrappers while reusing existing Space/Layout values. Keep native document and window behavior.
2. Migrate the current source/effect inspector and compact preview layout first. Introduce editable numeric fields only with proper reducer/history handling.
3. Review a native parts gallery with forced states in light/dark/increased contrast before adopting custom styles across screens.
4. Add wide layout as a responsive variation. Apply graph contracts to the separately authorized graph work; preserve typed validation and compile recovery.
5. Implement presets, mappings, host sync and external-display recipes only within their product milestones.

Suggested ownership: `Sources/VHS/UI/` for current app wrappers; a shared native design module when production plugin/editor ownership is established. Do not couple component state to a global AppModel singleton: plug-in instances must remain independent. Shared tokens do not imply shared mutable UI state.

The reference sheet provides a real appearance comparison, selected effect inspector, bypass toggles, editable range examples, node specimen and state gallery. It intentionally does not simulate project persistence, output windows, host automation or MIDI/audio input. Those require native verification.
