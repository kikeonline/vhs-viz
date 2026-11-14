# VHS project format

`.vhsproject` is a UTF-8 JSON document registered as `com.kike.vhs.project`, conforming to `public.json`. Current schema: **4**. Maximum encoded/read size: 8 MB.

Phase 4A implements typed shader graphs in schema 4 (see SHADER-GRAPHS.md); ordered effects were introduced in schema 3. Factory/user presets, MIDI-learn assignments, audio/MIDI mappings, sync settings, and production DAW automation state remain planned. The probe already embeds the implemented graph document in its host state. Their implementation must define explicit migrations/envelope versions and validation. A DAW song must embed its instance state without depending on an external .vhsproject path; hardware selection and live input/render/transport state must not be mistaken for portable scene data.

Planned portable preset/graph contract: stable node/parameter IDs and typed edges; graph/base values, seed, mappings and sync settings; explicit version/migration and validation before compile/apply. Project/DAW state embeds loaded preset content instead of referring to a library file. Device/display IDs, live input, window visibility and fullscreen are local/transient. Graph compilation failure leaves the last working executable graph active. The current schema is 4; later additions require new explicit migrations.

## Schema 4 graph additions

Every scene requires a version-1 `graph` (`nodes`, `edges`, `version`). Nodes have UUID `id`, typed `kind`, complete tagged `values` and `bypassed`; edges have `from`/`to` endpoints (`node` UUID, `port` key). Kind uses Codable associated-value objects such as `{"source":{"_0":"gradient"}}`. Port types and eligible target metadata are registry-owned, not file-defined. Exactly one Output, acyclic valid references, required inputs and bounded nodes/passes/textures are validated. Unknown kinds and invalid inputs report their node where available.

The source/effect fields remain a compatible chain cache. When the entire graph is representable, the cache must agree; mismatches are rejected. Arbitrary graphs are never flattened or executed through that cache. The project adds `graphLayout` with UUID-keyed `positions`, `pan` and `zoom`; layout changes affect dirty tracking but are outside scene undo. Selection/live input/window visibility are not stored. See SHADER-GRAPHS.md for limits and target identities.

Schema 3 validates its original typed source/effect data, then constructs equivalent graph nodes/edges with deterministic source/output IDs and retained effect UUIDs; graphLayout starts at its defaults. Schemas 1/2 also migrate directly to current schema 4. All subsequent saves write 4. The probe’s `VHS2` host envelope embeds the same project bytes (128 KiB bound) and retains legacy `VHS1` RGB-state reads; it saves no project path.

## Source/effect fields (introduced in schemas 2/3)

The top-level keys are `schemaVersion` (4), `id` (UUID), `name`, `scene`, and `graphLayout`. The scene contains:

- `source`: `solid`, `gradient`, `noise`, `oscillator`, or `shape`.
- `seed`: an unsigned 32-bit integer, shared by the project and exposed on Noise.
- `effects`: ordered array (maximum 16) of `{id, kind, bypassed, parameters}` records. UUIDs are unique; kind is transform/blur/pixelate/threshold/colorize/rgbSplit. Parameter keys/types/ranges must exactly match EffectRegistry. See EFFECTS.md.
- `parameters`: a JSON object keyed by stable `ParameterID` strings from `VHSCore/SourceRegistry.swift`. It contains all source settings, including inactive sources; switching sources does not throw away edits.

Each parameter is tagged: `{"type":"number","value":0.24}`, `{"type":"choice","value":"radial"}`, `{"type":"toggle","value":true}`, or `{"type":"color","value":{"red":0.24,"green":0.08,"blue":0.62}}`. Colors are opaque, linear-light RGB in 0…1. The native color picker converts to/from linear sRGB. The renderer encodes to sRGB at the output attachment.

All parameter keys are required. Unknown or missing keys, wrong value types, invalid choices, nonfinite/out-of-bounds numbers and nonintegral integer parameters are rejected. The source registry is the authority for type, default, range and choices; data loaded from disk is never silently clamped. Runtime UI actions clamp numeric values and ignore incompatible typed values.

## Migration

Schema 1 held `scene.color` (linear RGB) and `scene.seed`. Its decoder validates the original values, then creates a schema 4 Solid scene with an empty effect chain and equivalent graph, retaining identity, name, seed and color and filling new source defaults. Loading is clean and resets history normally; the next Save writes schema 4. No migration is invented for version 0. Unsupported older/future versions are rejected; a future version explains that a newer VHS is needed.

Schema 2 source scenes validate their full typed parameter set and migrate unchanged to schema 4 with an empty effect chain and equivalent graph. Source settings (including inactive sources), identity and seed are preserved. Current schema 4 requires `effects` and `graph` explicitly; malformed effect data is rejected atomically.

Migration and dispatch occur only in `ProjectCodec`. New schema changes must add an explicit migration and tests. A later app must not interpret new parameter semantics as schema 2 without a migration.

## Titles and rename

The filename without extension is authoritative when opening, including externally renamed files. The serialized `name` is validated but normalized to that filename in memory. A saved Rename moves the file in its current folder, refuses collisions and preserves dirty scene values/history; the JSON name is synchronized on the next Save. Renaming an unsaved project changes its suggested save name. Save As retains the old file and changes the active URL only after success.

## Atomic writes and document transitions

`ProjectIO` keeps file work off the main actor. A Save encodes and validates an immutable snapshot, writes a unique temporary sibling, synchronizes/closes its handle, and uses same-directory POSIX rename to atomically replace the target. Failure before successful replacement leaves the previous file intact; temporary siblings are cleaned up. The saved snapshot establishes the baseline; scene edits made during standalone Save remain dirty.

New/Open/close/quit block scene editing while resolving Save/Don't Save/Cancel. Open validates before prompting and re-reads the committed candidate after the decision: saving can have replaced the very file selected for Open. Replacing a project resets undo; switching sources is an ordinary undoable scene edit. Runtime clock time, output lifecycle, and UI state are never serialized.

These guarantees cover ordinary write/replace errors, not power-loss durability, concurrent external writers, or network/cloud filesystem coordination. Those environments have not been validated.
