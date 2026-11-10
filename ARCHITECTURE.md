# VHS architecture

## Targets and ownership

- VHSCore: immutable scene/source/effect/graph contracts, versioned project codec/store/session, history, graph validation/pass planning and clock. No UI or Metal dependency.
- VHSRenderer: per-instance Metal resources, chain renderer, generated graph shaders, actor-isolated compiler, immutable executable graphs and frame-boundary build coordinator. Depends only on Core.
- VHSGraphUI: shared native graph canvas/library/inspector and transient editor selection/error state. Receives immutable graph/layout plus action/layout closures; owns no file controller, renderer, host singleton or audio path. Used by standalone and plug-in.
- VHS: standalone file dialogs/menus/windows, capture/test modes and AppModel. AppModel owns a ProjectSession and RenderSession. Physical audio/MIDI/capture adapters remain future standalone work.
- VHSRealtime: C atomic RGB mailboxes, preallocated bounded event queue and bounded try-once document mailbox. No Swift/UI/render calls from the processor.
- VHSPluginUI: per-instance native runtime/editor/output, shared graph UI, document exchange and pure bounded state-validation export. The Objective-C++ adapter owns host buses/parameters/stream state. No standalone MenuState or termination commands enter the host.

## Execution

The main actor owns editors, histories, layout and windows. Layout is part of ProjectSession but outside SceneHistory; selection is transient. Value drags have explicit begin/end boundaries. Typed graph edges and parameters use persistent UUID/key identities; deleting a target never rebinds it.

GraphCompiler runs on an actor executor: validates, plans bounded passes, generates registry-owned Metal and compiles pipelines. GraphBuildCoordinator accepts an async compilation closure; production uses the actor and tests substitute delayed results. Debouncing, cancellation and generation checks discard obsolete jobs. Only RenderSession.update consumes a ready executable. Preview/output draw its matching immutable scene/time; failed drafts keep the accepted executable and frame scene.

Live submission checks out one of three frame slots and drops on saturation. Each slot exclusively owns scratch textures until completion. The chain uses two textures; branching graphs use up to eight according to liveness. Shader intermediate color is linear RGBA16Float; final output encodes sRGB. Readback/waitUntilCompleted occurs only in opt-in verification and GPU tests.

Host process() remains C++/C and unchanged by graph integration. Host state operations exchange at most 128 KiB of versioned document bytes through a try-once atomic-flag mailbox. State decoding/validation does not render or create an editor. The display timer applies restore and requests compilation; restoring state never auto-opens output. Pure state validation may allocate bounded decoding data; it is a host state operation, never called by process(). Production automation/undo/bypass/transport acceptance remains Phase 8.

## Existing seams

The async compile closure has both production and controlled out-of-order/failure test implementations. Core reduction/validation runs without AppKit. Metal fixtures execute real pipelines. The native embedding harness drives the same shared graph editor/runtime as the plug-in, separately from actual DAW certification.

Space/Grid/Tokens sources are symlinked into UI targets to avoid drift; each target records its own layout probes. A shared GraphEditorDiagnostics entry point exports the graph module's measurements for app/harness verification.
