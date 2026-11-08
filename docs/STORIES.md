# VHS stories

Phase 1 approved on 2026-11-08. Later phases remain in PLAN.md.

## Phase 1 — Runnable native core

### S-001 Launch the control window
As a performer, I launch VHS and see a solid scene beside its color controls.
Screens: control-light.png, control-dark.png, control-minimum-light.png, control-minimum-dark.png
Acceptance:
- [self] Metal initializes and the live display loop runs without error.
- [snap] A native title bar, live preview, source description, and three labeled color sliders fit at default and minimum sizes.
- [snap] Light and dark modes use readable semantic system colors.
UX:
- Flow: launch VHS → Untitled Scene with Solid selected → adjust inline controls.
- Surface: one control window; no sidebar for the single source available in Phase 1.
- States: initialized scene appears immediately; Metal failure shows Unable to Render and the actionable error in the preview.
- Words: Live Preview, Source, Solid, Color, Red, Green, Blue.
- Access: native slider labels and values; natural keyboard focus order; no automatic text selection.
Status: done

### S-002 Change the solid color
As a performer, I move the color sliders and see the scene update immediately.
Screens: control-light.png, control-dark.png, output.png
Acceptance:
- [unit] Reducer changes the requested component without mutating the original snapshot or seed.
- [unit] Out-of-range and nonfinite component values are bounded safely.
- [self] Changed scene values reach the live frame and GPU readback.
UX:
- Flow: focus or drag Red, Green, or Blue → both views update → release commits the gesture.
- Surface: inline sliders with visible 0–1 numeric values, working in linear RGB.
- States: values have useful initial settings; boundaries are constrained by native controls.
- Words: component names remain the same in visible and accessibility labels.
- Access: keyboard-adjustable native sliders; meaning also conveyed by labels and numeric values.
Status: done

### S-003 Undo a color edit
As a performer, I undo or redo one committed edit, including a complete slider drag.
Screens: control-light.png
Acceptance:
- [unit] A multi-update drag produces one undo entry.
- [unit] Undo restores the initial value and redo restores the edited value.
- [unit] A new branch clears redo; no-op changes preserve history; undo during a drag commits then reverses it.
- [self] Published Undo/Redo availability and Command-Z/Shift-Command-Z dispatch follow current history, including after menu refresh.
UX:
- Flow: Edit > Undo Color Change or Command-Z → previous color; Shift-Command-Z → edited color.
- Surface: standard Edit menu; unavailable actions remain disabled.
- States: empty history disables Undo; branching disables Redo.
- Words: Undo Color Change, Redo Color Change.
- Access: keyboard shortcuts remain available from either window.
Status: done

### S-004 Open and reopen the performance output
As a performer, I show a separate output window and keep it live while editing.
Screens: output.png
Acceptance:
- [self] Show Output opens a resizable window with a live Metal surface.
- [self] Closing releases its surface and reopening preserves the current scene.
- [self] Resizing does not produce render errors.
- [snap] The output content contains only the scene.
UX:
- Flow: toolbar Show Output or Window > Show Output or Command-Shift-O → output; close → control remains; Show Output → same scene.
- Surface: separate native window because the content stays open beside the controls.
- States: existing output is brought forward rather than duplicated; closing stops its display loop.
- Words: Show Output, VHS Output, Show Control Window.
- Access: Show Control Window (Command-1) returns focus to the editor; native close, resize, and fullscreen affordances.
Status: done

### S-005 Render a deterministic frame
As a developer, I render a known scene at a fixed time and verify actual GPU pixels.
Screens: output.png
Acceptance:
- [unit] Fixed seed/time and scene produce repeatable GPU readback.
- [unit] All pixels match expected sRGB output within one code value, including non-square and resized textures.
- [unit] Black and white fixtures have exact opaque endpoints.
- [self] Live rendering runs alongside the shared-clock timer without GPU waits on the UI path.
UX:
- Surface: command-line test suite; no test or technical controls in the performance flow.
Status: done

### S-006 Build and inspect VHS repeatedly
As a developer, I build, launch, self-test, and snapshot VHS through documented commands.
Screens: control-light.png, control-dark.png, output.png, VHS-icon.png
Acceptance:
- [self] Release packaging includes the shader resource bundle and compiled icon.
- [snap] Icon reads in Default, Dark, Tinted, Clear, and small renditions.
- [self] Snapshot mode writes real-window PNGs and layout probe files then exits.
- [self] Grid lint and layout checks pass.
UX:
- Flow: build.sh → app bundle; tools/selftest.sh → checks; tools/snap.sh → snapshots.
- Surface: scripts outside the normal UI; errors exit nonzero.
Status: done

## Verification record

Phase 1 acceptance checks passed. See [PHASE-1-VERIFICATION.md](PHASE-1-VERIFICATION.md) for evidence and manual checks not performed. Later-phase stories have not been started.
