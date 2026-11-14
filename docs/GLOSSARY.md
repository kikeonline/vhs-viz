# VHS glossary

| Term | Meaning |
| --- | --- |
| Scene | A source/effect chain or, after Phase 4A, a typed shader graph producing one output |
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
| Standalone | VHS.app running independently with its own audio/MIDI device inputs |
| VST3 | VHS.vst3 loaded by Studio One, receiving host audio, MIDI, automation, and transport |
| Host | Studio One, which owns plug-in processing and song recall |
| Plug-in editor | The host-attached VHS controls; closing it does not destroy the instance or output |
| Instance | One independent VHS scene, input state, clock, editor, and output within a host song |
| MIDI learn | Select a control and learn a CC/note assignment with channel filtering, confirmation, cancel and clear; VST3 may use a host-mediated workflow |
| Free Run | Animate with VHS's local seconds-based clock |
| Follow DAW | Animate from valid host musical time and transport, with a documented fallback |
| Song recall | Restore embedded VHS scene/mappings/sync state when the DAW song opens |
| Audio pass-through | Copy incoming host audio unchanged; VHS produces visuals rather than sound |
| Shader graph | Typed source, math, color and effect nodes connected to one Output node |
| Preset | Portable named scene/graph plus base values, seed, mappings and sync settings |
| Factory preset | Bundled example that can be copied into the user library |
| User preset | A saved look the performer can rename, duplicate, delete and export |
| Output destination | The connected display selected for an instance's output window |
| Fit / Fill | Preserve aspect with letterboxing / crop to fill the output surface |

| Effect | One identified image operation in the ordered chain |
| Bypass | Temporarily skip an effect without deleting its settings |
| Move Up / Move Down | Apply the effect earlier / later in the chain |
| Transform | Translate, rotate and scale the incoming image |
| Blur | Soften the incoming image with a separable Gaussian filter |
| Pixelate | Sample the incoming image in square pixel blocks |
| Threshold | Turn luminance into black/white with optional softness |
| Colorize | Map luminance between two colors and mix with the original |
| RGB Split | Offset red and blue in opposite directions around green |

| Node | One identified source, effect, value or operation in a shader graph |
| Port | A typed node input or output |
| Connection | A directed link from an output to a matching input |
| Output node | The one final image destination in a graph |
| Last valid render | The working graph kept on screen while a new graph is incomplete or fails compilation |
| Chain | Source followed by ordered effects; available only for fully representable graphs |

| Inputs | Standalone audio/MIDI source choices, live input status and meters |
| Audio input | Selected microphone/interface by stable device UID |
| MIDI source | Selected Core MIDI source by stable unique ID |
| Channels | One input channel or adjacent stereo pair to analyze |
| RMS / Peak | Window level / maximum sample magnitude, displayed in dBFS |
| Low / Mid / High | Normalized band RMS from the shared analysis engine |
| Transient | Normalized increase in RMS between analysis hops |
| Listening / Silent | Capturing a selected input / receiving measured silence |

| System Audio | Audio from content selected through the macOS sharing picker; standalone only |
| Choose Audio to Share… | Open the native picker for an explicitly requested system-audio session |
