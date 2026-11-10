# Ordered effects (Phase 4)

Add Effect appends an instance and selects its inspector. Select a row to edit it; Source returns to the source controls. The native list supports keyboard selection; Tab/Space operates Bypass and Move Up/Move Down buttons. The row context menu also offers editing, bypass, ordering and removal. Remove Effect is in the inspector. At most 16 effects are allowed; repeated types are independent.

All structural edits and committed values are undoable. Continuous numeric drags are grouped into one edit. Inspector selection is transient and does not mark the project dirty or add history. Removal returns the inspector to Source; Undo restores the original effect UUID/settings. Switching sources retains the effect chain.

## Rendering contract

Each effect consumes the image produced by the previous enabled effect. All effects output opaque linear RGB. The source and intermediate passes use RGBA16Float; final BGRA8 sRGB conversion happens once. An empty or entirely bypassed chain uses the original source pipeline directly, preserving old fixtures exactly. Neutral enabled effects can differ by one output byte due to intermediate floating-point rounding.

| Effect | Parameters and behavior |
| --- | --- |
| Transform | Position X/Y −1…1 in units of the viewport's shorter side; positive X moves right, positive Y down. Rotation −180…180 degrees clockwise in the screen coordinate system. Scale 0.1…4 around center. Inverse sampling, black outside source extent. Defaults: 0/0/0/1. |
| Blur | Radius 0…32 output pixels, default 8. Two separable 33-tap Gaussian passes over ±radius with sigma radius/3. Bilinear sampling; clamp to image edge. Radius zero is neutral. |
| Pixelate | Block size 1…128 output pixels, default 12. Square cells anchored at the top-left; sample each cell's center with bilinear filtering. Clamp incomplete edge-cell samples. Size one is neutral. |
| Threshold | Level 0…1 (default 0.5), softness 0…0.5 (default 0). Rec.709 linear luminance (0.2126, 0.7152, 0.0722). At zero softness, luminance >= level becomes white. Otherwise smoothstep(level−softness, level+softness). |
| Colorize | Dark color (default black), Light color (default VHS purple), Amount 0…1 (default 1). Map Rec.709 linear luminance between the two colors, then linearly mix with the original. Amount zero is neutral. |
| RGB Split | X/Y −64…64 output pixels (defaults 8/0). Red samples at UV+offset, green at original UV, blue at UV−offset; clamp to edge. Zero offsets are neutral. |

Pixel-valued effects are evaluated at each surface's own pixel resolution; preview/output use the same scene and time, with matching parameters rather than identical pixels at different sizes.

## Identity, persistence and limits

Schema 3 requires an ordered `scene.effects` array. Every record has `id` (UUID), `kind`, `bypassed` and a complete typed `parameters` object. UUID plus parameter key identifies a future automation/mapping target; reorder never changes either. No production mapping or host automation surface is added in Phase 4. The Phase 3A plug-in retains its explicitly limited RGB probe state/editor.

Schema 1 and 2 explicitly migrate to schema 3 with an empty chain. Current-schema missing/unknown effect kinds, wrong parameter keys/types, invalid ranges, duplicate IDs, malformed UUIDs and chains over 16 are rejected before document replacement. Files are never silently clamped. Runtime numeric actions clamp; incompatible actions are ignored.

Each per-instance MetalRenderer owns three nonblocking frame slots. A slot retains at most two reusable intermediate textures; checkout prefers a matching size, then an empty slot, then replaces an idle slot's obsolete size. Completion releases the slot; an in-flight texture is never resized or overwritten. At saturation the live frame is dropped. Maximum drawable/readback dimensions are 4096×4096; a chain has at most 32 effect passes plus its source pass. No GPU wait/readback occurs in live submission; fixtures alone synchronously read output. Pool checks prove retained texture count/reuse, not a full-process memory or performance certification.
