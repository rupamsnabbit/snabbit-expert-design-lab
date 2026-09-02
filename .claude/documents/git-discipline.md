---
description: Git branching model and dual-PR workflow for KMP feature work. Loaded by review-changes skill.
---

# Git Discipline — Snabbit Runner KMP

## Branch Model

Feature branches always cut from `release` — it is the authoritative stable base.
Naming: `feat/kmp-<feature-name>` (e.g. `feat/kmp-language-screen`)

## Dual-PR Workflow (D4)

Every KMP feature ships two PRs from the same feature branch:

```
release  ──────────────────────────────────────────► (production)
   │                                                         ▲
   └── feat/kmp-<name> ──► PR-1 → integration  (merge immediately for QA builds)
                       └── PR-2 → release       (hold — merge only at ship decision)
```

**PR-1 → `integration`:** merge as soon as the feature is QA-ready. Triggers integration test builds.
**PR-2 → `release`:** keep open. Merge only when the feature is approved for production release.

If `release` advances (e.g. a hotfix lands) before PR-2 is merged: rebase the feature branch onto the latest `release` tip, then force-push. PR-2 updates automatically.

## PR Requirements

- Run `/review-changes` and resolve every FAIL item before opening PR-1 — mandatory, not optional
- Title format: `[KMP] <feature-name> — <what changed>`
- Both PRs must use `.github/PULL_REQUEST_TEMPLATE.md` — fill every section honestly
- Both PRs must pass CI before merge: `./gradlew :shared:testDebugUnitTest :shared:compileTestKotlinIosArm64`
