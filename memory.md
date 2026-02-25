# Memory

## Invariants
- Implement work in plan order, phase by phase.
- Use small TDD chunks: tests first, then code, then fix.
- Keep commits small and focused.
- Keep `status.md`, `memory.md`, `session.md`, and `scratchpad.md` updated.

## Environment Facts
- Repo branch: `cursor/docs-plan-implementation-1464`
- Swift toolchain not installed in current Linux VM (`swift` command missing).

## Technical Decisions
- Use conditional compilation for AppKit/SwiftUI-specific code to keep module portable in non-macOS environments.
