# Fork Notes

Practical notes on how this fork ([EmmettBudd/LaunchManager](https://github.com/EmmettBudd/LaunchManager)) of [Sean10000/LaunchManager](https://github.com/Sean10000/LaunchManager) is set up, for future reference.

## Branches

- `main` tracks `upstream` (`Sean10000/LaunchManager`) — used only for pulling in future upstream fixes/releases, never committed to directly.
- `main-emmett` is this fork's own default branch. All local work and PRs target this branch, keeping it cleanly separate from `main` so upstream can still be merged in later without conflict noise.

## Things that don't carry over from upstream as-is

- `.github/workflows/release.yml` (DMG build → GitHub Release → Homebrew tap update) references `Sean10000/homebrew-tap` and expects an `HOMEBREW_TAP_TOKEN` secret scoped to that repo. It won't do anything useful here until it's repointed at an equivalent tap of my own, or just disabled if a public release pipeline isn't needed.
- `DeveloperSettings.xcconfig` (gitignored; copy from `DeveloperSettings.xcconfig.example`) is where a personal `DEVELOPMENT_TEAM` goes for proper code signing, instead of the ad-hoc signing the CI script uses.
