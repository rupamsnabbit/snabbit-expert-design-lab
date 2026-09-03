# Expert App design system

This folder is the frontend and product-design source of truth for new work in the Expert App.

Start with [AI design instructions](./AI_DESIGN_INSTRUCTIONS.md) for the required reading order and implementation workflow.

The repository also includes the `snabbit-design` workflow and [Impeccable](https://github.com/pbakaus/impeccable) v4.1.3 (Apache-2.0) under `.agents/skills/`. Impeccable strengthens critique and polish; the Snabbit source-of-truth order still decides the product's visual language.

Mobbin is connected as an MCP research source for focused pattern exploration. Follow [Reference research](./REFERENCE_RESEARCH.md): learn from behavior and information architecture, then translate the insight into Snabbit rather than copying an external screen.

## Core documents

- [Design principles](./DESIGN_PRINCIPLES.md) — the bright, warm, confident, practical, trustworthy, and human product personality.
- [Design tokens](./DESIGN_TOKENS.md) — exact color, typography, spacing, radius, border, elevation, icon, button, and screen-grid contract.
- [Component library](./COMPONENT_LIBRARY.md) — approved package components, Expert App wrappers, variants, states, behavior, and reuse policy.
- [Screen patterns](./SCREEN_PATTERNS.md) — standard layouts and behavior for login, forms, cards, sheets, empty/error/success/loading, navigation, and operational flows.
- [Screen inventory](./SCREEN_INVENTORY.md) — routes, purposes, component families, fixtures, screenshots, status, and inconsistencies.
- [Content and voice](./CONTENT_AND_VOICE.md) — tone, CTA, error, empty, Hindi/English, capitalization, and formatting rules.
- [Frontend fixtures](./FRONTEND_FIXTURES.md) — deterministic design-review data and required state coverage.
- [Design QA checklist](./DESIGN_QA_CHECKLIST.md) — final design and implementation review gate.
- [Design-system extension process](./DESIGN_EXTENSION_PROCESS.md) — how to build a compatible local composition, variant, or new component when the system has no exact match.
- [Golden reference families](./GOLDEN_REFERENCES.md) — preferred Home, job, attendance, sheet, payout, and outcome references, with cautions and evidence status.
- [Reference research](./REFERENCE_RESEARCH.md) — when and how to use Mobbin or other external examples without drifting from Snabbit.
- [Expert App design framework](./EXPERT_APP_DESIGN_FRAMEWORK.md) — end-to-end design workflow and definition of done.
- [Screen / experience design brief](./DESIGN_BRIEF_TEMPLATE.md) — lightweight approval brief for a new screen or meaningful redesign.
- [New component brief](./NEW_COMPONENT_BRIEF_TEMPLATE.md) — copy this before proposing a new component or screen pattern.

The app's shared Compose design-system package is `com.snabbit:design-system:0.19.0`.
The practical app layer around it lives in:

- `shared/src/commonMain/kotlin/com/snabbit/runner/shared/core/designsystem/`
- `shared/src/commonMain/kotlin/com/snabbit/runner/shared/ui/components/`
- `shared/src/commonMain/kotlin/com/snabbit/runner/shared/features/` for domain compositions
- `lib/utils/themes.dart`, `lib/utils/colors.dart`, `lib/utils/custom_themes/`, and `lib/widgets/` for legacy Flutter surfaces

The source-of-truth order is:

1. Design-system package.
2. Rules in `docs/design/`.
3. The nearest consistent existing Snabbit screen.
4. A documented local decision only when no existing rule exists.

When the package and an app wrapper both provide a capability, use the app wrapper as the implementation entry point while preserving the package's visual contract. Update this folder whenever a reusable design decision is made.
