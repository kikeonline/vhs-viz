# VHS

Native Swift 6/macOS 26+ app. Follow docs/BRIEF.md, docs/STORIES.md, and docs/PLAN.md. Build only the approved phase.

- `./build.sh --debug` builds a local signed app at build/VHS.app; `--install --open` installs to ~/Applications and opens it.
- `tools/test.sh` runs state and actual Metal GPU fixture tests with full Xcode selected locally.
- `tools/selftest.sh` runs app actions and output-window lifecycle checks on ephemeral state.
- `tools/snap.sh` captures control default/minimum sizes in light/dark and the output. Needs GUI, Screen Recording, and System Events Accessibility access; activates the exact snapshot process.
- `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/VHS-shots/*-layout.json` check layout.
- `tools/icon_review.sh` renders all icon appearances and small sizes.

Design rules: design/DESIGN-SYSTEM.md. Use its tokens; never raw colors, radii, or durations for app UI. User scene colors are content.

VHSCore owns immutable snapshots, reducer, value history, and clock. VHSRenderer owns the shared device/queue/pipeline. AppModel owns the common frame, UI state, and output lifecycle. Live rendering never waits for GPU completion. Synchronous readback is for tests only.

After changing commands, check actual Edit menu enablement before/after a slider edit, Command-Z and Shift-Command-Z, Show Output, closing/reopening output, and Command-1 from output. Do not infer menu correctness from snapshots alone. Record any manual checks not performed.
