# Procedural sources

Choose a Source above the parameter inspector. Switching preserves that source's previous settings and is undoable. Parameters come from `VHSCore/SourceRegistry.swift`: one definition supplies each stable identifier, type, title, default, range, and choices to the editor and project validator.

| Source | Variants | Controls |
| --- | --- | --- |
| Solid | Solid fill | Linear Red, Green, Blue |
| Gradient | Linear, Radial | Start/end colors, angle, center X/Y, Reverse |
| Noise | Smooth, Cells | Scale, contrast, low/high colors, UInt32 seed, Animate, speed |
| Oscillator | Sine, Triangle, Square | Cycles, speed, angle, phase, foreground/background colors, Animate |
| Shape | Circle, Rectangle, Triangle | Fill/background, size, position X/Y, rotation, softness, Outline, outline width |

Angle is disabled for Radial Gradient, Speed is disabled while Animate is off, and Outline width is disabled until Outline is on. Their values are retained. Fine controls such as Softness show three decimal places.

Numbers use bounded sliders and group a drag into one undo entry. Discrete keyboard adjustments, choices, toggles and committed seed edits are independent entries. Color controls open the native color panel; each panel value change is undoable. Undo Scene Change and Redo Scene Change use the standard Command-Z/Shift-Command-Z shortcuts.

The inspector scrolls when needed; the Source picker stays above it. Colors use the native picker, with conversion between the panel's sRGB and scene linear RGB. Projects always store opaque linear RGB; the renderer encodes sRGB for the display.

## Coordinates and time

Positions are fractions of output width/height from the top-left. Gradient angle zero runs left to right; radial distance uses the short viewport dimension. Shape Circle remains round at every aspect ratio. Size is its diameter relative to the short dimension; Triangle uses circumdiameter. Rectangle has a 3:2 silhouette and Size sets its height. Softness and outline width are fractions of the short dimension, with derivative antialiasing at zero softness. Positive rotation follows screen coordinates.

Oscillator Cycles describes spatial repetition, Phase is a fraction of a cycle, and Speed is cycles per second (negative reverses direction). Noise Speed is cells per second, panning horizontally. Noise's integer lattice tiles every 4096 cells; its time offset wraps at the same interval for a continuous repeat. Smooth interpolates lattice values; Cells holds a constant value per cell. The saved UInt32 seed selects the pattern.

Animate off evaluates that source at time zero, preserving its phase/speed settings. Animate on follows the common running clock; turning it back on joins the current clock rather than resuming a private playhead. Time is not saved and never marks the project dirty or creates undo entries. Preview and output receive the same scene and clock; their pixel dimensions can differ.

## Project compatibility

Schema 2 persists the selected source, all inactive source settings, and seed. Schema 1 Solid projects migrate while preserving identity/name/color/seed. The next Save writes schema 2; older VHS versions cannot read it. See [PROJECT-FORMAT.md](PROJECT-FORMAT.md).

Effects and audio remain later phases. The native color panel is a system editor, not a new performance-output control.
