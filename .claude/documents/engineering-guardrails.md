---
description: Hard anti-over-engineering guardrails for :shared KMP work. Loaded by build-feature. Enforced at Gate 7.
---

# Engineering Guardrails — No Over-Engineering

Deliver exactly what the task needs. Simplicity is a requirement, not a preference.

## Rules (enforced)

| # | Rule | Reject when |
|---|------|-------------|
| G1 | **YAGNI** — build only what a confirmed requirement needs. | A field/param/branch/screen exists "for later" with no current caller. |
| G2 | **No speculative layers** — add `domain/` (UseCase/Repository), interfaces, or mappers only when they carry real logic. | A layer just forwards calls (pass-through UseCase, 1:1 mapper, single-impl interface with no seam need). Collapse per `cmp-architecture-structure.md`. |
| G3 | **No premature generalization** — concrete first. | A `<T>`/config/strategy/abstract base with one concrete use. |
| G4 | **Match existing patterns** — reuse the established seam/DS/state approach; don't introduce a parallel one. | A new mechanism duplicates one already in the repo. |
| G5 | **Stable dependencies** — prefer stable releases; a pre-release (alpha/beta/rc) or `[TBD]`-version dep needs explicit engineer approval recorded in the PR/plan. | An alpha/beta/rc lib added without a recorded, approved reason. |
| G6 | **Minimal state** — a UiState field must map to a rendered/derived need; one-shot effects per D2, not extra state. | A UiState field nothing reads, or an effect modeled as retained state. |
| G7 | **No config/flags without a consumer** — no toggles, feature flags, or params without a caller that sets them. | An unused `enabled`/`variant`/`mode` param. |
| G8 | **No premature vertical-slicing** — one concern = one feature; split into `<feature>/<slice>/…` + a `shared/` bucket only when ≥2 slices each carry independent data+ui with real cross-slice reuse (Expand rules, `cmp-architecture-structure.md`). | A single-concern feature force-split into slices, or a `shared/` bucket created for one consumer. |

**Official basis (G2).** Google *Guide to app architecture*: the domain layer is **optional** — "use it only when needed" — and forcing pass-through use cases "adds complexity for little benefit" ([domain-layer](https://developer.android.com/topic/architecture/domain-layer)); interfaces are **recommended** for swappability/testability, **not mandated** ([data-layer](https://developer.android.com/topic/architecture/data-layer)). So a pass-through UseCase and a single-impl interface with no test/swap seam are both collapsible, not required.

## How enforced
- `build-feature` **Gate 7** carries a checklist item citing this file (G1–G8); a feature is not "done" until it passes.
- `architecture-reviewer` reads this file and flags violations by rule id (G1–G8).
- When a rule conflicts with a request, **STOP and ask** (no silent scope expansion, no silent simplification).
