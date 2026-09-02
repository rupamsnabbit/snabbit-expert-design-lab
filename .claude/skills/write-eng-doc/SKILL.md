---
name: write-eng-doc
description: Generate a lean, human-scannable engineering document (PRD, HLD, TRD, or LLD) for a feature in the :shared KMP/CMP module. Use when asked to write, create, draft, or scaffold a PRD, HLD, TRD, or LLD, produce a design or requirements doc, or turn a feature description into a structured engineering document. Not for editing existing prose, code review, building the feature (use build-feature), or non-engineering documents.
argument-hint: "[prd|hld|trd|lld] [feature details]"
allowed-tools: Read, Write, Edit, WebSearch, WebFetch
metadata:
  version: "1.1"
  author: "Snabbit Mobile"
---

# Write Engineering Document — Snabbit Runner KMP

Generate one document — **PRD, HLD, TRD, or LLD** — for a `:shared` KMP/CMP feature, scoped to that type, following lean AI-authoring rules. Output is consumed by **build-feature**.

## When to use
- Write / draft / scaffold a **PRD, HLD, TRD, or LLD**, a design/requirements doc, or turn a feature description into a structured engineering document.
- **Do not use** for: editing prose, code review, **building the feature (→ build-feature)**, or defining the feature itself (brainstorm first).

## Inputs
1. **Document type** — `prd | hld | trd | lld`.
2. **Feature details** — what is being built + constraints/links.

Missing or ambiguous → **ask**; never guess the type or invent scope.

## Ground in the repo first (reference, don't restate)
These recorded documents are the **trusted baseline**. The emitted doc **cites them per-doc** — it never copies their rules:
- `.claude/documents/core-facts.md` — ViewModel **D1**, one-shot effects **D2**, **AppErrorType**, SnabbitScreen, AppDispatchers, Koin
- `.claude/documents/cmp-architecture-structure.md` — feature layout (incl. vertical-slice Expand rules), boundaries, collapse, i18n, navigation (**BUILT** — `NavigationController`)
- `.claude/documents/feature-template.md` — MVI contract (`Contract.kt`) + collapse summary
- `.claude/documents/platform-rules.md` — CmpHostActivity (**TARGET, not yet built**), StoreManager, background work
- `.claude/documents/library-guide.md` — pinned versions, commonMain blocklist, **iOS compile gate**
- `.claude/documents/component-catalog.md` — canonical DS components
- `.claude/documents/git-discipline.md` — branch model; docs are version-controlled

## Scope per document type (enforced boundaries)
| Type | Answers | MUST cover | MUST NOT contain |
|------|---------|------------|------------------|
| PRD | What / Why | objective, users, success metrics, requirements, out-of-scope | implementation, architecture, APIs |
| HLD | System-level How | components, high-level data/interfaces, flows, platform abstraction, crosscutting (cite docs) | class/method detail, full contracts |
| TRD | Verifiable requirements | functional reqs (trace to PRD), quantified NFRs, permissions, contracts, test/rollout | narrative design, code |
| LLD | Class/method-level How (one module) | MVI file layout, API contract, AppErrorType handling, Android/iOS mapping, sequences, tests | system redesign, product rationale |

Cross-boundary content is a defect — move it to the correct document.

## Workflow
1. **Confirm inputs** — type + feature. Missing → ask.
2. **Load the template** from `assets/` — use its exact section structure; add or drop nothing.
3. **Front-matter** — type, title, status, version, author, `traceability` (parent/children/tickets). Write to `docs/design/<feature>/<TYPE>.md` (per `git-discipline.md`).
4. **Fill sections in repo vocabulary** — feature-first layout (`cmp-architecture-structure.md`): `ui/contracts/<Feature>Contract.kt` (Intent+UiState; `SideEffect` only for a rare non-nav one-shot), `data/`, `domain/` per collapse; `androidx.lifecycle.ViewModel` + `viewModelScope`; `AppErrorType`; **D2** one-shot effects; `SnabbitScreen` + DS components; server-driven i18n + composeResources fallback (forward standard); `CmpHostActivity` (**TARGET, not yet built**; navigation **BUILT** — `NavigationController`). Unknown → `[TBD]` + ask; risky → `[ASSUMPTION]`.
5. **Current facts** — web-search official sources for any version/API/OS-limit **not** covered by the recorded docs. The recorded docs are the baseline — do not re-verify them.
6. **Cite or mark** — each recommendation cites an official source or a recorded doc, else `[ASSUMPTION]`.
7. **Self-check** vs the boundary table + authoring rules. An **LLD must map to build-feature's file order**: UiState → UiIntent → DataSource → Strings → ViewModel → Screen → Fake → Test.

## Authoring rules (enforced)
- **Tables first** · **Diagrams required** (Mermaid, every non-trivial flow/state/topology) · **Human tone** · **Current** (web-search non-recorded facts) · **Evidence** (cite / `[ASSUMPTION]`) · **STOP-on-unknown** (`[TBD]` = ask). Full rules + markers: `assets/conventions.md`.

## Mermaid safety
No `;`, `<…>`, `=` at a label start, `→`, or `∧` in diagram text; class members one per line.

## Output format
- One markdown doc; headings match the template exactly. Target: PRD/HLD ≈ 3–4 pp · TRD ≈ 3–4 · LLD ≈ 5–6 — scannable. Any code-shaped claim must be iOS-compile-safe (`./gradlew :shared:compileTestKotlinIosArm64`).

## Example
"Write an LLD for a `referral` feature." → load `assets/LLD.md`; MVI layout per `feature-template.md`; errors via `AppErrorType` (`core-facts.md`); UI via `SnabbitScreen` + `component-catalog.md`; Android/iOS seams; cite `.claude/documents/*`; unknown backend contract → `[TBD]`.

## Common mistakes
- Boundary bleed · prose bloat · **restating recorded rules** (reference them) · guessing gaps (use `[TBD]`) · adding sections.

## Related skills
- **build-feature** — consumes the LLD/TRD to build the feature.
- **review-changes** — reviews the resulting diff.

## Assets & references
- `assets/{PRD,HLD,TRD,LLD}.md` — templates. `assets/conventions.md` — flow, markers, authoring rules, repo grounding. `references/authoring-rules.md` — expanded rules.
