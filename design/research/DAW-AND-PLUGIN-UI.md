# DAW and plug-in UI research

Research date: 2026-11-10. Scope: official product imagery and published manuals, not hands-on usability testing or measured competitor specifications. Product versions below identify the references inspected; they are not a claim about the latest release. All numeric VHS values are original design decisions. The observations and recommendations are design analysis, not statements by the manufacturers.

## Comparative findings

| Reference | Observed visual / interaction pattern | Take into VHS | Leave behind |
| --- | --- | --- | --- |
| Ableton Live 12 | Flat neutral surfaces; tightly grouped toolbar; repeated device geometry; color encodes clips, states and modulation. Manual describes a persistent Control Bar and contextual status information. | Stable control locations, a strict grid, compact labels, restrained chrome. | DAW-scale visual density and small targets. VHS needs space for its image. |
| Neural DSP Archetype: Gojira X | Near-black shell, persistent global controls and preset area; discrete signal-chain navigation above a large amplifier depiction. Numerals and knobs have a technical instrument character. | Strong silhouette, deliberate contrast, source → effects → output hierarchy. | Photoreal amplifier, grilles, cables and ornamental material. VHS's rendered content is its hero object. |
| FabFilter Pro-Q 4 | Large editable graph dominates; band controls appear for the selected bands; global functions sit at the perimeter. Manual documents fine adjustment, value entry and scalable views. | Content-first layout, selection-driven inspector, exact value entry, readable resizing. | EQ-specific rainbow bands as general decoration; hover-only access to essential controls. |
| Bitwig Studio / The Grid | Dense but consistently grouped panels; color separates content and signals; The Grid makes patch structure visible and provides contextual module help. | Typed ports, selected-path emphasis, immediate contextual inspection. | Bitwig's interchangeable signal model: VHS has typed connections and must enforce compatibility. |
| Minimal Audio Current | Dark shell, a large visual center, clear Play/Engine/Effects/Stream navigation; a small set of primary macro controls near the visual. | Separate common performance tasks from deep construction; let the image carry expression. | Cloud/library account patterns and a keyboard. VHS is local, offline and generates visuals. |

## Primary sources and inspected images

1. **Ableton:** [Live concepts, manual v12](https://www.ableton.com/en/manual/live-concepts/) — toolbar organization and contextual status. [Official UI image](https://ableton-production.imgix.net/live-manual/12/ControlBarL12.png?auto=&w=1600). [Live 12 release notes](https://www.ableton.com/en/release-notes/live-12/) — theme, contrast and view styling. An initial general product link redirected to Live 13; this study deliberately uses the versioned v12 manual/image as its reference.
2. **Neural DSP:** [Archetype: Gojira X](https://neuraldsp.com/plugins/archetype-gojira). [Official interface image](https://images.ctfassets.net/8puu65w27ud0/3GZTR4l2KNtbquiYsztlKW/74b876bbd132c28bd9b3bfb0c7059edf/a-gojira-x-ui.png?w=1080).
3. **FabFilter:** [Pro-Q 4 overview](https://www.fabfilter.com/help/pro-q/using/overview), [display workflow](https://www.fabfilter.com/help/pro-q/using/eqdisplay), [resizing and scaling](https://www.fabfilter.com/help/pro-q/using/fullscreenandresize). [Annotated official interface image](https://www.fabfilter.com/help_pages/pro-q/images/overview@2x.jpg).
4. **Bitwig:** [Studio overview](https://www.bitwig.com/overview/), [The Grid](https://www.bitwig.com/the-grid/). [Official interface image](https://assets.bitwig.net/media/image/bitwig-studio_bws6_full-gui-hero/Bitwig-Studio_BWS6_Full-GUI-Hero-LG-SD.png?v=AUnG3FE6bi).
5. **Minimal Audio:** [Current manual with Play View image](https://manual.minimal.audio/current-manual). The product page exposed no readable text; the official manual and its embedded image supplied the visual reference.

Valhalla VintageVerb was considered as an additional flat-UI reference, but the official page returned 403. It is excluded from the evidence base.

Competitor images are linked as references; they are not bundled as VHS assets. VHS diagrams and scene studies in the reference sheet are original, code-drawn illustrations, not screenshots of running VHS.

## Synthesis: Signal

Precise. Restrained. Electric. A graphite instrument panel with off-white labels, thin rules, compact rectangular controls and a chartreuse brand option. The generated scene supplies saturated color; the control surface stays neutral. Identity comes from aligned geometry, tabular numbers and a strong image silhouette. Avoid grain, scanlines, fake CRT typography and permanent glow in the editor, even though the app is named VHS.

The balance is Ableton's consistency, FabFilter's canvas priority, Neural DSP's instrument character, Bitwig's visible signal relationships and Current's expressive visual center. This is a design interpretation, not a copy of any one product.

## Existing VHS audit

Inspected `docs/BRIEF.md`, `docs/DESIGN.md`, the existing design system, native spacing/layout tokens, source/effect controls, graph source files, and the existing `/tmp/VHS-shots/source-oscillator-dark.png` capture. The saved capture shows an earlier source-inspector state; it is not evidence of current graph/effect behavior. The checkout contains ongoing work and was not modified outside design documentation.

Keep: visible initial content, separate overlay-free output, 280pt inspector, native menus/dialogs, aspect-correct preview, immutable scene edits and grouped undo, offline workflow, system appearance and accent override.

Improve: hierarchy between title/section/parameter labels; repeatable value alignment; a clear selected effect; visible bypass state; contextual failure recovery; and compact, predictable panel proportions as the feature set grows.

## Design tradeoffs

- Chartreuse gives the brand energy but cannot use white text in dark appearance: use the dark `onAccent` token. Light appearance uses a deeper green.
- A third chain column helps long chains on wide screens but consumes preview width. Keep the chain below preview at the existing default/minimum sizes; use a rail only at ≥1200pt.
- Rotary controls look familiar in audio software but cost space and precision. Use sliders and editable values by default. A knob needs a demonstrated performance benefit before being added.
- A preset browser and mappings are future patterns. Show those when their milestones ship; do not expose decorative inactive product navigation.
- A bright scene must not reduce inspector readability. Surfaces stay opaque and scene-independent; only the preview/output uses scene colors.

## Validation to do during implementation

Observe musicians in Studio One switching between scene editing, automation and output recovery. Verify exact numeric entry and grouped undo; no gesture collisions with host shortcuts; two-instance independence; light/dark and increased contrast; VoiceOver; minimum-size overflow; graph keyboard operations; output recovery after disconnect; and unchanged render performance. This research does not establish those checks as passed.
