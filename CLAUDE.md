# LaunchManager (Emmett's fork)

## What this is

A native macOS SwiftUI app for managing `launchd` LaunchAgents/LaunchDaemons: browse, create, edit, and remove them, with toggles for common needs like run-on-login (`RunAtLoad`) and restart-if-stopped (`KeepAlive`), plus a Form/XML dual editor for anything more advanced. It also covers Homebrew Services, crontab entries, and a Docker-aware view of local listening ports.

This is a fork of [Sean10000/LaunchManager](https://github.com/Sean10000/LaunchManager) ([launchmanager.dev](https://www.launchmanager.dev)), adopted after a security/architecture review found it well-built, native Swift (not Electron/Tauri), and MIT licensed — a better starting point than building the same launchctl/plist/privilege-escalation plumbing from scratch.

## Goals for this fork

- Keep an easy, GUI-driven way to see all launchd items on the Mac, edit their settings, and add/remove them, without hand-editing plist files or running `launchctl` at the terminal.
- Track upstream (`Sean10000/LaunchManager`) for fixes and features where useful, while carrying local fixes and docs independently.
- Fix issues found during review as they come up (see `docs/`).

## Repo layout

- `main` — tracks `upstream` (`Sean10000/LaunchManager`), not committed to directly.
- `main-emmett` — this fork's own default branch; all local work and PRs target this.
- `docs/` — **check here first** for anything non-obvious about this codebase:
  - `ARCHITECTURE.md` — layering (Model/Service/Store/View), concurrency patterns, the privilege-escalation mechanism.
  - `FORK_NOTES.md` — fork-specific setup (branches, what doesn't carry over from upstream as-is, e.g. release CI).
  - `LOCALIZATION.md` — the app's base language is Chinese (`zh-Hans`); every UI string literal in the Swift source is Chinese text, resolved to English at runtime via Xcode's String Catalog. This is standard Swift/Apple practice, not a bug — read this file before being alarmed by Chinese text in a `.swift` file.
- Standard Xcode project otherwise: `LaunchManager/` (app source), `LaunchManagerTests/` (XCTest, ~92 tests concentrated on plist/launchctl/crontab parsing).

## Build & run

```bash
open LaunchManager.xcodeproj   # then ⌘R in Xcode
```
or headless:
```bash
xcodebuild -project LaunchManager.xcodeproj -scheme LaunchManager -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```
