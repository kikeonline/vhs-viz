# Design artifact verification

Date: 2026-11-10. This verifies the design reference artifacts, not the native app or VST3.

## Visual inspection

Rendered the HTML in headless installed Google Chrome using Playwright 1.65.0. Visually inspected the dark and light full-page references, the dark editor crop, and the narrow document capture. Checked the increased-contrast appearances through browser rendering and token checks. Corrected the primary-action specimen fill, muted text contrast and graph-wire endpoint alignment. Preview preserves a 16:9 content area. Artwork is an original Canvas illustration, not a running Metal render.

Delivered images: `vhs-design-system-dark.png`, `vhs-design-system-light.png`, `vhs-editor-concept.png`. The standalone HTML has embedded styles, tokens and illustration code; no network requests, packages or external fonts are needed to open it.

## Automated interaction / layout checks

- Dark, light, dark increased contrast, light increased contrast switch correctly.
- Effect selection updates the inspector.
- Exact numeric entry commits; arrow keys update the linked field; Escape cancels uncommitted edits; out-of-range values fail browser validity checks.
- Row bypass and inspector bypass stay synchronized. Bypassed effects retain values and remain editable.
- Sample diagnostic expands and collapses.
- No JavaScript page errors.
- No document horizontal overflow at 1440, 1000, 880, 680 or 390px widths.

The HTML intentionally omits real project saving, shader compilation, output-window control, host sync and MIDI/audio. The visible Show Output treatment is a static visual specimen. HTML numeric editing does not model native undo history.

## Token contrast checks

Computed sRGB relative luminance for 244 foreground/background combinations across the four themes. Text roles checked at ≥4.5:1 on canvas/surface/raised/hover/selection; onAccent checked against accent. Essential boundaries/focus/type colors checked at ≥3:1 on those five surfaces. Decorative divider tokens were excluded. Minimum observed ratios:

| Theme | Text minimum | Essential graphic minimum | Result |
| --- | --- | --- | --- |
| dark | 4.66:1 (muted / selection) | 3.12:1 (controlBorder / selection) | Pass |
| light | 4.69:1 (muted / hover) | 3.10:1 (controlBorder / hover) | Pass |
| darkHighContrast | 5.49:1 (muted / selection) | 4.84:1 (controlBorder / selection) | Pass |
| lightHighContrast | 6.27:1 (muted / selection) | 4.87:1 (controlBorder / selection) | Pass |

These are mathematical checks of the Signal palette. Native system-accent overrides, actual custom-control rendering, VoiceOver, Full Keyboard Access, macOS settings, plugin-host keyboard handling and native minimum-size behavior require verification during implementation. Color-swatches and generated scene content are outside UI contrast tests.

## Scope integrity

Only design documents/artifacts were authored. `design/DESIGN-SYSTEM.md` gained a link to the Signal specification; previous implementation guidance remains intact. Existing application source work was preserved. No native application build, runtime UI check or implementation test is claimed by this design task.

## Approval

The user approved Signal on 2026-11-10. Approval was recorded in the design guidelines, kit, token metadata and reference sheet. This establishes the design direction for future UI work; native migration has not been performed.
