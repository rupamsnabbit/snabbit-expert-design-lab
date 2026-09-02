# Expert App design framework

## Purpose

This framework keeps every new screen, component, banner, bottom sheet, and interaction recognizably part of the Expert App. It is written for product design, interface design, UI behavior, and frontend handoff.

The app is an operational tool for experts. The visual system should help an expert understand what is happening now, what to do next, how much time or money is involved, and what happens if something fails.

## 1. Source-of-truth order

Use this order when making a visual or interaction decision:

1. The design-system package: `com.snabbit:design-system:0.19.0`.
2. Rules in `docs/design/`, including app-specific wrapper and screen-pattern guidance.
3. Existing Snabbit screens, using the closest consistent screen rather than an isolated legacy exception.
4. A documented local decision only when no existing rule can express the requirement.

Product intent and approved Figma define what must be achieved, but they do not silently override the visual source-of-truth order. Record and approve any required exception, then update the shared package or these docs so the decision becomes reusable.

Do not create a new visual treatment just because a generic component is convenient. First check whether an existing token, component, or screen pattern can express the intent.

## 2. Choose the surface before designing

The app currently has three visual surfaces. Decide which one owns the new experience before drawing it.

| Surface | Use | Design contract |
| --- | --- | --- |
| Compose/KMP | New shared-native flows and migrated app surfaces | Use `SnabbitScreen`, `SnabbitTheme`, and `com.snabbit.design.*`; no new raw Material chrome in feature UI. |
| Legacy Flutter | Existing Flutter flows that have not migrated | Use `AppTheme`, `AppColors`, existing Flutter widgets, and the closest established screen pattern. |
| Webview/hosted | Hosted or embedded experiences | Preserve the app shell, typography hierarchy, spacing rhythm, action placement, loading/error states, and safe-area behavior. |

Do not mix the three contracts inside one visual surface unless the transition is intentional and documented. The user should experience one app, even while the implementation is migrating.

## 3. The visual language

The app should feel calm, practical, and action-oriented. It is not a marketing surface.

- Brand actions use the Snabbit pink family.
- White and cool neutral gray create the primary canvas and card hierarchy.
- Green communicates success, completion, and positive earnings.
- Amber communicates caution, waiting, or an action that needs attention.
- Red is reserved for danger, failure, cancellation, and destructive actions.
- Blue is informational, not an alternative brand color.
- Cards are rounded and structured; avoid decorative containers without a clear information or action purpose.
- Every screen has one obvious primary action or one obvious current state.
- Persistent bottom actions should remain reachable and visually separate from scrolling content.

### Core semantic colors

These are the package values to use when working on Compose/KMP screens. Prefer semantic names over hex values in design and code.

| Role | Token | Reference |
| --- | --- | --- |
| Brand action | `bgBrand`, `textBrand`, `borderBrand`, `iconBrand` | `#F70F79` |
| Brand pressed/deep | pressed brand state | `#C70C61` |
| Main text | `textPrimary` | `#111827` |
| Body text | `textBody` | `#374151` |
| Secondary text | `textSecondary` | `#6B7280` |
| Tertiary text | `textTertiary` | `#9CA3AF` |
| Main canvas | `bgPrimary` | `#FFFFFF` |
| Secondary canvas | `bgSecondary` | `#F9FAFB` |
| Tertiary canvas | `bgTertiary` | `#F3F4F6` |
| Success | success semantic family | `#059669` |
| Warning | warning semantic family | `#D97706` |
| Error | error semantic family | `#DC2626` |
| Information | info semantic family | `#2563EB` |

Never use color alone to communicate a state. Pair it with text, an icon, a shape, or a status label.

## 4. Foundations

### Typography

The shared Compose package exposes these variants. Use the variant for its role instead of choosing a font size by eye.

| Variant | Size / line height | Intended use |
| --- | --- | --- |
| Display | 32 / 40 | Rare hero or high-salience result |
| Heading 1 | 28 / 37 | Screen-level title when the content needs emphasis |
| Heading 2 | 24 / 32 | Major section or result |
| Heading 3 | 20 / 28 | Card or section title |
| Title | 18 / 24 | Navigation title, prominent label |
| Body large | 16 / 24 | Primary explanatory content |
| Body medium | 14 / 20 | Default supporting content |
| Caption | 12 / 16 | Metadata and helper content |
| Small | 10 / 14 | Compact metadata only; never essential instructions |
| Button large | 16 / 16 | Large primary action |
| Button medium | 14 / 14 | Standard action |

Compose uses the package typography and Outfit font. Existing Flutter surfaces use the established Metropolis theme. Do not introduce another typeface; when a screen migrates, preserve hierarchy and intent before trying to normalize the font.

### Spacing

Use the package spacing scale. The numeric scale is `1=2`, `2=4`, `3=8`, `4=12`, `5=16`, `6=20`, `7=24`, `8=32`, `9=40`, `10=48`, `11=64` dp.

