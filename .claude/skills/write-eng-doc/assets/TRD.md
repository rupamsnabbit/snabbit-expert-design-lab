---
doc_type: TRD
title: "<Feature / Module name>"
status: draft            # draft | in-review | approved | implemented | superseded
version: 0.1
author: "<engineering lead>"
reviewers: []
platforms: [android, ios]   # KMP :shared — Android + iOS
created: "<YYYY-MM-DD>"
last_updated: "<YYYY-MM-DD>"
traceability:
  parent: "HLD-<id>"
  children: ["LLD-<id>"]
  tickets: []
---

# TRD — <Feature / Module name>

**Scope of this doc:** the HOW as verifiable requirements. Each FR traces to a PRD id; each NFR is quantified. Conventions & `[TBD]` rule: see [conventions](conventions.md).

## 1. Context & Administration
- Purpose: [TBD]
- PRD ref: [TBD]  ·  HLD ref: [TBD]
- Definitions: [TBD]

## 2. Functional Requirements
| ID | Requirement (SHALL…) | Traces to PRD | Verification |
|----|----------------------|---------------|--------------|
| FR1|                      |               |              |

## 3. Non-Functional Requirements (mobile)
> Quantify with number + unit + condition.

| Category | Requirement (quantified) | Verification |
|----------|--------------------------|--------------|
| Cold-start / TTI |  |  |
| Frame / jank budget |  |  |
| Memory footprint |  |  |
| App-size impact |  |  |
| Battery / power |  |  |
| Network / offline behavior |  |  |
| Crash-free / ANR rate |  |  |
| Security |  |  |
| Privacy / compliance |  |  |
| Accessibility |  |  |

## 4. Permissions & Platform Requirements
| Capability | When requested | Handling (granted / denied / permanently-denied / background) |
|-----------|----------------|---------------------------------------------------------------|
|           |                |                                                               |

> Platform-model diagram **required** when a cross-process / background / multi-activity model applies (Mermaid).

## 5. Architecture & Design Requirements
> Diagram **required**: component/ownership map or MVI layers (Mermaid). Cite `feature-template.md` (MVI + collapse rules) and `library-guide.md` (mandated versions) — do not restate.

| Concern | Requirement / ownership | Notes |
|---------|-------------------------|-------|
| Modules in scope |  |  |
| Local storage / persistence |  |  |
| Mandated SDKs / min-OS / versions |  |  |
| Platform-parity (Android/iOS must match on…) |  |  |

## 6. Interface / API Contracts
> Backend endpoints consumed and/or module public API. Define error/offline behavior, not just happy path. Errors map to `AppErrorType` (per `core-facts.md`).

| Interface | Input | Output | Errors / offline | Auth |
|-----------|-------|--------|------------------|------|
|           |       |        |                  |      |

## 7. Data Requirements
| Field / entity | Source | Used for | Rendered? | PII / storage |
|----------------|--------|----------|-----------|---------------|
|                |        |          |           |               |

> Retention / cache-invalidation / migration:
[TBD]

## 8. Dependencies & Assumptions
| Dependency | Type (lib / module / branch / service) | Status |
|-----------|-----------------------------------------|--------|
|           |                                         |        |

| Assumption | Owner | Confirm by |
|------------|-------|------------|
| [ASSUMPTION] |     |            |

## 9. Testing & Acceptance
> Cover functional + NFR + offline/edge + device/OS matrix.

| Requirement ID | Test type (unit / UI / integration / device-matrix) | Acceptance criteria |
|----------------|------------------------------------------------------|---------------------|
|                |                                                      |                     |

## 10. Rollout, Observability & Rollback
| Aspect | Detail |
|--------|--------|
| Feature flag / remote config |  |
| Analytics events / alerts to watch |  |
| Staged rollout |  |
| Rollback trigger & steps |  |

## 11. Open Questions
| # | Question | Owner | Needed by |
|---|----------|-------|-----------|
| 1 |          |       |           |
