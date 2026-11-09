# VHS glossary

| Term | Meaning |
| --- | --- |
| Scene | The source and, in later phases, its ordered effects |
| Source | The procedural image generator at the start of the chain |
| Solid | A source that fills the scene with one color |
| Control window | The editor containing controls and Live Preview |
| Live Preview | The embedded view of the current scene |
| Output | The separate content-only performance surface |
| Color | Linear-light Red, Green, and Blue components in the 0–1 range |
| Show Output | Open or bring forward the existing output window |
| Undo Color Change | Restore the state before a committed color edit |
| Redo Color Change | Reapply the last undone color edit |
| Project | A named, versioned .vhsproject document containing the scene |
| Untitled | A fresh project that has not been saved |
| Edited | Current project values differ from the saved baseline |
| Save Project | Write the active project, choosing a path on first save |
| Save Project As | Save to another path and make it active |
| Rename Project | Change the title and the saved filename without discarding scene edits |
| Don't Save | Continue the requested transition without writing current edits |
| Gradient | Two colors blended along a line or from a radial center | colorize effect |
| Noise | Seeded Smooth or Cells pattern | microphone noise |
| Oscillator | Sine, Triangle, or Square pattern moving with the common clock | audio oscillator |
| Shape | Circle, Rectangle, or Triangle with fill or outline | effect instance |
| Animate | Evaluate the source with running time; off evaluates time zero | pause the output window |
| Seed | Persisted UInt32 controlling repeatable noise | animation time |
| Outline | Draw only a shape's edge using Outline width | transparent background |
| Phase | Offset an oscillator pattern by a fraction of one cycle | implementation phase |
| Cycles | Number of oscillator repetitions across its coordinate axis | hertz of captured audio |
