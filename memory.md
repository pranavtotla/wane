# Memory

## Invariants
- Implement work in plan order, phase by phase.
- Use small TDD chunks: tests first, then code, then fix.
- Keep commits small and focused.
- Keep `status.md`, `memory.md`, `session.md`, and `scratchpad.md` updated.

## Environment Facts
- Repo branch: `cursor/docs-plan-implementation-1464`
- Swift toolchain not installed in current Linux VM (`swift` command missing).
- All `swift build` / `swift test` verification attempts are blocked until Swift is installed.

## Technical Decisions
- Use conditional compilation for AppKit/SwiftUI-specific code to keep module portable in non-macOS environments.
- Store provider tint as hex in core model (`tintHex`) and expose SwiftUI color only when SwiftUI is available.
- Keep provider parsing/data logic in Foundation-only code paths so unit tests remain straightforward once Swift toolchain is available.
