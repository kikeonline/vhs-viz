# VHS checkpoint

Phases 1–3 are implemented and functionally verified. The release app is installed at ~/Applications/VHS.app. Phase 4 has not started; wait for user direction.

Phase 3 provides Solid, Gradient, Noise, Oscillator and Shape, generated typed controls, retained inactive settings, deterministic Metal fixtures, and schema 1 → 2 project migration. See SOURCES.md, PROJECT-FORMAT.md and PHASE-3-VERIFICATION.md for contracts and evidence. Registry metadata owns parameter types, bounds, choices, defaults, decimal precision and conditional control availability.

Commands use SwiftUI's menu tree and observed availability. Undo/Redo are now Scene Change. Both Metal surfaces are explicitly drawn from the common frame timer, with weak surface ownership; the self-test checks drawable progress and matching restored snapshots. Rendering never waits for GPU completion. Test readback is synchronous.

GitHub #10 remains open for actual VoiceOver announcement/navigation and macOS 26 runtime verification. Keyboard-only sliders, Increase Contrast and external Edit-menu enablement passed in that follow-up; keyboard/menu checks also passed again after Phase 3. Current runtime is macOS 27.2.

Snapshot mode now includes each source at default/minimum sizes, scrolled inspector bottoms, all output sources and native color panels. tools/snap.sh activates its exact process through System Events, so multiple installed/test app instances do not select the wrong process. It requires an unlocked GUI, Screen Recording and System Events Accessibility.

No Orca workers were launched. Pre-existing untracked .agents/, .claude/ and skills-lock.json remain excluded. App source and detailed evidence are local; GitHub contains the README and self-contained phase issues.
