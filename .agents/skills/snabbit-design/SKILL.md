---
name: snabbit-design
description: Explore, critique, specify, implement, or visually review Snabbit Expert App frontend work from PRDs, Figma links, screenshots, or written prompts. Use for screens, components, interaction states, design-system extensions, frontend fixtures, and design QA; do not use for backend-only work.
---

# Snabbit design workflow

Create a coherent Snabbit experience, not a standalone mockup. Explain decisions in product-design language before implementation detail.

## Select the mode

- **Explore or critique:** inspect the current experience and references, then return prioritized findings and 1–3 defensible directions. Do not edit code unless requested.
- **New screen or meaningful redesign:** create a concise brief from `docs/design/DESIGN_BRIEF_TEMPLATE.md`. Present the recommendation, tradeoffs, states, reuse plan, and open questions before coding. Wait for the user's response when a choice changes the experience materially.
- **Small visual change:** inspect the owning screen and relevant rules, state the intended correction, implement it, and verify proportionately.
- **Implementation of an approved direction:** use frontend fixtures, preserve the owning framework, render the meaningful states, and complete design QA.

## Use Impeccable for visual craft

Load `.agents/skills/impeccable/SKILL.md` alongside this skill for visual design work. Treat the Expert App as Impeccable **Operate** mode: the expert completing the task, understanding the current state, and acting safely outrank novelty.

Run Impeccable's context setup once per applicable task. If `node` is not on `PATH`, use the bundled Node executable reported by the workspace dependency runtime; do not install another Node version merely to run the skill.

Use Impeccable selectively:

| Snabbit task | Impeccable lens |
| --- | --- |
| Explore a PRD or shape a new flow | `shape` / new-work guidance after product context is established |
| Improve or review an existing Figma/screen | `critique` for prioritized, evidence-based findings |
| Refine hierarchy, spacing, type, or density | `layout`, `typeset`, `distill`, `bolder`, or `quieter` as appropriate |
| Complete edge cases and accessibility | `harden` and native `adapt` / `audit` guidance |
| Final implementation pass | `polish`, followed by one bounded confirmation pass |

The authority order is: approved product outcome and facts, Snabbit design-system package, `docs/design/`, consistent Snabbit references, then Impeccable craft guidance. Treat generic detector findings as evidence to evaluate, not automatic permission to change a deliberate Snabbit token or pattern. Document a true new decision through the Snabbit extension process.

Do not enable hooks, introduce a new visual world, create `DESIGN.md`, or run an Impeccable redesign flow as a side effect. Do those only when the current request needs them. Keep visual QA bounded to an initial batched review, one correction batch, and at most one confirmation pass.

## Discover before deciding

1. Read the PRD/prompt and inspect every supplied Figma frame or reference that affects the task. If a Figma link is available, use the available Figma workflow rather than guessing from its title.
2. Identify the user moment, primary outcome, consequence of delay/failure, and any missing product decision. Ask only questions whose answers would materially change the result.
3. Inspect the current screen, its actual reusable components, and the closest reference family in `docs/design/GOLDEN_REFERENCES.md`.
4. When the user asks to explore designs, requests inspiration or benchmarking, or a real interaction uncertainty remains, use the connected `mobbin` MCP server and follow `docs/design/REFERENCE_RESEARCH.md`. Search for the specific user moment rather than browsing broadly.
5. Record the useful behavior, hierarchy, state, and content lessons in the design brief. Separate observations from recommendations and identify what will change during translation to Snabbit.
6. Do not copy another product's branding, assets, copy, or full composition, and do not treat external visuals as Snabbit's source of truth.

## Load design context selectively

Start with `docs/design/AI_DESIGN_INSTRUCTIONS.md`; it is the router. Then read only the material relevant to the task:

| Need | Read |
| --- | --- |
| Product personality or hierarchy | `DESIGN_PRINCIPLES.md` |
| Colors, type, spacing, radius, elevation, sizing | Relevant section of `DESIGN_TOKENS.md` |
| Reusing or changing a component | Relevant entry in `COMPONENT_LIBRARY.md` |
| Screen structure, sheets, states, navigation, CTAs | Relevant section of `SCREEN_PATTERNS.md` |
| Existing screen/route/reference | Relevant rows in `SCREEN_INVENTORY.md` and `GOLDEN_REFERENCES.md` |
| External pattern exploration | `REFERENCE_RESEARCH.md` and the `Reference synthesis` section of the design brief |
| Reviewable data and states | `FRONTEND_FIXTURES.md` |
| User-facing copy | Relevant section of `CONTENT_AND_VOICE.md` |
| No existing component fits | `DESIGN_EXTENSION_PROCESS.md` and, when required, `NEW_COMPONENT_BRIEF_TEMPLATE.md` |
| Final review | `DESIGN_QA_CHECKLIST.md` |

Use heading or keyword search to load relevant sections instead of reading every long document end to end.

## Make the brief useful to a designer

Lead with:

- the problem and user moment;
- what the current experience gets right or wrong;
- the recommended direction and why;
- reference patterns being adapted;
- components and tokens being reused;
- screen/state flow, including failure and recovery;
- what is genuinely new;
- questions or tradeoffs needing approval.

Avoid leading with architecture, filenames, or implementation terminology unless they affect the design decision.

## When the system has no component

Do not stop and do not improvise styling.

1. Try a screen-level composition of approved primitives.
2. Name the exact missing capability.
3. Classify it as a component variant, domain component, design-system component, or intentional one-off.
4. Propose the narrowest token-aligned solution and show it beside the nearest Snabbit references.
5. Use `NEW_COMPONENT_BRIEF_TEMPLATE.md` for a meaningful variant, reusable behavior/API, new foundation, or high-consequence interaction.
6. Keep it local and experimental until reuse or validation justifies promotion. Update `COMPONENT_LIBRARY.md` only after promotion.

Novel information structure is welcome. Arbitrary new colors, typography, spacing, elevation, CTA behavior, or sheet behavior are not.

## Implement for frontend review

- Use the framework and conventions already owning the target feature. A potentially better framework is a proposal, not automatic permission for a rewrite.
- Use existing components and semantic tokens. Keep data behind deterministic debug/test/preview fixtures.
- Do not make design review depend on backend responses, production credentials, or real user data.
- Include the applicable default, loading, empty, success, error, disabled, offline/permission, timeout/expiry, and long-content states. Mark genuinely irrelevant states as not applicable in the brief.
- Provide a direct preview route, fixture selector, preview, or golden-test seam so the user can review without navigating the production flow.
- Compare at 360 × 800 dp, then check 320 and 412 dp widths when supported. Check long copy, safe areas, 48 dp targets, non-color status meaning, and CTA reach.

## Close the loop

Before calling work complete:

1. Render or capture the important states when the environment permits it.
2. Apply `DESIGN_QA_CHECKLIST.md` proportionately.
3. Update `SCREEN_INVENTORY.md` for a new or materially changed screen.
4. Update tokens, components, patterns, fixtures, or golden references only when their source of truth actually changed.
5. Report the design direction, preview entry, covered states, captured evidence, checks run, unresolved decisions, and any documented exception.
