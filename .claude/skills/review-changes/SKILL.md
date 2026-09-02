---
name: review-changes
description: Review KMP changes across architecture, concurrency, and UI dimensions using specialist subagents. Use before opening a PR or when reviewing a teammate's PR on the shared module.
---

# Review Changes — Snabbit Runner KMP

## When to Use
- Before opening your own PR: `/review-changes`
- Reviewing a teammate's PR: `/review-changes <branch-or-PR-url>`

## When NOT to use
- Building / scaffolding a feature or screen → **build-feature**.
- Files outside `shared/` (Flutter/Dart) → the existing Flutter review checklist, not this skill.

## Before Reviewing — Read These

1. `.claude/documents/core-facts.md` — ViewModel pattern, one-shot effects, AppErrorType, SnabbitScreen
2. `.claude/documents/feature-template.md` — folder structure, MVI contract, collapse rules
3. `.claude/documents/git-discipline.md` — branch model, dual-PR requirements
4. `.claude/documents/component-catalog.md` — canonical DS component reference (UI dimension)

---

## STEP 1 — Identify Scope
List every changed file in:
- `shared/src/commonMain/`
- `shared/src/commonTest/`

Ignore files outside `shared/` for KMP rules — Flutter rules in the existing checklist apply to those.

---

## STEP 2 — Fan Out to Specialist Subagents (run in parallel)

Invoke all three against the changed files. Each checks one dimension only.

| Subagent | File | Dimension |
|---|---|---|
| Architecture | `.claude/agents/architecture-reviewer.md` | Layer structure, AppErrorType, Koin, folder layout |
| Concurrency | `.claude/agents/concurrency-reviewer.md` | viewModelScope, AppDispatchers, state updates, CancellationException, one-shot effects |
| UI | `.claude/agents/ui-reviewer.md` | SnabbitScreen, DS components, collectAsStateWithLifecycle, UiState structure |

---

## STEP 3 — Aggregate Verdict

| Result | Condition |
|---|---|
| **PASS** | All three subagents return no violations |
| **FAIL — must fix before merge** | Any subagent flags one or more violations |

For every FAIL item list: file path · line number · rule violated · exact fix required.
Do not mark review complete with any open FAIL item.

---

## STEP 4 — Git Discipline Check
Verify against `git-discipline.md`:
- [ ] Branch cuts from `release`
- [ ] Branch named `feat/kmp-<name>`
- [ ] Dual-PR plan in place: PR-1 → `integration`, PR-2 → `release`
- [ ] CI passes: `./gradlew :shared:testDebugUnitTest :shared:compileTestKotlinIosArm64`