| Context | Preferred values |
| --- | --- |
| Tight icon/text gap | 4, 8 |
| Component internal gap | 8, 12, 16 |
| Screen horizontal padding | 16 by default; 24 or 32 for spacious layouts |
| Section gap | 24, 32 |
| Major separation | 40, 48, 64 |
| Bottom action clearance | At least 16 plus safe-area inset |

Use one consistent horizontal grid within a screen. Avoid arbitrary 10, 14, 18, or 22 dp values unless a package component requires them.

### Radius and borders

| Token | Value | Use |
| --- | --- | --- |
| None | 0 | Dividers and intentionally sharp geometry |
| Small | 4 | Small controls and tags |
| Medium | 8 | Inputs and compact containers |
| Large | 12 | Default cards and larger controls |
| XL | 16 | Selected cards, sheets, prominent surfaces |
| XXL | 24 | Large surface or hero treatment |
| Full | 9999 | Pills, avatars, circular controls |

Use 1 dp for standard borders, 1.5 dp for package card borders, and 2 dp for selected or emphasized states. A border should communicate structure or state; it should not be added to every layer.

## 5. Component selection rules

Start with the smallest approved component that expresses the job. Use the app wrapper when one exists.

| Need | Preferred component/pattern | Design note |
| --- | --- | --- |
| Text | `SnabbitText` | Select a semantic typography variant and explicit color only when needed. |
| Main action | `SnabbitButton` | One primary action per decision area; use destructive only for irreversible consequences. |
| Grouped surface | `SnabbitCard` | Choose Base, Dashed, Elevated, or Selected to communicate meaning. |
| Choice with explanation | `SnabbitSelectionCard` | Use Radio for one choice and Checkbox for multiple choices. |
| Short status/category | `SnabbitTag`, `SnabbitBadge`, or `SnabbitChip` | Keep labels short; never use a tag as the only explanation of a serious state. |
| Text entry | `SnabbitTextField` | Use label, helper, error, success, warning, and disabled states intentionally. |
| Phone/OTP | `SnabbitPhoneInput`, `SnabbitPinInput` | Preserve clear focus, error, resend, and recovery states. |
| Date or DOB | `SnabbitDatePicker`, `SnabbitDobSelection` | Make the format and allowed range understandable. |
| Progress | `SnabbitProgressBar` or `SnabbitPillProgress` | Show what progress means and what remains. |
| Screen shell | `SnabbitScreen` and `SnabbitTopNav` | The shell owns background, top navigation, insets, and snackbar behavior. |
| Temporary focused task | `SnabbitBottomSheet` | Use for a focused decision or short task; do not hide a complete workflow in a sheet. |
| Persistent status | `SnabbitStatusBanner` | Use for a visible condition that affects the current task. |
| Brief feedback | `SnabbitToast` | Use after an action; do not use it for critical information that must remain visible. |
| Bottom action | `SnabbitActionFooter` or established bottom action pattern | Keep primary action reachable and stable while content scrolls. |
| Earnings detail | `SnabbitEarningsAccordion`, `SnabbitMetricCard`, `SnabbitSummaryCard`, `SnabbitPayoutRow` | Make amount, period, status, and next step scannable. |
| Navigation destination | `SnabbitNavigationCard`, `SnabbitListItem`, or existing drawer/tab pattern | Preserve the app's established navigation grammar. |
| Repeated operational state | Existing `SnabbitJobState`, hotspot, connectivity, error, and home-state components | Prefer extending a state model over inventing a parallel card. |

If the need is not represented, complete the component brief before adding a new pattern.

## 6. Screen patterns

### Standard task screen

Use when the expert needs to complete one bounded task.

1. Top navigation: back/close, title, and progress only when progress is meaningful.
2. Context: one short explanation of why the task matters.
3. Main content: one decision or input group at a time.
4. Validation: show errors next to the relevant input and preserve entered data.
5. Bottom action: stable primary action with a clear disabled/loading state.

### Selection screen

Use a vertical list of selection cards or chips. Make the selected state obvious through more than color. The primary action should say what happens next, not just “Continue,” when the consequence is important.

### Operational home

The home screen can have different states—attendance, waiting, hotspot, new job, accepted job, in progress, lunch, completion, logged out, suspended, cancelled, offline, or error. Design each as a deliberate state, not as an empty variation of the same dashboard.

For every home state, define:

- current status;
- next best action;
- time or countdown meaning;
- earnings or job impact;
- recovery path if the expert cannot act;
- what should persist when the state changes.

### Job lifecycle

Keep the transition legible: new job → accepted → travel/check-in → in progress → completion → rating/earnings. The action, time pressure, and consequence should be clear at each step. Do not place two equally strong competing actions in a high-pressure job state.

### Bottom sheet

Use a sheet for a focused decision, picker, explanation, or short confirmation. Give it a clear title, a close/dismiss path, enough content context, and a primary action when an action is required. Avoid stacking sheets or making a sheet taller than the task deserves.

### Earnings and money

Show the amount first, then the period/status, then the breakdown or next step. Distinguish earned, pending, deducted, and unavailable values. Never rely on tiny text or color alone for financial meaning.

### Safety, failure, and recovery

