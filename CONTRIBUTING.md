# Contributing to OCTO iOS

Thanks for your interest in contributing to OCTO iOS! 🐙 We welcome contributions of all sizes.

> 🌐 **Read in**: **English** · [简体中文](CONTRIBUTING.zh.md)

## Getting Started

1. **Fork** the repo and create your branch from `main`.
2. **Install dependencies** — see the [README](README.md#-quickstart) for setup (`pod install`, `OctoConfig.xcconfig`).
3. **Make your changes** — follow existing code style and respect the constraints below.
4. **Test on a real device** when your change touches push notifications, gestures, or chat UI — Simulator can hide regressions.
5. **Update docs** — if behavior changes, update README / module READMEs.
6. **Open a Pull Request** — describe what & why; reference any related issue.

## Development Workflow

- All changes go through a Pull Request against `develop` (release PRs target `main`, see [RELEASE.md](RELEASE.md)).
- PRs require at least one approving review from a maintainer.
- We use **merge commit** for `develop → main` release PRs (preserve feature history) and **squash merge** for feature PRs into `develop`.
- No CI is wired up yet (contributions welcome). Until then, you're expected to build + smoke-test locally before requesting review.

## Self-Check Before Opening a PR

- [ ] Builds in **both** Debug and Release configurations
- [ ] Real-device regression for any change that touches push / background / gestures / chat UI
- [ ] Dark **and** Light appearance both look right
- [ ] No new `NSLog` of tokens, passwords, full HTTP headers, or full APNs `userInfo` (use `WKLog*` macros instead)
- [ ] No local-only configuration accidentally committed (AppKeys, Team ID, server hosts — all of these belong in `OctoConfig.xcconfig`, which is gitignored)
- [ ] No new `import` of GPL / LGPL code (the repo has no GPL/LGPL static deps after 2026-05 cleanup — keep it that way; see [NOTICE](NOTICE))

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(chat): add per-conversation custom Lobster prompt
fix(contacts): resolve duplicate entries on space switch
docs: clarify Universal Links setup
chore(deps): bump SDWebImage to 5.10
```

Scope is optional but encouraged — common scopes: `chat`, `contacts`, `login`,
`imsdk`, `push`, `aisummary`, `space`, `theme`.

## Pull Request Description

- Describe **what** changed and **why**.
- Reference any related issues (e.g. `Fixes #123`).
- Include screenshots / screen recordings for UI changes (light + dark if relevant).
- **Write PR descriptions in English** to keep the history accessible to the global community.

## Code Style

- **Objective-C**: 4-space indent, no tabs. One class per file. Public APIs documented in `*.h`.
- **Swift**: SwiftFormat / SwiftLint defaults (config to be added — until then follow the surrounding code).
- **Class prefix**: `WK*` is the historical prefix in the `WuKong*` modules (preserved from the upstream WuKongIM SDK and stays under MIT — see [LICENSE](LICENSE) note). New top-level classes in the main `Octo/` target can use any prefix that makes sense.
- **Asset names**: snake_case.

## License Hygiene

The repository ships fully Apache 2.0 — both source and binary. Please keep it that way:

- The **main app** (`Octo/`, extensions) and our own new code are **Apache 2.0**.
- The **`WuKong*` modules** are **MIT** (upstream WuKongIM SDK). Do not relicense or strip original attributions.
- **Do not add new GPL / LGPL / Affero dependencies** (CocoaPods or vendored source). The historical `TelegramUtils/` (GPL v2) and `SoundTouch` (LGPL v2.1) have been removed; adding new strong-copyleft code would reintroduce binary-distribution obligations.

Look at [CLAUDE.md](CLAUDE.md) for additional engineering constraints (e.g. swizzle whitelist, debug-tool lifecycle).

## Reporting Bugs

Open a GitHub issue using the **Bug Report** template (when available) or include:

- Expected vs actual behavior
- Steps to reproduce (including chat-related preconditions: 1:1 / group, message type, …)
- Environment: iOS version, device model, app build
- Logs / screenshots / screen recording (please redact tokens)

For **security-sensitive issues**, follow [SECURITY.md](SECURITY.md) — do not open a public issue.

## Suggesting Features

Open a GitHub issue using the **Feature Request** template. Explain the use case
and why existing features don't solve it. For larger feature work, open an
**RFC issue** first (≥ ~200 lines / API changes / architecture-affecting) so we
can align on direction before you spend implementation time.

## License

By contributing, you agree that your contributions will be licensed under the
project's [Apache License 2.0](LICENSE) for new code in the main app, or the
matching upstream license for changes to MIT portions.

## Questions?

- Open a [GitHub Discussion](https://github.com/orgs/Mininglamp-OSS/discussions)
- Browse the [OCTO Home](https://github.com/Mininglamp-OSS) for the full ecosystem

Thanks for helping make OCTO iOS better! 🚀
