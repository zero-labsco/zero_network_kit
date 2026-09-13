# Contributing to zero_network_kit

Thanks for taking the time to contribute! This document describes the workflow
we follow. For the full engineering contract — architecture, conventions, release
process and the new-feature checklist — read [AGENTS.md](AGENTS.md) first.

## Requirements

- Flutter `3.41.7` (pinned so `dart format` output is identical everywhere)
- Dart SDK `>=3.11.0 <4.0.0`

## Local checks (must pass before opening a PR)

```bash
flutter pub get
dart format --set-exit-if-changed lib/
flutter analyze lib/
flutter test
```

Example app:

```bash
cd example
flutter pub get
dart format --set-exit-if-changed lib/ test/
flutter analyze lib/
flutter test
```

Integration tests hit the real network and therefore never run in CI. Run them
manually against a device when you touch native code:

```bash
flutter test integration_test -d <device-id>
```

## Branch & PR workflow

1. Branch from `main` using a descriptive name, e.g. `feat/ipv6-probe`.
2. Keep the change focused; one logical change per PR.
3. **PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/)**
   and are validated by CI. Allowed types: `feat`, `fix`, `docs`, `style`,
   `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
4. Ensure `Analyze & Test` and `Pana Score Check` are green. `Pana Score Check`
   enforces a minimum pub.dev score of `120/130`.
5. Update `CHANGELOG.md` under `## [Unreleased]` (or the version you are
   releasing) whenever behaviour changes.

## Commit messages

Short, imperative, English. Real examples:

```
feat(ping): support ICMP mode on desktop platforms
fix(dns): guard against compression pointer loops
docs(readme): document the quality score weighting
```

## Code style

- `dart format` is authoritative; the `Dart Format Auto-Fix` workflow commits
  formatting fixes for you, but please run it locally too.
- Keep the public API documented in **English** with a short **Chinese** summary
  line, matching the existing bilingual doc-comment convention.
- No new `// ignore:` unless there is a comment explaining why.
- Never introduce a dependency without checking its pana/lint impact.

## Reporting bugs

A good bug report contains:

- Flutter / Dart version and the plugin version
- Target platform(s) and OS version
- A minimal reproduction (ideally a failing test or a snippet using
  `NetworkDiagnostic`)
- Expected vs. actual behaviour
