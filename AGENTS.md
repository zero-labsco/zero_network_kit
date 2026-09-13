# Zero Network Kit - Agent Guide

This file defines the architecture, coding conventions, and required workflows for the `zero_network_kit` Flutter plugin. AI coding agents (CodeBuddy, Trae, Cursor, Claude Code, GitHub Copilot, Codex, etc.) should read and follow it for any task in this repository. It is the single source of truth for project conventions.

## Overview
`zero_network_kit` is a Flutter plugin for **network diagnostics** on Android and iOS: connectivity inspection, latency probing, DNS resolution, port checks, bandwidth measurement, weighted quality scoring and micro-benchmarks. Integration is one optional line (`ZeroNetworkKit.init()`); every capability is exposed through static APIs, so it also works with zero setup. Most of the logic is plain Dart, so it is injectable and testable without touching the network.

## When to apply
- Implementing features, fixing bugs, or changing the public API in `lib/`.
- Opening pull requests (titles must follow Conventional Commits; 3 status checks are required to merge).
- Cutting a release or publishing to pub.dev.
- Updating the GitHub Pages documentation site under `website/` (built into `docs/` by the pre-commit hook).
- Editing `pubspec.yaml`, the workflows under `.github/workflows/`, or the native Android/iOS code.

## Architecture
- `lib/zero_network_kit.dart` - public barrel; re-export the public API only. Add new public symbols here. Also hosts the `ZeroNetworkKit` entry class (`init()`, `dispose()`, `getPlatformVersion()`, `getNativeNetworkDetails()`).
- `lib/zero_network_kit_platform_interface.dart` - `ZeroNetworkKitPlatform` abstract base (token-verified, `plugin_platform_interface`).
- `lib/zero_network_kit_method_channel.dart` - default `MethodChannel` implementation on channel `zero_network_kit` (`getPlatformVersion`, `getNetworkDetails`).
- `lib/src/` - 21 implementation files grouped as: `models/` (benchmark_result, dns_test_result, network_connection_info, network_diagnostic_report, network_quality_score, network_type, ping_result, port_check_result, speed_test_result), `services/` (benchmark_service, connectivity_service, dns_service, ping_service, port_service, quality_evaluator, quality_service, speed_test_service), `dns/` (dns_packet), `utils/` (network_config). Do not import `lib/src/` directly from consumers.
- Facade entry points in `lib/src/`:
  - `network_diagnostic.dart` - the `NetworkDiagnostic` static API (`checkConnection`, `onConnectivityChanged`, `ping`, `resolve`, `runSpeedTest`, `checkPort`, `scanPorts`, `evaluateQuality`, `diagnose`, `configure`, `reset`). It holds the swappable service instances.
  - `network_benchmark.dart` - the `NetworkBenchmark` static API (`runAll`, `runSuite`) measuring how fast the diagnostics API itself runs.
- How features work:
  - Connectivity via `connectivity_plus` (through an injectable `ConnectivityAdapter`) plus the native channel for IP / gateway / VPN / SSID / BSSID / RSSI only obtainable from system services.
  - Ping is a TCP handshake RTT probe by default (`PingMode.tcp`), with an optional system ICMP binary on desktop (`PingMode.icmp`).
  - DNS uses the system resolver and/or raw UDP queries against explicit servers, encoded/decoded by the pure-Dart `DnsPacket` wire-format codec.
  - Speed test streams download/upload traffic against configurable endpoints with `SpeedTestProgress` callbacks.
  - Quality scoring is a pure function (`NetworkQualityEvaluator`) over the available metrics; `QualityService` gathers them.
- Native: Android `android/src/main/kotlin/com/zerolabsco/zero_network_kit/ZeroNetworkKitPlugin.kt` (package `com.zerolabsco.zero_network_kit`); iOS `ios/Classes/ZeroNetworkKitPlugin.swift`. The native side only supplements what the system requires; keep changes minimal and matching the method channel contract.

