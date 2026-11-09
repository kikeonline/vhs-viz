# VHS project format

`.vhsproject` is a UTF-8 JSON document registered as `com.kike.vhs.project`, conforming to `public.json`. Current schema: **2**. Maximum encoded/read size: 8 MB.

## Schema 2

The top-level keys are `schemaVersion` (2), `id` (UUID), `name`, and `scene`. The scene contains:

- `source`: `solid`, `gradient`, `noise`, `oscillator`, or `shape`.
- `seed`: an unsigned 32-bit integer, shared by the project and exposed on Noise.
- `parameters`: a JSON object keyed by stable `ParameterID` strings from `VHSCore/SourceRegistry.swift`. It contains all source settings, including inactive sources; switching sources does not throw away edits.

Each parameter is tagged: `{"type":"number","value":0.24}`, `{"type":"choice","value":"radial"}`, `{"type":"toggle","value":true}`, or `{"type":"color","value":{"red":0.24,"green":0.08,"blue":0.62}}`. Colors are opaque, linear-light RGB in 0…1. The native color picker converts to/from linear sRGB. The renderer encodes to sRGB at the output attachment.

All parameter keys are required. Unknown or missing keys, wrong value types, invalid choices, nonfinite/out-of-bounds numbers and nonintegral integer parameters are rejected. The source registry is the authority for type, default, range and choices; data loaded from disk is never silently clamped. Runtime UI actions clamp numeric values and ignore incompatible typed values.

## Migration

Schema 1 held `scene.color` (linear RGB) and `scene.seed`. Its decoder validates the original values, then creates a schema 2 Solid scene, retaining identity, name, seed and color and filling new source defaults. Loading is clean and resets history normally; the next Save writes schema 2. No migration is invented for version 0. Unsupported older/future versions are rejected; a future version explains that a newer VHS is needed.

Migration and dispatch occur only in `ProjectCodec`. New schema changes must add an explicit migration and tests. A later app must not interpret new parameter semantics as schema 2 without a migration.

## Titles and rename

The filename without extension is authoritative when opening, including externally renamed files. The serialized `name` is validated but normalized to that filename in memory. A saved Rename moves the file in its current folder, refuses collisions and preserves dirty scene values/history; the JSON name is synchronized on the next Save. Renaming an unsaved project changes its suggested save name. Save As retains the old file and changes the active URL only after success.

## Atomic writes and document transitions

`ProjectIO` keeps file work off the main actor. A Save encodes and validates an immutable snapshot, writes a unique temporary sibling, synchronizes/closes its handle, and uses same-directory POSIX rename to atomically replace the target. Failure before successful replacement leaves the previous file intact; temporary siblings are cleaned up. The saved snapshot establishes the baseline; scene edits made during standalone Save remain dirty.

New/Open/close/quit block scene editing while resolving Save/Don't Save/Cancel. Open validates before prompting and re-reads the committed candidate after the decision: saving can have replaced the very file selected for Open. Replacing a project resets undo; switching sources is an ordinary undoable scene edit. Runtime clock time, output lifecycle, and UI state are never serialized.

These guarantees cover ordinary write/replace errors, not power-loss durability, concurrent external writers, or network/cloud filesystem coordination. Those environments have not been validated.
