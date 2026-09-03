# AI design router for the Snabbit Expert App

Use this page to load the smallest useful amount of design context. Detailed rules live in the linked documents; do not load the entire design folder for every task.

## Source-of-truth order

When sources disagree:

1. The installed design-system package: `com.snabbit:design-system:0.19.0` for Compose/KMP, or the established theme bridge for an existing Flutter surface.
2. Rules in `docs/design/`.
3. The nearest consistent Snabbit screen in [GOLDEN_REFERENCES.md](./GOLDEN_REFERENCES.md) and [SCREEN_INVENTORY.md](./SCREEN_INVENTORY.md).
4. A documented local decision only when no existing rule fits.

PRDs and approved Figma define the intended outcome. They do not silently authorize a new color, type style, spacing value, component foundation, or interaction grammar.

## Route the task

| Task | Minimum design context |
| --- | --- |
| Critique or improve an existing design | [DESIGN_PRINCIPLES.md](./DESIGN_PRINCIPLES.md), nearest golden reference, relevant screen pattern, and current implementation/Figma |
| New screen from a PRD | [DESIGN_BRIEF_TEMPLATE.md](./DESIGN_BRIEF_TEMPLATE.md), relevant principles, pattern, inventory rows, components, tokens, fixtures, and voice |
| Small visual correction | Owning component/screen plus the exact token or component rule involved |
| New or changed reusable component | Relevant component entry and [DESIGN_EXTENSION_PROCESS.md](./DESIGN_EXTENSION_PROCESS.md) |
| Copy change | [CONTENT_AND_VOICE.md](./CONTENT_AND_VOICE.md) and the relevant state pattern |
| Implementation or visual QA | Relevant fixtures plus [DESIGN_QA_CHECKLIST.md](./DESIGN_QA_CHECKLIST.md) |

Search long documents by heading, component, domain, or route. Read adjacent context when needed; do not assume an isolated match is the whole rule.

## Approval gate

For a new screen or meaningful redesign:

1. Explore the PRD, supplied Figma, current implementation, Snabbit references, and relevant external patterns.
2. Present a concise design brief with a recommended direction, state flow, reuse/extension plan, and material questions.
3. Resolve choices that change the experience before implementation.
4. After approval, implement with frontend fixtures and provide a directly reviewable entry point.

A small, explicit correction does not need a stored brief unless it introduces a new reusable decision.

## Frontend-only boundary

- Keep design work independent of live backend responses, authentication, remote configuration, and production data.
- Preserve existing data/API seams. Add or extend debug/test/preview fixtures at the frontend boundary.
- Do not delete or rewrite backend-related code merely because the design prototype does not use it.
- Use the framework already owning the feature. Document and approve a framework migration before starting it.

## Reuse and extension

Reuse existing components and semantic tokens wherever they fit. If nothing fits, follow [DESIGN_EXTENSION_PROCESS.md](./DESIGN_EXTENSION_PROCESS.md): try composition first, identify the missing capability, choose the narrowest ownership level, document meaningful extensions, and keep them experimental until validated.

## Visual craft lens

Use the repository's `impeccable` skill for critique, hierarchy, layout, typography, responsive behavior, accessibility, state completeness, and final polish. The Expert App is an operational product: clarity, trust, consistency, and task completion outrank decorative novelty.

Impeccable suggestions sit below the design-system package, these documents, and approved Snabbit references. If a generic anti-pattern rule conflicts with an intentional documented product decision, preserve the product decision and record only genuine exceptions or extensions.

## Required state thinking

Design the applicable default, loading, empty, success, error, disabled, offline/permission, timeout/expiry, and long-content states. Make the current state, next action, and any time, money, safety, or destructive consequence clear. Use [FRONTEND_FIXTURES.md](./FRONTEND_FIXTURES.md) for deterministic review data.

## Handoff

Report:

- recommended direction and important tradeoffs;
- surface, route, preview/fixture entry, and covered states;
- reused components, tokens, patterns, and reference screens;
- screenshots or goldens captured;
- responsive, accessibility, and other checks actually performed;
- documentation changed and any unapproved exception.
