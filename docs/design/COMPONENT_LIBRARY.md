# Snabbit component library

## How to use this catalog

This page describes the public design contract of reusable UI. The Compose package is the canonical component source. App-level wrappers add Expert App behavior and should preserve the package's visual contract. Legacy Flutter components are supported for existing Flutter flows but must not be copied into new Compose work.

For every component:

- Default includes readable content and no pending action.
- Pressed/focused must visibly acknowledge interaction.
- Disabled must block action and, where unclear, explain why.
- Loading must preserve layout and block duplicate action.
- Error belongs next to the failed component when possible.
- Accessibility semantics must describe role, state, value, and action.

## Package primitives: `com.snabbit.design`

### Text, media, and structure

| Component | Anatomy | Variants/states | Behavior | Do / don't |
| --- | --- | --- | --- | --- |
| `SnabbitText` | Text content | Display, Heading 1–3, Title, Body L/M, Caption, Small, Button L/M; semantic colors | Wraps naturally; respect font scale | Do select by role. Don't choose a raw size by eye. |
| `SnabbitRichText` | Ordered text spans | Inline emphasis/links | Keep reading order and link semantics | Do emphasize a short consequence. Don't simulate a paragraph layout with many spans. |
| `SnabbitIcon` | Named icon | Package icon names and semantic colors | Decorative icons are excluded from semantics; actionable icons need labels | Do use known icon names. Don't mix arbitrary icon sets in one surface. |
| `SnabbitImage`, `SnabbitRemoteImage`, `SnabbitLottie` | Media frame, source, fallback | Loading, loaded, fallback/error | Reserve size while loading; remote media needs fallback | Do provide useful alt/semantics. Don't make essential guidance image-only. |
| `SnabbitAvatar` | Image/initial, shape | Available fallback states | Preserve circular crop and label identity | Do provide fallback initials/image. Don't use as decoration. |
| `SnabbitDivider` | Rule and optional spacing | Horizontal structural separation | Not interactive | Do separate peers. Don't use multiple dividers plus borders for the same boundary. |
| `SnabbitBox` | Tokenized surface/content slot | Consumer-defined | Layout primitive only | Do use for simple tokenized composition. Don't create a new card API with it. |

### Actions and selection

| Component | Anatomy | Variants/states | Behavior | Do / don't |
| --- | --- | --- | --- | --- |
| `SnabbitButton` | Label, optional leading/trailing icon or badge, optional spinner/progress | Primary, Secondary, Tertiary, Neutral Filled/Stroke, Destructive, Success, Link, Text Link; XS/S/M/L; default/pressed/disabled/loading/progress | One tap per action; loading keeps label; full-width L suits persistent footer | Do use one primary action. Don't recolor Primary to create a new semantic style. |
| `SnabbitButtonGroup` | Ordered buttons with shared layout | Vertical/horizontal combinations supported by API | Primary follows reading order; stacks when labels need room | Do keep labels action-specific. Don't show two primary buttons. |
| `SnabbitNavButton` | Icon, accessible label, hit area | Back/close or supported nav intent | Minimum 48 dp target | Do use for app navigation. Don't place a bare 24 dp tappable icon. |
| `SnabbitCheckbox` | Control, label/semantics | Checked, unchecked, disabled | Toggles independent choices | Do use for multiple selection. Don't use for mutually exclusive options. |
| `SnabbitRadioButton` | Control, label/semantics | Selected, unselected, disabled | Selects one item in a group | Do expose group context. Don't allow multiple selected values. |
| `SnabbitSelectionChip` | Compact label, selected affordance | Selected/unselected/disabled | Use for short, low-complexity choices | Do keep labels short. Don't use for choices needing explanation. |
| `SnabbitSelectionCard` | Control, title, optional description/supporting content | Radio/Checkbox; Default/Selectable; selected/disabled | Entire card target selects; selection is communicated beyond color | Do use when a choice needs context. Don't nest independent links without clear hit areas. |

### Status and compact information

| Component | Anatomy | Variants/states | Behavior | Do / don't |
| --- | --- | --- | --- | --- |
| `SnabbitTag` | Optional icon, short label | Brand, Neutral, Success, Warning, Error, Info, Purple; Filled/Soft/Outline; XS/S/M/L | Read-only category/status | Do keep it short. Don't use a tag as the only explanation of a serious state. |
| `SnabbitBadge` | Compact count/status marker | Brand, Success, Error, Warning, Info, Neutral | Attaches to another element | Do use for count/newness. Don't place standalone without context. |
| `SnabbitChip` | Icon(s), optional count | Filled/Stroke; Repeat/Count; semantic variants; 20/24/28/32/40 dp | Compact repeated status/count | Do use semantic variant. Don't use raw color unless the domain owns it. |
| `SnabbitStatusDot` | Dot and semantics | Semantic status colors | Supplementary status cue | Do pair with text. Don't rely on dot color alone. |
| `SnabbitStatusBanner` | Icon, title/body, optional action | Semantic variants; Top/Bottom/Standalone | Persistent while condition affects current task | Do include recovery when actionable. Don't replace critical content with a toast. |
| `SnabbitToast` | Icon, brief message | Success, Error, Warning, Info | Temporary post-action feedback; not a workflow container | Do confirm a completed lightweight action. Don't use for payment/safety facts that must persist. |
| `SnabbitTooltip` | Anchor and concise explanation | Package-supported placement/state | Opens on supported help interaction and dismisses safely | Do explain unfamiliar icons/terms. Don't hide required instructions. |
| `SnabbitTone` | Semantic tone mapping | Package semantic tones | Internal semantic helper | Do reuse through components. Don't treat it as a new palette. |

