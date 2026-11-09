# VHS checkpoint

Phases 1–2 are implemented and functionally verified. See PHASE-1-VERIFICATION.md and PHASE-2-VERIFICATION.md for evidence and manual verification limits. The release app is installed at ~/Applications/VHS.app. Phase 3 has not started; wait for user direction.

Phase 2 adds versioned .vhsproject JSON, an off-main-actor file store with atomic sibling replacement, document dirty baselines, native file dialogs, Rename, and save/discard/cancel for New/Open/close/quit. Finder-style cold launch is verified, including rendered preview pixels. Both Metal surfaces are explicitly drawn from the common frame timer; the self-test checks increasing drawable counts. Filename is authoritative on open; saved Rename moves the file without overwriting another project. Sources remain Solid only.

Use AGENTS.md and README.md for commands. Commands remain in SwiftUI's menu tree with observed availability. GitHub #10 remains open for VoiceOver, keyboard-only slider navigation, Increase Contrast, actual menubar inspection, and macOS 26 runtime verification. Current verification ran on macOS 27.2.

No Orca workers were launched for the integrated core or persistence lifecycle. Existing untracked .agents/, .claude/, and skills-lock.json predate implementation and remain excluded from commits. Source and detailed reports remain local; GitHub contains the README and phase issues.
