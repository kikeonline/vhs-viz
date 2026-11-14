# Phase 7 automated evidence — 2026-11-14

See ../../PHASE-7-VERIFICATION.md for results and the separate attended acceptance.

- tests.log: `tools/test.sh`, 100 passing functions, including actual GPU fixtures.
- build.log: `./build.sh --debug`, locally signed app.
- mapping-selftest.log / input-selftest.log: isolated app model actions.
- mappings-layout-run.log / mappings-grid.log / layouts/: 84 measured states/toolbar layouts, with every image capture skipped.
- plugin-ui.log / plugin-layouts/: native embedding/mapping/recall/lifetime harness and eight layout files, images skipped.
- vst3.log: actual processor/state tests and SDK validator (47 passed / 0 failed), local arm64 artifact/signature checks.
- source-checks.log: grid lint, Signal resource/style check, diff whitespace check, strict app signature, Info.plist and dylib dependency inspection.

These are fixture logs and geometry, with no screenshots, hardware capture, permissions, Studio One session or attended keyboard/accessibility evidence. User data and installed applications/plug-ins were not replaced.

Recorded text logs have trailing whitespace removed; result text is unchanged.