### Data, lists, and progress

| Component | Anatomy | Variants/states | Behavior | Do / don't |
| --- | --- | --- | --- | --- |
| `SnabbitCard` | Surface, optional header, content, optional click action | Base, Dashed, Elevated, Selected; padding None/8/12/16; Block/Row | Entire card may be one action; selected uses brand boundary | Do group related information. Don't wrap every row in a card. |
| `SnabbitListItem`, `SnabbitListRow`, `SnabbitListValue` | Leading content, title/body/value, trailing action | API-supported density/content variants | Preserve aligned rows and clear action target | Do use for repeated peers. Don't make only the chevron tappable when the row navigates. |
| `SnabbitAccordion` | Header, disclosure state, body | Expanded/collapsed/disabled where supported | Maintains disclosure state; header controls body | Do use for optional detail. Don't hide the main status or CTA. |
| `SnabbitPayoutRow` | Label, amount/value, optional status | Earned/pending/deducted meaning supplied by content/tone | Currency remains aligned and explicit | Do include period/status. Don't use color alone for negative values. |
| `SnabbitProgressBar` | Track, fill, optional label/value | Determinate/indeterminate variants exposed by API | Announce progress meaning and value | Do say what remains. Don't show unexplained progress. |
| `SnabbitPillProgress` | Pill track/steps and label | Package-supported progress states | Compact progress for bounded sequence | Do use for short progress. Don't use as a substitute for navigation history. |
| `SnabbitSummaryCard` | Title, primary metric, supporting rows | Content states supplied by caller | Main value first, supporting detail second | Do keep financial/status meaning explicit. Don't combine unrelated metrics. |
| `SnabbitDate` | Formatted date/value | Package-supported display | Uses localized format supplied by product | Do use one date format per flow. Don't expose backend timestamps. |

### Inputs

| Component | Anatomy | Variants/states | Behavior | Do / don't |
| --- | --- | --- | --- | --- |
| `SnabbitTextField` | Label, input, optional leading/trailing content, helper/error | Package sizes; default/focused/error/success/warning/disabled | Validate at useful moment; keep entered value; move above keyboard | Do show local error and recovery. Don't clear input on retry. |
| `SnabbitPhoneInput` | Country code, number input, label/helper/error | Default/focused/error/disabled/loading at screen level | Use numeric keyboard and clear formatting | Do state expected digits. Don't expose raw server validation copy. |
| `SnabbitPinInput` | Ordered PIN cells, status/helper, resend context | Empty/focused/filled/error/disabled | Paste/autofill where available; error preserves retry path | Do allow correction. Don't trap focus or auto-submit unexpectedly. |
| `SnabbitDatePicker`, `SnabbitDobSelection` | Trigger/fields, selected date, constraints, error | Empty/selected/error/disabled | Explain format and allowed range | Do localize and constrain dates. Don't permit invalid future/past values silently. |
| `SnabbitAudioPlayer` | Play/pause, progress, duration, label | Idle/playing/paused/loading/error | Must have non-audio fallback for essential information | Do expose playback state. Don't autoplay unexpectedly. |

### Navigation and modal surfaces

| Component | Anatomy | Variants/states | Behavior | Do / don't |
| --- | --- | --- | --- | --- |
| `SnabbitTopNav` | Back/close, title, optional actions/progress | Package layouts | Owns top safe area and navigation hierarchy | Do use one title. Don't add a second custom app bar. |
| `SnabbitBottomSheet` | Scrim, optional 40 dp close control, rounded-top panel, caller content | Visible/hidden, scroll-capped at 90% by default | Scrim/back/close dismiss through one callback; preserve safe area | Do use for one focused task. Don't stack sheets or hide a long workflow in one. |

## Expert App Compose wrappers

