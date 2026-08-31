# Localization

## The base language is Chinese

This app's development/base language is **Simplified Chinese (`zh-Hans`)**, not English. Every UI string literal in the Swift source — `Text("检查更新…")`, `Label("从 XML 粘贴…", ...)`, etc. — is written in Chinese. This note exists so that's never a surprise when opening a view file: it's not broken, obfuscated, or a mistranslation artifact, it's just which language the original author happened to write the app in. English translations are complete and were spot-checked as part of this fork's initial review — see `git log` for the review that preceded this fork.

## How the string lookup works

Apple's localization tooling — both the older `.strings` files and the newer String Catalog (`.xcstrings`) format this project uses — has long defaulted to using **the literal display text itself as the lookup key**, rather than a separate abstract identifier. Concretely:

- SwiftUI's `Text`, `Label`, `Button`, etc. take a `LocalizedStringKey`, and `String(localized:)` works the same way. Xcode automatically scans the source for these and extracts every literal it finds into `LaunchManager/Localizable.xcstrings` — no manual registration step.
- At runtime, the framework looks up the literal in the catalog and swaps in the translation for the current system language. On an English system, `Text("检查更新…")` renders as "Check for Updates…" because the catalog maps that exact Chinese string to that English value.
- Because the base language is Chinese here, the Chinese text acts as both the "key" and the fallback (what renders if a translation is ever missing) — for a project with English as the base language, the English text would play that same dual role instead.

This is standard, idiomatic Swift/Apple platform practice, not something specific or unusual about this project. It differs from Android's `strings.xml`, where every string gets an abstract key (`R.string.check_for_updates`) that's separate from the displayed text in any language — Apple's tooling generally skips that indirection.

## Where to look things up

- `LaunchManager/Localizable.xcstrings` is a plain JSON file — every Chinese string in the source has an entry there with its English translation under `"localizations" → "en"`.
- Xcode's String Catalog editor (open the `.xcstrings` file in Xcode) gives a searchable table view of the same data if JSON isn't convenient.
