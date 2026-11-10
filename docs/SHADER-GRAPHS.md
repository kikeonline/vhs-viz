# Shader graphs (Phase 4A)

Choose Nodes in the toolbar. Chain stays available when the complete graph is one source followed by at most 16 ordered effects, without extra nodes or parameter connections. Returning to Chain never discards branches, values or disconnected nodes: incompatible graphs keep Chain disabled with an explanation. Older projects migrate to equivalent nodes and edges; source/effect identities survive edits in either mode.

## Editing

Add Node opens a searchable library. Select a card title or use Selected node in the inspector. Drag a card title to move it; inspector Position X/Y fields provide a keyboard alternative. Duplicate creates a new UUID and copies values/input connections; Remove deletes that node and its connections. The one Output cannot be duplicated or deleted.

Drag an output port onto a matching input. Alternatively click an output then an input, or use each input's native inspector picker. The first picker option disconnects (or returns an optional parameter to its base value). Inputs accept exactly one connection; outputs can feed multiple branches. Numeric/color parameter connections disable their base-value controls while preserving those values. Source choices/toggles remain inspector values, with stable port definitions for the numeric/color parameters.

Drag the background to pan; Zoom In/Out, Pan and Reset View also have native controls. Pan, zoom and positions are saved outside musical undo. Selection and an unfinished connection gesture are transient. Graph/value edits use immutable snapshots and undo/redo; a numeric drag is one edit. The standalone uses its scene Undo/Redo commands; the probe exposes local Undo/Redo Graph Edit buttons without installing app commands into the DAW. Full host automation/undo certification is Phase 8.

## Node library and types

| Family | Nodes |
| --- | --- |
| Sources | Solid, Gradient, Noise, Oscillator, Shape; existing variants and parameter metadata |
| Effects | Transform, Blur, Pixelate, Threshold, Colorize, RGB Split; Bypass and existing image contracts |
| Values | Number, Vector (two components), Color (opaque linear RGB), UV (normalized top-left coordinates), Time (free-running seconds) |
| Scalar math | Add Numbers, Multiply Numbers, Sine |
| Vector math | Add Vectors, Multiply Vectors |
| Color | Compose Color, Luminance, Mix Colors, Sample Image, Color to Image |
| Image | Mix Images and exactly one final Output |

Ports are scalar (float), vector (float2), color (float4 with opaque RGB semantics), or image (a full-resolution image). There are no implicit conversions. Compose Color clamps components to 0…1; Luminance uses Rec.709 linear weights. Mix amounts clamp to 0…1. Sample Image uses bilinear filtering/clamped UV. Scalar/vector arithmetic saturates finite results to ±1,000,000 and turns nonfinite results into zero. Registered numeric parameter connections clamp to their declared bounds; base number/vector constants are bounded to ±1000. Global Seed is saved and shared by Noise nodes; it is not a per-node hardware/input setting.

Time is a finite Float shader value derived from the common seconds clock. Long-duration float precision and timing remain performance/sync measurement concerns; Follow DAW remains Phase 8. Static source/effect chain scenes retain their original Double-based CPU time folding and renderer fixtures.

## Validity, compilation and recovery

Graphs are version 1, acyclic, with at most 64 nodes, 256 connections, 64 image passes and eight simultaneously needed intermediate textures. Validation rejects duplicate/missing identities, unsupported kinds/versions, mismatched ports, multiple connections to an input, cycles, invalid values and resource overflow with a node-specific diagnostic where possible. Shader expressions are limited to 64 KiB. Unconnected optional parameter inputs use their base values; required ports must be connected before execution/save.

Incomplete drafts remain editable and undoable. Invalid type/cycle connections are rejected without committing the link. An incomplete required input or compiler failure leaves the last valid executable and its scene on preview/output; time continues. Save validates the complete candidate, preserving an existing file on failure. In the probe, an incomplete/oversized candidate reports an error and keeps the last valid host-state bytes.

Only registry-owned Metal is generated; project files contain no arbitrary shader source. GraphCompiler validates, plans and compiles on an actor executor. An 80 ms debounce coalesces edits; cancellation and generation checks prevent obsolete results from replacing current state. The common frame timer alone adopts a ready graph. Preview/output share the accepted snapshot/time, at their own sizes.

Images are rendered in topological passes. Scalar/vector/color expressions run in the image pass that consumes them; image dependencies stop at texture boundaries. Blur uses two passes. Liveness assigns reusable slots without reading and writing the same texture in a pass. Each renderer has three in-flight frame slots, up to eight scratch textures per slot; saturation drops a live frame. No live GPU completion wait/readback is added. Maximum dimensions remain 4096×4096. All image intermediates are linear RGBA16Float; only final output is sRGB encoded. Compiled chain equivalence tolerance is two output-byte values; default noise/source comparisons use one. The compatible chain path itself is unchanged and exact.

## Persistence and targets

Project schema 4 stores the immutable graph plus the compatible source/effect cache, global seed, and a separate graphLayout (positions, pan, zoom). Schemas 1/2/3 migrate explicitly to equivalent graphs with deterministic source/output IDs; existing effect UUIDs become node UUIDs. Custom graph source/output IDs are retained when editing in Chain. Cache/graph mismatch is rejected, never used to render a different scene silently. Layout permits up to 128 bounded UUID positions (including undo recovery positions), finite pan and zoom 25%…200%.

GraphParameterTarget is node UUID + local parameter key. Shared registry definitions expose numeric eligibility/range/default metadata. Missing targets return unavailable and never retarget a replacement node. The shared inspector can display supplied unresolved references. Actual MIDI/audio mappings and host binding slots remain Phase 7/8; no production mappings are invented in this phase.

## Plug-in probe

The native probe embeds the same VHSGraphUI and compiler as standalone. Probe version is 0.4.1; its existing class identity and parameter IDs remain compatible. Legacy `VHS1` RGB-only host state remains readable. Extended `VHS2` state contains the same three finite RGB values, a bounded length and an embedded schema-4 project (topology, node values/IDs, seed and editor layout), not an external file path. Live audio/MIDI/transport, window visibility and device/display choices are excluded.

The host-state document limit is 128 KiB (standalone project limit remains 8 MiB). A preallocated try-once mailbox serializes copies without spinning. Version-checked UI publication cannot overwrite an unconsumed host restore. Pure validation happens in the state operation, without views, disk or compilation. The display timer consumes a restored document and compiles as needed. Restore never auto-opens output. Explicit graph edits notify the host's dirty interface after successful publication when supported; the display timer never calls the host edit callback. Existing probe RGB host controls and audio/velocity/CC bindings apply to compatible Solid chains; arbitrary node targets await the production binding surface.

`process()` remains C++/C, with unchanged stereo byte pass-through and bounded input handoffs; it does not call state validation, Swift, graph compilation or rendering. Actual Studio One graph/UI/recall checks are deferred under the user's automated-only direction. Native embedding, real processor state fixtures and SDK validator results are recorded separately in PHASE-4A-VERIFICATION.md.