| Component | Job | Anatomy and variants | Required states/behavior |
| --- | --- | --- | --- |
| `SnabbitScreen` | Standard app shell | Background, optional snackbar host, content with insets | Own system bars/safe areas; do not wrap in extra scaffold chrome without need. |
| `SnabbitHeaderNav` | Expert header/navigation | Leading nav, title/status, optional actions | Use for the established Expert header pattern. |
| `SnabbitBottomTabBar` | Primary app destinations | Home, earnings, refer, profile and notification treatment as configured | Preserve destination order, labels/semantics, and selected state. |
| `SnabbitActionFooter` | Persistent bottom CTA area | Divider/surface, primary and optional secondary action, safe-area padding | Remains stable while content scrolls; loading/disabled belongs to action. |
| App `SnabbitBottomSheet` wrapper | Standard sheet content/padding | Package sheet plus Expert composition | Use the package dismissal and accessibility contract. |
| `PlatformBackHandler` | Cross-platform system-back handling | Platform implementation around one back callback | Keep back behavior equivalent on Android/iOS and route it through the screen/sheet owner. |
| `GeneralErrorState` | Recoverable full-screen/section error | Illustration/icon, title, explanation, retry | Explain what failed and whether retry is safe; never dead-end. |
| `SnabbitConnectivityBanner` | Offline/online condition | Status icon/text and recovery behavior | Persistent while offline; do not show repeated toasts. |
| `SnabbitNavigationCard` | Navigable feature/setting | Leading visual, title/body, trailing cue | Whole card navigates; one destination only. |
| `SnabbitMetricCard` | Operational or financial metric | Label, prominent value, optional detail | Include unit/period and unavailable state. |
| `SnabbitEarningsAccordion` | Expandable earnings breakdown | Summary amount/status and line items | Distinguish earned, pending, and deduction values in text. |
| `SnabbitHotspotCard` | Hotspot/location state | Location/status, distance/context, action | Handles locating, reached, outside area, permission, and error. |
| `SnabbitJobState` | Job lifecycle composition | Status, timer, customer/location/detail, primary action | State model owns accepted/check-in/in-progress/completed behavior; no parallel card. |
| `StadiumProgressPill` | Compact staged progress | Track/steps/current state | Use only for established bounded progress. |
| `SnabbitButtonWithBadge` | Action with count/reward badge | Package button + badge | Badge supplements, never replaces, the action label. |
| `SnabbitGradientTag` | Approved campaign/tier emphasis | Tag content and owned gradient | Domain-specific; not a general status treatment. |

## Legacy Flutter component policy

Canonical Flutter foundations are `AppTheme`, `AppColors`, `AppTextTheme`, `CommonAppBar`, `CommonBottomSheetSetup`, and the established theme button/input styles. The `lib/widgets/` tree also contains domain components for attendance, job lifecycle, payout, go-live, onboarding, referrals, safety, tiering, leave, and disputes.

### Preferred Flutter building blocks

| Need | Existing entry point | Notes |
| --- | --- | --- |
| Screen theme | `AppTheme`, `AppColors`, `AppTextTheme` | Use semantic intent and the shared theme; raw styles are migration debt. |
| App bar | `CommonAppBar` | Preserve established navigation; review against current top-nav pattern. |
| Bottom sheet shell | `CommonBottomSheetSetup` | Reuse within Flutter; do not add another modal shell. |
| Bottom actions | `BottomActionRow`, `ElevatedButtonWithLoader` | Preserve one primary action, disabled/loading, and safe-area behavior. |
| Text input | `TextFormV2` / theme input decoration | Prefer the newer established field in the owning flow. |
| OTP/PIN | `PinputField` | Align resend, error, focus, and loading behavior with login pattern. |
| Date of birth | `DobSelectorV2` | Prefer V2; document any reason to use the older selector. |
| Dropdown | `CustomDropdownV2` | Prefer V2; verify focus, overlay dismissal, and long values. |
| Full/section error | `AppErrorWidget` | Include specific recovery copy; do not show raw API errors. |
| Remote media | `RemoteImageHandler` | Reserve layout and provide deterministic fallback/error. |
| Camera/upload | `PictureCapture` and domain upload widgets | Permission, loading, retake, failure, and privacy states are required. |

Feature folders are the registry for domain compositions: `attendance_flow/`, `job_start_flow/`, `job_in_progress/`, `job_login/`, `payout/`, `go_live/`, `onboarding_form_elements/`, `upload_documents/`, `gamification/`, `tiering/`, `long_leave/`, `raise_dispute/`, and the Kavach/safety modules. Reuse within the owning domain, but do not promote feature-specific visuals to general-purpose patterns without review.

Use this order within a Flutter flow:

1. Shared theme and generic widgets.
2. Existing component in the same domain folder.
3. Closest screen pattern from [SCREEN_PATTERNS.md](./SCREEN_PATTERNS.md).
4. A screen-local composition.
5. A new reusable widget only after completing the component brief.

Known Flutter risks include raw `Color(...)` values, direct `TextStyle(...)`, variable app-bar elevations, duplicate countdown widgets, duplicate dropdowns, duplicate bottom-sheet shells, and feature-owned button styles. Treat these as migration/audit items, not examples to copy.

## Component brief requirement

When no existing component fits, first follow [DESIGN_EXTENSION_PROCESS.md](./DESIGN_EXTENSION_PROCESS.md) to decide whether the solution is a screen composition, variant, domain component, shared component, or intentional one-off.

Use [NEW_COMPONENT_BRIEF_TEMPLATE.md](./NEW_COMPONENT_BRIEF_TEMPLATE.md) before adding a reusable component or a meaningful new variant. The brief must name the missing capability, anatomy, variants, states, interaction contract, tokens, content limits, accessibility, responsive behavior, closest existing components, visual references, lifecycle status, and promotion criteria.
