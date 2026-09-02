# Contributing & PR Guidelines — snabbit-runner-app

These guidelines apply to **every PR** raised to this repo. The code-level rules live in
[`CLAUDE.md`](CLAUDE.md); the testing philosophy lives in [`COVERAGE_STRATEGY.md`](COVERAGE_STRATEGY.md).

## Branches & commits
- Branch from `main`. Name it `<type>/<JIRA-KEY>-<short-slug>`, e.g.
  `fix/ECPO-173-new-job-login-button`, `feat/SNCON-92-payout-card`.
  Types: `feat`, `fix`, `refactor`, `chore`, `ci`.
- Write imperative commit subjects (`fix: rebuild widgetUtil on cache-apply`). Reference the Jira key.
- Keep PRs focused — one logical change. Split unrelated cleanups into their own PR.

## Before you open a PR
Run the local checks (see the [`Makefile`](Makefile)):

```bash
make analyze          # static analysis on your changes
make format           # auto-format the Dart you touched
make test             # run the suite
make test-my-changes  # coverage for just your changed lines  ⭐
```

Then fill in the PR template (it loads automatically from
[`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md)) — summary, Jira key, the
checklist, **how to test on a device**, and screenshots/recording for any UI change.

## What CI runs on your PR
[`.github/workflows/flutter-ci.yml`](.github/workflows/flutter-ci.yml) runs one lightweight check on every PR:

| Check | Job result | Blocks merge? |
|-------|-----------|---------------|
| `dart format` on **changed** Dart files | Fails (red ✗) if unformatted — fix with `make format` | No\* |

> **\* Nothing in CI blocks a merge today.** `main` is governed by a GitHub *ruleset* whose only
> merge requirement is **1 approval** (enforced org-wide — same as maestro-core, which also keeps all
> its CI advisory). A red ✗ does **not** prevent merge until this job is added as a **required status
> check** (*Settings → Rules → Rulesets → main → Require status checks*).
>
> **Run the fuller checks locally** before a PR: `make analyze`, `make test`, `make test-my-changes`.
> `analyze`/`test` are deliberately kept out of CI for now — the repo has pre-existing debt (~880
> analyzer issues, some failing tests) that would make them noisy, non-actionable signal. Add them
> to CI (and make them required) once that debt is burned down.

The existing [`firebase-debug-apk-main.yml`](.github/workflows/firebase-debug-apk-main.yml) also
builds & distributes a debug APK on PRs to `main`/`release`.

## AI review on a PR
Comment one of these on the PR:

- **`/claude-review`** — project-aware automated review (reads `CLAUDE.md`). Covers crash/leak risks
  (silent catches, undisposed controllers, missing `mounted` guards), correctness on API data
  (`anyValueToInt`/`anyValueToDouble`), and conventions (ScreenUtil `.r`, `AppColors`, RemoteConfig
  safe defaults / Shorebird kill-switches, `MonitoringServiceHelper` logging). Posts inline comments
  ([`claude-code-review.yml`](.github/workflows/claude-code-review.yml)).
- **`@claude <question>`** — ask Claude to explain, fix, or change something
  ([`claude.yml`](.github/workflows/claude.yml)).

These are review aids, not a substitute for a human approval.

## Review & merge
- At least **one human approval** before merge.
- Resolve the blocking format check and address (or explicitly justify) review findings.
- Squash-merge keeping a clean, Jira-referenced title.

## Required repo secrets
The CI and AI-review workflows need these configured under *Settings → Secrets and variables → Actions*:

- `GH_APP_CICD_ID`, `GH_APP_CICD_PRIVATE_KEY` — GitHub App used to fetch private git
  dependencies (`comm_stream`, `safety_shield`, `network_info_plugin`). Already used by the
  existing build workflows.
- `CLAUDE_CODE_OAUTH_TOKEN` — required by the three Claude review workflows. If it isn't set,
  those workflows will fail when triggered (the rest of CI is unaffected).
