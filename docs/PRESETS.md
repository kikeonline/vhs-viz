# Presets

Phase 7A adds the shared Signal browser to the standalone toolbar and embedded plug-in editor. Factory and User scopes support case-insensitive search. Selecting a row or using arrow keys never changes output. Load asks to replace the current scene, validates and compiles the candidate off the UI/audio paths, then commits one scene replacement. Undo restores the previous scene. A concurrent project/scene edit or host restore cancels the pending load rather than overwriting it. The existing render continues during preparation and on failure.

The Name field supplies the destination name for Save Current Scene, Duplicate and Rename. Factory examples are immutable; Duplicate makes a user copy. Save captures base values, never current modulation. Delete and replacement require explicit confirmation. Import validates a portable file before creating/replacing a user entry; a collision asks before replacement. Cancel preserves the library. Export uses the native save panel and its replacement confirmation. Search with no matches has an explicit empty state; errors retain the current scene/library.

User presets live in `~/Library/Application Support/VHS/Presets/*.vhspreset`. File operations run through `PresetLibrary`'s actor. Writes validate, encode, synchronize a temporary sibling, then atomically rename on confirmed overwrite or link for exclusive creation; failed commits leave existing files unchanged. Names use the project name rules (1–120 characters, no separators/control characters), with case/diacritic collision detection. Rename creates a validated new entry before removing the old one; removal failure can leave both copies, preserving content. Cross-process concurrent external editing, network volumes and power-loss durability have not been certified.

## Portable format

The JSON envelope contains exactly the emitted fields `format: "vhs-preset"`, `version: 1`, `sceneVersion: 5`, `name` and `scene`. Files above 8 MiB, unknown envelope/scene versions, malformed parameter types, missing current fields and invalid graphs/mappings are rejected. Scene versions 1–4 use the existing validated project migrations; re-export writes version 5 scene content. `ProjectDocument` identity is synthesized only inside migration and never serialized into a preset.

Scene content includes graph topology and stable node IDs, source/effect caches and base values, deterministic seed, mappings and confirmed MIDI assignments/channel filters, and the sync setting. There is no live audio/MIDI/transport state, pending learn candidate, device/display selection, host/project identity, output visibility, fullscreen or library URL. Graph editor layout stays local to the existing document and outside musical undo.

Factory examples include a deterministic Solid look, audio-peak-driven Noise scale and a branching Gradient/Oscillator mix. They require no named capture device. Actual host analysis availability remains as documented for Phase 7: Peak + MIDI in the prototype; production RMS/bands/transient and transport behavior belong to Phase 8.

## Project and host ownership

Loading changes scene content within the current `ProjectSession`; its identity, title, file URL and saved baseline stay intact. No project is saved as a side effect. Existing schema-5 `.vhsproject` and bounded plug-in document state embed the entire scene, so deleting/renaming a library file cannot change recall. No project schema increment is necessary.

Plug-in loads preflight the 128 KiB host-state capacity before mutation. Publication marks host state dirty through the existing control-thread bridge, retains notification across a deferred mailbox publication, and asks the host to refresh existing parameter values. Parameter IDs are unchanged. Existing Solid host controls are visibly unavailable for incompatible scenes; unresolved mapping targets retain their UUID/key and are visibly unavailable in Mappings, never retargeted. Local scene undo remains separate from the DAW's undo ownership; actual host automation/dirty/song acceptance remains Phase 8.

See [verification](PHASE-7A-VERIFICATION.md). Phase 4C's outstanding attended checks remain open.