## Dependencies and SDK constraints
- Dart SDK: `>=3.11.0 <4.0.0`; Flutter: `>=3.3.0` (from `pubspec.yaml`). CI pins Flutter `3.41.7` so `dart format` output is identical everywhere.
- Runtime deps: `plugin_platform_interface`, `connectivity_plus`, `http`. Keep the caret (`^`) constraint on pub dependencies; do not pin exact versions without reason.
- Dev deps: `flutter_test`, `flutter_lints` (v6). Analysis is governed by `analysis_options.yaml`.
- License: MPL-2.0 (Mozilla Public License 2.0). Do not relicense without the maintainer's explicit decision.
- Platform pattern: define the abstract API in the platform interface, provide the `MethodChannel` default, register it in the barrel, and re-export any new public symbols from `lib/zero_network_kit.dart` only.
- **Injectability is a hard requirement**: every service must accept its collaborators (`ConnectivityAdapter`, `http.Client`, other services) through the constructor so the entire test suite runs hermetically. Never introduce a hidden global client or a direct `dart:io` dependency in a service that must be unit-testable.

## Coding conventions
- Follow `effective_dart`; style is enforced by `flutter analyze` / `flutter_lints` (v6) in CI.
- Use Conventional Commits for both commit messages AND PR titles: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, `build:`, `ci:`, `chore:`, `revert:`.
- Do not break the public API without a major version bump.
- Prefer immutable value objects with `toMap()` / `fromMap()`; derived statistics (averages, jitter, stddev, ops-per-second) belong on the model, not in call sites.
- **Graceful degradation**: a missing permission or an unreachable sub-service must never throw through the public API; the affected field stays `null` and the rest of the result is still returned.
- Keep public doc comments **English-primary with a short Chinese summary** (matching the existing bilingual convention in `lib/`).

## Workflows

### Branching and PRs
- Branch from `main` with a typed prefix: `feat/`, `fix/`, `docs/`, `ci/`, `chore/`, etc.
- Never push directly to `main`; it is branch-protected and requires 3 passing status checks to merge.
- PR titles MUST follow Conventional Commits, enforced by `pr-title-check.yml` (`amannn/action-semantic-pull-request@v6`).
- Required checks before merge: `Analyze & Test`, `Pana Score Check`, `Check PR Title (Conventional Commits)`.

### Pull request body template / PR 正文模板

AI coding agents (CodeBuddy, Trae, Cursor, Claude Code, GitHub Copilot, Codex, etc.) and contributors SHOULD follow the body template below when opening PRs. Keep the `###` section structure; fill in real content. Use English as the primary language and Chinese as the secondary language (EN-primary, ZH-secondary) for each section. Brand the assistant with **Zero Buddy** (two words, NOT "ZeroBuddy") at the end.

AI 协作工具（CodeBuddy、Trae、Cursor、Claude Code、GitHub Copilot、Codex 等）与贡献者开 PR 时应遵循以下正文模板。保留 `###` 章节结构并填入真实内容。每个章节采用英文为主、中文为辅（EN-primary, ZH-secondary）。文末以 **Zero Buddy**（两个单词，不要写成 "ZeroBuddy"）署名。

```markdown
### Summary / 摘要

<one-line plain-English summary> + <对应中文一句话摘要>

### Changes / 变更

- <change bullet, EN> / <中文说明>
- <change bullet, EN> / <中文说明>

### Context / 背景

<why this change is needed, EN> / <改动背景的中文说明>

### Checklist / 检查项

- [ ] Title follows Conventional Commits / 标题符合约定式提交
- [ ] CI checks pass after merge / 合入后 CI 通过

## Test plan

- [ ] <how to verify, EN> / <验证方式>

🤖 Generated with [Zero Buddy](https://www.zerolabsco.com)
```

Notes / 说明:
- The PR **title** stays English-only and MUST follow Conventional Commits (enforced by `pr-title-check.yml`). Bilingual content goes in the body only.
  PR **标题**仅用英文，且必须符合约定式提交（`pr-title-check.yml` 强制校验）。双语内容只放在正文。
- For Dependabot PRs, do NOT author the body manually — `dependabot-pr-bilingual.yml` auto-appends the bilingual summary (see CI section).
  Dependabot 的 PR 不要手动写正文，由 `dependabot-pr-bilingual.yml` 自动追加双语摘要（见 CI 段）。

