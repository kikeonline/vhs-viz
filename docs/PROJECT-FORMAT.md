# VHS project format

A `.vhsproject` is UTF-8 JSON. Version 1 is the first public schema:

```json
{
  "schemaVersion": 1,
  "id": "CE0BB40E-4F90-45BA-AC60-C62F61E5CC92",
  "name": "Sunset Session",
  "scene": {
    "color": { "red": 0.24, "green": 0.08, "blue": 0.62 },
    "seed": 1
  }
}
```

`id` is the logical project identity and survives Save As. Color components are finite linear-light numbers in 0–1. `seed` is an unsigned 32-bit integer. The source is implicitly Solid in version 1. Undo history, rendering time, windows, device handles, and transient runtime values are not serialized.

`ProjectCodec` validates the schema header before decoding content and rejects unsupported versions, invalid values, malformed documents, and files larger than 8 MB. `schemaVersion` dispatch is the migration boundary. There is no invented legacy version: version 0 is rejected. When a later schema is introduced, add explicit migration from version 1 and round-trip fixtures, preserving identity, color, and seed. Never reinterpret a future version as the current format.

## Titles and rename

The filename without `.vhsproject` is authoritative for saved-project titles, including external Finder renames. The JSON name records the title at the last save and is synchronized on subsequent saves. Unsaved projects retain the chosen title in memory until saved. Names are trimmed and must contain 1–120 characters without path separators, colons, control characters, or dot-only directory names.

Rename moves an existing file within its directory without overwriting another file. It preserves unsaved scene edits and scene undo history. Case-only rename is tested. Rename does not create a scene undo entry. Save As writes a new file before changing the active URL and keeps the original file.

## Atomic saves

1. Capture an immutable project snapshot.
2. Encode and validate it on the file-I/O actor.
3. Write a unique temporary sibling file and synchronize it.
4. Atomically rename that sibling over the target.
5. Update the saved baseline only after success, retaining any scene edits made during the write as dirty.

A write or replacement failure leaves the target untouched. Temporary files are cleaned up after the operation. Tests inject a failure after writing and before replacement, and exercise actual write/rename failures. This is an atomic-save guarantee; it does not claim a complete power-loss recovery journal.

New/Open reset document history after the transition succeeds. Candidate files are decoded before current edits are discarded. Save, Don't Save, and Cancel protect New/Open, editor close, and Quit. A cancelled or failed save prevents departure. Closing the separate output never prompts or discards project edits.