Safety, SOS, insurance, dispute, suspension, cancellation, and offline states need a persistent explanation and a recovery action. Error copy should answer: what happened, what can the expert do now, and whether the task is still safe to retry.

## 7. States and behavior are part of the design

Every new component must be designed in a state matrix, at minimum:

| State | Required question |
| --- | --- |
| Default | What is the normal reading and action? |
| Pressed/focused | How does the user know the interaction registered? |
| Disabled | Why cannot the user act, and is the reason visible? |
| Loading | What is temporarily unavailable, and does layout remain stable? |
| Success | What changed and what can happen next? |
| Error | What failed, how local is the problem, and how can it recover? |
| Empty | Is the empty state expected, and what should the user do? |
| Offline/permission | Can the user continue safely, retry, or return later? |

For timed or consequential actions also define timeout, expiry, cancellation, duplicate tap, and interrupted-session behavior. For every destructive action, define confirmation, cancellation, and post-action recovery.

## 8. Accessibility and practical use baseline

- Minimum interactive target: 48 dp in the native surface, even when the visual control is smaller.
- Preserve readable contrast for text, status, and disabled content.
- Pair icons with labels when the meaning is not universally obvious.
- Keep primary actions reachable with one hand and above the system gesture area.
- Keep keyboard, safe-area, and bottom-sheet behavior explicit.
- Do not encode meaning only with pink/gray/green/red.
- Keep labels and error messages short enough to scan while moving between jobs.
- Check long translations, numeric formats, and names that wrap to two lines.
- Preserve focus order and announce important status changes in accessible text.

## 9. When a new component is justified

Create a new reusable component only when at least one is true:

- the same structure appears in two or more flows;
- the interaction has a meaningful state model that should be consistent;
- the component protects a safety, payment, timing, or compliance behavior;
- an existing component cannot express the hierarchy without misleading the user.

A new component needs: a clear job, anatomy, variants, tokens, content limits, all states, interaction behavior, accessibility notes, responsive behavior, and examples of correct and incorrect use. If it is only a one-screen composition, keep it as a screen-level pattern instead.

If the system has no exact match, follow the [design-system extension process](./DESIGN_EXTENSION_PROCESS.md). New compositions are allowed when they reuse approved foundations. New visual foundations or reusable APIs require an extension brief and explicit review.

## 10. New work workflow

Use this sequence for every new screen or component. A new screen or meaningful redesign should be summarized with the [screen / experience design brief](./DESIGN_BRIEF_TEMPLATE.md) and reviewed before implementation; a small explicit correction can proceed after stating the intended change.

1. Understand the PRD, current experience, supplied Figma, and the user moment: where is the expert, what just happened, and what must happen next?
2. Inspect the closest Snabbit references in [GOLDEN_REFERENCES.md](./GOLDEN_REFERENCES.md). Use external research only to resolve a real interaction or information-architecture question.
3. Choose the owning surface: Compose/KMP, legacy Flutter, or webview/hosted.
4. Recommend a direction, name meaningful tradeoffs, and resolve decisions that change the experience.
5. Choose an existing screen pattern and approved components.
6. Map the information hierarchy: current state, primary action, supporting context, and recovery.
7. Map every visible element to a semantic token and component.
8. Design the complete applicable state matrix, including loading, error, offline, timeout, and long content.
9. Complete the [new component brief](./NEW_COMPONENT_BRIEF_TEMPLATE.md) if introducing a meaningful reusable pattern or new foundation.
10. After approval, implement with frontend fixtures and a direct review entry point.
11. Review at realistic device width, one-handed reach, and with long content.
12. Record intentional exceptions in the brief and update the relevant source-of-truth documents.

## 11. Design review gate

Before approval, ask:

- Can an expert tell what state they are in within two seconds?
- Is there one clear next action?
- Is the information hierarchy consistent with similar screens?
- Are tokens and approved components used instead of custom styling?
- Are success, error, loading, empty, offline, disabled, and timeout states covered?
- Are money, time, safety, and destructive consequences explicit?
- Does the surface preserve the app shell, spacing rhythm, typography, and bottom-action behavior?
- Does it work with long labels, localization, keyboard, safe area, and one-handed use?
- If it is new, is the reason for adding a new component stronger than reusing an existing one?

## 12. Definition of done

Design work is ready for frontend handoff when the answer is yes to all of these:

- The user moment and success condition are written down.
- The UI surface is known.
- The screen pattern and component choices are named.
- Visible values map to semantic tokens.
- All meaningful states and transitions are shown.
- Content, localization, accessibility, and edge cases are considered.
- The primary action and recovery path are unambiguous.
- The design has been compared with an existing app screen.
- Any exception is documented and approved.

## Known consistency risks

The product is migrating between legacy Flutter and Compose/KMP, and some screens are hosted or embedded. The main risk is visual drift between those surfaces—especially font, spacing, action-footer placement, and status treatments. Treat these as explicit product decisions, not accidental differences.

High-consequence states deserve extra review: job acceptance, check-in, countdowns, completion, earnings, payment/bank setup, SOS, insurance, disputes, suspension, and offline recovery.
