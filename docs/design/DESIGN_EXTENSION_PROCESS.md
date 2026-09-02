# Design-system extension process

## Purpose

The design system will not contain every future card, banner, workflow, or operational state. Missing components are expected. The goal is to extend the product without making each new feature look like a different app.

The rule is:

> New composition is allowed. New visual foundations require an explicit design-system decision.

A feature may arrange approved text, icons, cards, buttons, status treatments, and spacing in a new way. It must not silently invent a new color family, typography scale, grid, button style, sheet behavior, or interaction grammar.

## First classify the gap

Before designing or coding, place the need in one of these categories:

| Category | Meaning | Where it belongs | Documentation |
| --- | --- | --- | --- |
| Screen composition | Existing components can express the experience; only their arrangement is new | Feature/screen layer | Record in the screen inventory; no new component API |
| Existing component variant | The component's job is unchanged, but one reusable state or layout is missing | App wrapper first; package when shared | Extension brief required |
| Domain component | A repeated structure belongs to one domain such as attendance, payout, job, or Kavach | Domain component folder | Extension brief required |
| Design-system component | The same job applies across multiple unrelated domains and needs one stable contract | Shared design-system package | Extension brief and package review required |
| Intentional one-off | A unique campaign/editorial treatment with no reusable behavior | Feature-local composition | Short decision record; never a source for unrelated UI |

Do not create a reusable component simply because a design contains a rectangle with text. Reuse is based on a stable job and behavior, not visual similarity alone.

## Decision sequence

### 1. Search by job, not appearance

Ask what the element does: navigate, select, warn, summarize, confirm, show progress, explain earnings, or recover from failure. Check the package, app wrappers, domain components, screen patterns, and nearest consistent screens.

### 2. Try composition

Build the design from existing primitives and tokens. For example, a new attendance-impact card may be a `SnabbitCard` containing `SnabbitText`, `SnabbitTag`, payout rows, and an existing action—not a new card foundation.

Prefer a screen-local composition when it appears once and has no independent behavior. Extract it only when the screen becomes hard to understand/test or the structure repeats.

### 3. Identify the truly new part

Write one sentence naming what the system cannot currently express. Examples:

- “A status card needs a persistent before/after earnings comparison.”
- “The existing selection card cannot show a timed expiry.”
- “This job state needs a reusable confirm-and-recover interaction.”

If the sentence is only “the design looks different,” the gap is not defined well enough.

### 4. Preserve Snabbit’s visual DNA

Every extension must inherit:

- semantic colors from [DESIGN_TOKENS.md](./DESIGN_TOKENS.md);
- approved typography roles;
- the 2/4/8/12/16/20/24/32 spacing rhythm;
- approved radius, border, icon, and button sizes;
- one-primary-CTA hierarchy;
- existing navigation, footer, bottom-sheet, loading, and error behavior;
- the voice rules in [CONTENT_AND_VOICE.md](./CONTENT_AND_VOICE.md);
- 48 dp targets, safe-area behavior, and non-color status communication.

Novelty should live in the information structure or domain behavior. It should not come from arbitrary styling.

### 5. Write an extension brief

Copy [NEW_COMPONENT_BRIEF_TEMPLATE.md](./NEW_COMPONENT_BRIEF_TEMPLATE.md) to:

`docs/design/extensions/<kebab-case-name>.md`

The brief must include the closest existing components/screens, why composition or a current variant is insufficient, anatomy, token mapping, all states, interaction behavior, content limits, accessibility, screenshots, and promotion criteria.

For a low-risk one-screen composition, the same information may be recorded directly in the related screen brief or inventory entry. A new color, interaction, high-consequence state, or reusable API always requires a separate brief.

### 6. Prototype at the narrowest safe level

Use this ownership order:

1. Screen-local composition for a unique layout.
2. Domain component for repeated behavior within one feature area.
3. Expert App wrapper for shared app behavior.
4. Design-system package component/variant for cross-domain use.

Starting locally is not permission to use raw styles. The prototype must still use approved tokens and primitives. Keep the API small and do not expose speculative variants.

### 7. Validate compatibility

Review the extension beside at least two references when available:

1. the nearest screen with the same user moment;
2. a canonical Snabbit screen that establishes general visual hierarchy.

Capture default plus meaningful loading, success, error, empty, disabled, offline/permission, timeout, and long-content states at 360 × 800 dp. Also verify 320 and 412 dp widths.

The review should answer:

- Does it look like it belongs on the same screen as existing components?
- Does it use the same density, hierarchy, and action grammar?
- Is the new behavior understandable without a new visual language?
- Would reusing it elsewhere preserve meaning rather than merely save code?

### 8. Decide whether to promote

Use this lifecycle:

| Status | Meaning |
| --- | --- |
| Proposed | The gap and solution are documented but not approved |
| Experimental | Implemented locally with fixtures for one validated use |
| Validated | Product/design/engineering agree the pattern works |
| Promoted | Added to the app component layer or design-system package and cataloged |
| Deprecated | Replaced; existing uses have a migration path |
| Rejected | Tested but should not be reused; retain the decision reason if useful |

Promotion is appropriate when one or more are true:

- the same structure is used in at least two flows;
- a meaningful interaction/state model must remain consistent;
- the component protects safety, payment, timing, attendance, or compliance behavior;
- more than one team/surface needs the same semantic job.

Do not promote seasonal artwork, campaign-only styling, or a layout whose meaning changes from screen to screen.

## Introducing a new token

A component gap and a token gap are different decisions. If existing semantic tokens cannot express the required meaning:

1. describe the semantic role, not just the desired hex/dimension;
2. show why existing tokens would miscommunicate the state;
3. define contrast, light/dark behavior, affected components, and migration;
4. propose the token in the design-system package;
5. if a temporary local token is unavoidable, isolate it in the app design-system layer and link its removal/promotion criterion.

Never put a new reusable color or dimension directly in a feature component.

## Extension register

Add approved or experimental extensions to this table. Link the brief rather than duplicating its contents.

| Extension | Category | Owner | Status | Used by | Brief | Promotion/review trigger |
| --- | --- | --- | --- | --- | --- | --- |
| _Add the first extension here_ |  |  |  |  |  |  |

When an extension is promoted, update [COMPONENT_LIBRARY.md](./COMPONENT_LIBRARY.md). When it changes a screen pattern or foundation, update the relevant pattern/token document as well.

## Agent rule

When no existing component fits, an AI agent must not stop at “component unavailable” and must not improvise silently. It must:

1. explain the missing capability;
2. classify the gap using this document;
3. propose the smallest token-aligned composition or extension;
4. identify its ownership level and lifecycle status;
5. create/update the brief and fixtures;
6. obtain review for new foundations or reusable APIs;
7. update the component library only after promotion.