### CI
- `ci.yml`: triggers on `push` to `v*.*.*` branches, `pull_request` to `main`/`v*.*.*`, `workflow_dispatch`, and `workflow_call` (reused by `pub-publish.yml`). Uses `actions/checkout@v7`, `subosito/flutter-action@v2` (pinned `flutter-version: '3.41.7'`), `actions/cache@v6` (pub cache keyed on `pubspec.lock` plus `example/pubspec.lock`). Runs `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` on both the plugin and the `example/` app, then a separate `Pana Score Check` job.
- `pana-check`: activates `pana`, runs with `--no-warning --json`, and **fails below a score of 120/130**. Keep this green when adding files or metadata.
- `path-filter` job: the `code` output decides whether the heavy jobs run. The `code` list contains **only code paths** (`lib/**`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `test/**`, `android/**`, `ios/**`, `example/lib/**`, `example/pubspec*.yaml`, `example/analysis_options.yaml`, `.github/workflows/ci.yml`). A docs/asset-only PR → `code=false` → both required jobs **skip green** (pana NOT run) so the PR still satisfies branch protection.
- **Never add `'**.md'` or `'docs/**'` to `paths-ignore`.** Doing so would skip the entire `ci.yml` workflow for docs-only PRs, leaving the branch-protection required checks permanently yellow and blocking merge. User-facing docs (`README*.md`, `README_zh.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `AGENTS.md`, `docs/**`, any other `**.md`) are intentionally NOT ignored.
- `stale.yml`: `actions/stale@v11` marks issues/PRs stale after 60 days of inactivity (issues close after 7 more, PRs after 14). `pinned`/`security`/`enhancement`/`bug` issues and `pinned`/`dependencies`/`wip` PRs are exempt.
- `dependabot-pr-bilingual.yml`: `actions/github-script@v9` appends a bilingual (EN-primary, ZH-secondary) summary to the **body** of Dependabot PRs only (`github.actor == 'dependabot[bot]'`, idempotent via marker). It does NOT touch the PR title or commit subject — those stay English per the Conventional Commits rule. When reviewing Dependabot PRs, verify the build passes, check changelogs for breaking changes on major bumps, and confirm the caret (`^`) constraint is preserved.
- `dart-format-fix.yml`: on PR `opened`/`synchronize`/`reopened` (and `workflow_dispatch` manual trigger), runs `dart format .` and, if it changed anything, auto-commits and pushes the fix back to the **same PR branch** as `github-actions[bot]`. Keeps style consistent without reviewer nudging. Note: uses `pull_request` (not `pull_request_target`) with `permissions: contents: write`; if branch protection blocks workflow pushes or requires signed commits, switch it to open a fix branch / post a comment instead.
- `link-check.yml`: on PR changes to `README.md`, `README_zh.md`, `CHANGELOG.md`, `docs/**` (and `workflow_dispatch` manual trigger), runs `lychee-action@v2` to scan those docs for dead/broken links and fails only on real broken links (mailto and common redirects/rate-limits are excluded). Use the Actions tab manual run to scan the default branch on demand.
- `pr-title-check.yml` details: allowed types are `feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert`; `requireScope` is `false`; PRs labeled `dependencies` or `github-actions` are ignored. The same type list applies to commit messages (Conventional Commits).
- **Line endings**: `.gitattributes` forces `eol=lf` for text files so `dart format` is idempotent across Windows (CRLF) and CI (Linux/LF). The `dart-format-fix` and `ci` jobs renormalize the tree to LF before formatting. Never let a CRLF blob reach the repository.

### Release and publish
1. Bump `version` in `pubspec.yaml` (semver; major bump for breaking public API).
   **Mandatory version-bump checklist — every one of these MUST be updated to the new version `X.Y.Z` (and the old version string removed). Missing any of them is a recurring, real mistake — verify each explicitly, do not assume a previous pass covered them:**
   - [ ] `pubspec.yaml` → `version: X.Y.Z`
   - [ ] `ios/zero_network_kit.podspec` and `macos/zero_network_kit.podspec` → `s.version = 'X.Y.Z'` (these are often stale; always check BOTH — only iOS and macOS use CocoaPods podspecs; Android/Linux/Windows derive the version from `pubspec.yaml` and need no manual bump)
   - [ ] `README.md`:
     - [ ] the `^X.Y.Z` dependency constraint in the install snippet
     - [ ] the `` `X.Y.Z` `` placeholder in "install from GitHub" (replace `X.Y.Z` with the version you need)
     - [ ] the `ref: release/vX.Y.Z` in the GitHub install git block (use the `release/vX.Y.Z` archive **branch**, NOT the `vX.Y.Z` tag — the tag collides with the branch refspec and breaks `git push`)
     - [ ] the "🔔 Upgrade recommended" callout — briefly summarize what the **current** release changed and recommend upgrading to the latest version (`^X.Y.Z`); it must **NOT** mention or reference previous versions. Each release, bump only the literal latest version token and update the one-line summary of the current change.
   - [ ] `README_zh.md`: same spots as `README.md` (`^X.Y.Z` dependency constraint, `` `X.Y.Z` `` placeholder, `ref: release/vX.Y.Z`, and the "🔔 推荐升级：" callout). The callout should briefly summarize what the current release changed and recommend the latest version; it must not reference previous versions.
   - [ ] `CHANGELOG.md`: add a new `## X.Y.Z` section at the top describing the changes (the format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)).
   - [ ] `website/pages/*.md`: the `__ZNK_VERSION__` placeholder is injected from `pubspec.yaml` automatically by the pre-commit hook — no manual edit needed, but confirm `docs/` rebuilds with the new version (committing the version bump triggers the hook).
   - **Changelog scope rule / 变更日志范围规则:** Only changes to `lib/` (i.e. published-package runtime behavior) earn a CHANGELOG entry. Pure documentation updates (`README*.md`, `docs/`, `AGENTS.md`, `CONTRIBUTING.md`) and `example/` changes must NOT get a CHANGELOG entry — they do not change the released package's runtime behavior. The single exception is a **pure version-bump commit**: bumping the version legitimately updates the CHANGELOG (and the doc version strings) as part of cutting the release, which is allowed. / 只有 `lib/` 的改动（即已发布包的运行行为）才进 CHANGELOG；纯文档（`README*.md`、`docs/`、`AGENTS.md`、`CONTRIBUTING.md`）与 `example/` 的改动不应写进 CHANGELOG——它们不改变发布包的运行行为。唯一的例外是「单纯 bump 版本」的提交：为发版而更新 CHANGELOG（及文档版本号）是允许的。
   - Grep sanity check before committing: `grep -rn "old_version" README.md README_zh.md docs website` must return NOTHING (only legitimate historical prose may remain).
2. Update `README.md` / `README_zh.md` / `CHANGELOG.md` as needed.
3. Locally verify before pushing:
   - `dart format .` — must report no changes. The `dart-format-fix.yml` CI workflow auto-commits any formatting diff back to the PR branch, so keep the tree formatted locally to avoid surprise commits.
   - `flutter analyze` — must pass with no errors.
   - `flutter test` — all unit tests green.
   - `flutter pub publish --dry-run` — confirm the package scores well on `pana` and no files are unintentionally excluded.
4. Commit on a branch, open PR, merge to `main` after the 3 required checks pass.
5. Tag (drives publishing): `git tag vX.Y.Z <commit> && git push origin vX.Y.Z`. The `vX.Y.Z` tag — NOT a branch — triggers `pub-publish.yml`. Never name a branch `vX.Y.Z`; it collides with the tag refspec and breaks `git push`.
6. Archive branch (optional, for release snapshots): create `release/vX.Y.Z` from the tagged commit via explicit refspec to avoid the tag/branch collision, e.g. `git push origin <commit>:refs/heads/release/vX.Y.Z`. These branches are inert (no CI triggers on them) and serve only as frozen snapshots.
7. `pub-publish.yml` runs on `push` of a `v[0-9]+.[0-9]+.[0-9]+` tag: it reuses `ci.yml` as a prerequisite (`ci-check`), then verifies the tag version matches `pubspec.yaml`, verifies `CHANGELOG.md` has a matching `## X.Y.Z` entry, runs `dart pub publish --dry-run`, publishes via `k-paxian/dart-package-publisher@v1.6` using the `PUB_CREDENTIALS_JSON` secret (fields `accessToken`, `refreshToken`; set `flutter: true`), and creates a GitHub Release from the extracted CHANGELOG block. Do NOT pass OIDC fields (`idToken` / `tokenEndpoint` / `scopes`); the action does not support them and emits invalid-input warnings.
   - Note: `k-paxian` internally uses older actions that emit Node 20 deprecation warnings. This is accepted; functionality is unaffected.
   - The CHANGELOG extraction uses portable `awk` (no gawk-only three-argument `match()`).

### Pub publish validation pitfalls
`dart pub publish` (run by `pub-publish.yml`) performs validation that FAILS the build on certain warnings. Re-verify with `flutter pub publish --dry-run` before tagging.

- **Checked-in file ignored by `.gitignore`** — Pub flags any file that is BOTH in the git index AND matched by `.gitignore`. Fix: do NOT try to solve this with `.pubignore` (pub's "checked-in but ignored" check ignores `.pubignore`); instead **untrack** the path so it is no longer "checked in" (`git rm -r --cached <path>`; the file stays on disk and remains gitignored). Keep `.codebuddy/` ignored in `.gitignore` — it is personal IDE data.
- **Top-level `docs/` directory (plural name)** — Pub warns that plural top-level dirs aren't recognized by its layout convention and suggests renaming to `doc/`. Do NOT rename: `docs/` is the GitHub Pages site (served from a Pages branch). Fix: exclude it from the package via `.pubignore` (`docs/`).
- **`.pubignore` usage** — `.pubignore` at repo root keeps repo-internal content out of the published tarball. Current entries: `docs/`, `.codebuddy/`, `wiki/`, `TODO.md`, `AGENTS.md`, `CONTRIBUTING.md`, `build/`. `.pubignore` is respected by `dart pub publish` but does NOT silence the "checked-in but gitignored" conflict above.

When re-tagging after a fix, force-update both the `vX.Y.Z` tag and the `release/vX.Y.Z` archive branch to the new commit so the publish job runs against the corrected tree.

### Documentation site (GitHub Pages)
- Source content lives in `website/` (Nextra + Next.js); the Markdown pages are in `website/pages/`.
- `docs/` is the **generated** static export (committed, served by GitHub Pages). It is produced automatically by the pre-commit hook (`website/scripts/sync-docs.mjs`) from `website/out/` — **do NOT hand-edit `docs/`**; edit `website/pages/*.md` instead.
- Version string: `website/pages/*.md` carry the placeholder `__ZNK_VERSION__`, which `sync-docs.mjs` replaces with the `version:` from `pubspec.yaml` at build time. Bumping the pubspec version alone triggers a rebuild so `docs/` picks up the new version.
- Hook setup (one-time, requires Node + `website/node_modules`): `cd website && npm install && npm run setup-hook` installs `.git/hooks/pre-commit`. It runs only when `website/` source **or** `pubspec.yaml` version changes (otherwise it is a no-op that exits 0, so normal code commits are unaffected).
- Publishing branch: `docs/github-pages`; GitHub Pages serves the `docs/` folder of that branch.
- Live site: https://zero-labsco.github.io/zero_network_kit/
- `pubspec.yaml` has a `documentation:` field pointing to the site (rendered on pub.dev). Keep it in sync after the site URL is stable.

## New feature development checklist
- [ ] Confirm the change against `effective_dart` and the existing `lib/src/` structure.
- [ ] Expose any new public symbol through `lib/zero_network_kit.dart` only.
- [ ] Keep every new/extended service constructor-injectable so tests stay hermetic; if it talks to the system, route it through the platform interface.
- [ ] Return immutable result objects with `toMap()` and degrade gracefully (no throws across the public API).
- [ ] Add or update unit tests under `test/`.
- [ ] Keep native Android/iOS changes minimal and matching the method channel contract.
- [ ] Run `dart format .`, `flutter analyze`, and `flutter test` locally before pushing.
- [ ] Use a typed branch (`feat/...`) and a Conventional Commits PR title.
- [ ] Ensure the 3 required status checks pass before requesting review/merge.
- [ ] For user-facing changes, update `README.md` / `README_zh.md` and the `website/` source (the `docs/` site is built and synced automatically by the pre-commit hook).
- [ ] For releases, bump `version` AND follow the **Mandatory version-bump checklist** under "Release and publish" above (pubspec, iOS and macOS podspecs, README.md, README_zh.md, `website/pages/*.md` via the `__ZNK_VERSION__` placeholder, CHANGELOG.md — grep for the old version string across `README*.md docs website` to confirm nothing is left). Tag `vX.Y.Z` (triggers publish), and optionally push a `release/vX.Y.Z` archive branch via explicit refspec.
