# Phase 4A architecture check-in

Signal: this feature crosses more than six files and two targets. Survey performed after the graph model/compiler/editor were established; no additional refactor is proposed in this review.

The feature already introduces three coherent boundaries: pure graph validation/planning in VHSCore, compilation/execution in VHSRenderer, and a shared VHSGraphUI used by standalone and the plug-in. Files remain under 600 lines. UI code does not reach into renderer internals; the compiler is replaceable in coordinator tests, and frame timing is not published into every editor view.

## Top recommendation

Keep these boundaries and complete the current phase's verification. No additional architectural refactor is needed to deliver Phase 4A, so there is no refactor candidate requiring a user choice. ARCHITECTURE.md records the target dependencies, threading and tested seams.

## Considered, not recommended

- Speculative: unify the standalone and probe's entire session controller. Their file/host-state ownership differs; sharing the graph UI and core value contracts supplies the useful reuse now. Revisit production host state/automation in Phase 8.
- Speculative: build a general renderer protocol. Actual Metal fixtures already test execution; the async compilation closure is the seam needed to prove stale-job handling. A broader abstraction would add interface without a second execution adapter.
- Worth exploring later: more precise pipeline reuse for numeric-only graph changes. The current bounded/debounced background compiler is correct; profile actual graphs before adding a pipeline cache or uniform indirection. Performance certification remains Phase 9.
