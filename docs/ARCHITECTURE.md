# Architecture Review

Notes from an initial review of the codebase (upstream: [Sean10000/LaunchManager](https://github.com/Sean10000/LaunchManager)) before adopting it as the base for this fork. Written for future-me and anyone else picking this project back up.

## Overview

A native SwiftUI macOS app (Swift 5.10, macOS 14+, no third-party dependencies) that manages `launchd` LaunchAgents/LaunchDaemons, Homebrew Services, crontab entries, and gives a Docker-aware view of local listening ports. ~7,700 lines of app code, ~1,500 lines of tests (92 test functions), MIT licensed.

## Layering

The app follows a straightforward, consistently-applied layered structure:

```
Views/  →  Store/  →  Services/  →  Models/
(SwiftUI)  (@MainActor        (shell-outs,    (plain structs/enums,
            ObservableObject)  file I/O,       Codable-ish data)
                                privilege esc.)
```

- **Models** (`LaunchManager/Models/`) — plain value types: `LaunchItem`, `CronJob`, `HomebrewService`, `Service`, etc. No behavior beyond simple computed properties.
- **Services** (`LaunchManager/Services/`) — one struct/enum per external system, each doing exactly one job: `LaunchctlService` (wraps `launchctl`), `PlistService` (scan/parse/write/delete plist files), `CrontabService`/`CrontabParser`, `BrewServicesService`, `Docker/DockerContainerService`, `PrivilegeService` (admin-privileged `do shell script` via AppleScript), `ShellRunner` (thin `Process` wrapper behind a protocol, making shell calls mockable in tests). Services are dependency-injected into Stores via initializer defaults (e.g. `AgentStore(plistService:launchctlService:privilegeService:)`), so tests can swap in fakes without touching production code.
- **Stores** (`LaunchManager/Store/`) — `@MainActor final class ... ObservableObject` per domain (`AgentStore`, `CrontabStore`, `HomebrewServiceStore`, `ServiceStore`). Hold `@Published` state, orchestrate multi-step operations (e.g. bootstrap → poll → refresh), and are the only layer Views talk to.
- **Views** (`LaunchManager/Views/`) — SwiftUI, read Store state via `@ObservedObject`/`@EnvironmentObject`, dispatch actions back to Stores. `ContentView.swift` is the `NavigationSplitView` root; `SidebarView` picks a section; each domain gets a `*ListView` + `*RowView` + edit `*Sheet`.

This separation is real, not superficial — Services have zero SwiftUI imports and Stores have zero direct `Process`/shell calls, which is what makes the unit tests possible (parsing/roundtrip logic is tested without ever touching an actual `launchctl` or the filesystem's real plist directories, via `scopeDirectoryOverrides` and mock `ShellRunner`s).

## Concurrency

- Stores are pinned to `@MainActor`; long-running work is wrapped in `Task { }` from Store methods, keeping UI updates safe by construction.
- `AgentStore.runLaunchctl` is a deliberate fork: non-privileged operations run via `Task.detached` (off the main thread), while privileged operations run synchronously on the main actor because the AppleScript admin-password prompt is itself modal — there's nothing productive the UI could do while it's up, so blocking there is a reasonable, if implicit, tradeoff rather than an oversight.
- `AgentStore.waitUntilStopped` polls with `Task.sleep` rather than a busy loop, with a bounded retry count and a `SIGKILL` fallback — sensible handling of the inherently asynchronous "did the process actually stop" question.
- `DirectoryWatcher` wraps FSEvents correctly: `Unmanaged.passUnretained` context pointer, matched `FSEventStreamStop/Invalidate/Release` in both `stop()` and `deinit`, and debounces callbacks via a cancellable `DispatchWorkItem` with `[weak self]`. No leaks or dangling-pointer risk spotted.

## Privilege escalation

System-scope operations (`/Library/LaunchDaemons`, `/Library/LaunchAgents`) go through `PrivilegeService.run(_:)`, which shells out via:

```swift
NSAppleScript(source: "do shell script \"...\" with administrator privileges")
```

This is the standard, expected macOS mechanism for this class of tool — no private APIs or exotic escalation tricks. Every call site builds its shell command as a plain string, so **path/argument quoting is the whole security model here**: every privileged call site is expected to run its interpolated values through the local `shellQuote()` helper (`'` + escape embedded `'` + `'`) before splicing them into the command. `LaunchctlService`, `BrewServicesService`, and most of `PlistService` do this consistently. `PlistService.delete()` was the one exception — see Findings below (fixed in a separate PR on this branch's base).

## Testing

92 XCTest functions concentrated on the parts most worth unit-testing: plist parsing/roundtrip (calendar/interval/watch-path triggers, environment variables, working directory, extra-key detection for the Form/XML mode split), `launchctl list` output parsing, disabled-label parsing, and crontab parsing. This is the right place to spend test budget in an app like this — the SwiftUI views are thin and mostly untested, which is a reasonable tradeoff, not a gap.

## Findings from this review

1. **Fixed (see PR on `fix/plist-delete-shell-quote`):** `PlistService.delete()` interpolated `item.plistURL.path` into a privileged shell command without `shellQuote()`, unlike every other privileged call site in the same file. Impact: breaks deletion for paths with spaces/metacharacters, and is a latent shell-injection surface if a crafted `Label` ends up in a privileged plist's filename (arbitrary shell execution as root). One-line fix: reuse the existing `shellQuote()` helper.
2. **No other correctness bugs found.** No unsafe force-unwraps anywhere in the codebase (the two `!` occurrences are both guarded by an adjacent nil-check in the same expression). No retain-cycle smells — `[weak self]` is used consistently in the handful of long-lived closures that need it.
3. **Security posture is clean.** The only network calls are to `api.github.com` (self-repo release-version check for the update notifier — never auto-downloads/executes anything, just surfaces a link), the project's own `launchmanager.dev/help`/`/templates` pages (opened in the user's default browser, never fetched in-app), and `localhost:<port>` (the app's own port-scanning feature). No telemetry, analytics, or crash reporting of any kind. No hardcoded secrets. CI (`.github/workflows/release.yml`) is a plain build → DMG → GitHub Release → Homebrew tap pipeline with no suspicious build-script phases.
4. **Localization is in good shape.** Base/source language is `zh-Hans`; the string catalog (`Localizable.xcstrings`) has real, natural-reading English translations for effectively every UI string (a handful of untranslated keys are technical terms identical in both languages, e.g. `"XML"`, `"Homebrew"`, `"PID"`). Spot-checked the longest/most technical strings for machine-translation artifacts — none found.

## Notes for building on this fork

- `main` tracks `upstream` (`Sean10000/LaunchManager`) for pulling in future upstream fixes/releases; `main-emmett` is this fork's own default branch for local changes and PRs.
- The `.github/workflows/release.yml` pipeline (DMG build, GitHub Release, Homebrew tap update) references `Sean10000/homebrew-tap` and assumes an `HOMEBREW_TAP_TOKEN` secret scoped to that repo — it won't do anything useful here until repointed at an equivalent of my own, or just disabled if I don't need a public release pipeline.
- `DeveloperSettings.xcconfig` (gitignored, copy from the `.example`) is where to put a personal `DEVELOPMENT_TEAM` for proper code signing instead of the ad-hoc signing CI uses.
