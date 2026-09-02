---
description: Canonical Snabbit Design System component reference (intent → DS component). Loaded by build-feature (UI) and the ui-reviewer agent. This file is the single source of truth for DS component names/variants — no other doc redefines them.
---

# Snabbit Design System — Compose component catalog

Intent → component, for picking the right DS component while building a screen.
Exact signatures live in the DS source (`com.snabbit.design.*`); this maps *what
to reach for*. **Anything visible uses one of these**; material3 is only for
layout primitives. **If nothing fits, STOP and flag it — never hand-roll or drop to material3.**

Package roots: `com.snabbit.design.atoms | molecules | organisms`; theme in
`com.snabbit.design.theme.SnabbitTheme`.

## Text & typography
| Need | Component | Key variants |
|---|---|---|
| Any text | `SnabbitText` (atom) | variant: Display, Heading1/2/3, Title, BodyLg, BodyMd, Caption, Small, ButtonLg, ButtonMd |

## Actions
| Need | Component | Key variants |
|---|---|---|
| Button / CTA | `SnabbitButton` (atom) | style: Primary, Secondary, … (see `SnabbitButtonStyle`); size: XS/S/M/L; `loading`, `fullWidth`, `leadingIcon`/`trailingIcon` |
| Group of buttons | `SnabbitButtonGroup` (molecule) | layout: Row, Column |

## Selection & choice
| Need | Component | Key variants |
|---|---|---|
| Single-choice list (radio rows) | `SnabbitSelectionCard` (molecule) | type=Radio; variant: Default, Selectable |
| Multi-choice list | `SnabbitSelectionCard` (molecule) | type=Checkbox |
| Bare radio / checkbox | `SnabbitRadioButton` / `SnabbitCheckbox` (atoms) | size: S/M/L |
| Filter / choice chip | `SnabbitChip`, `SnabbitSelectionChip` (atoms) | state: Filled/Stroke; display: Repeat/Count |

## Inputs
| Need | Component |
|---|---|
| Text field | `SnabbitTextField` (molecule) |
| Phone number | `SnabbitPhoneInput` (molecule) |
| OTP / PIN | `SnabbitPinInput` (molecule) |
| Date pick | `SnabbitDatePicker` / `SnabbitDobSelection` (molecules); `SnabbitDate` (atom, variant Default/Gray/NoFill) |

## Containers & rows
| Need | Component | Key variants |
|---|---|---|
| Card container | `SnabbitCard` (atom) | layout: Block, Row |
| Generic surface | `SnabbitBox` (atom) | |
| List row (label/value/helper) | `SnabbitListRow` (atom) | helper: Error/Warning |
| Payout amount in a row | `SnabbitListRow` + `SnabbitPayoutValue` | **`SnabbitPayoutRow` is DEPRECATED — use `SnabbitListRow` + `SnabbitPayoutValue` instead** |
| Summary card | `SnabbitSummaryCard` (molecule) | |
| Expand / collapse | `SnabbitAccordion` (atom) | group: Single/Multiple |
| Divider / spacing | `SnabbitDivider` (atom) | type: Line/Dotted/Spacing/Text |

## Status & feedback
| Need | Component | Key variants |
|---|---|---|
| Inline status banner | `SnabbitStatusBanner` (atom) | position: Top/Bottom/Standalone |
| Toast | `SnabbitToast` (atom) | variant: Success/Error/Warning/Info |
| Badge / tag | `SnabbitBadge`, `SnabbitTag` (atoms) | variant: Brand/Success/Error/Warning/Info/Neutral/Purple; tag style: Filled/Soft/Outline |
| Progress | `SnabbitProgressBar` (atom) / `SnabbitPillProgress` (molecule) | style: Linear/Segmented; variant: Neutral/Brand/Success/Warning/Error |
| Tooltip | `SnabbitTooltip` (atom) | |

## Media & misc
| Need | Component |
|---|---|
| Avatar | `SnabbitAvatar` (atom) — size S/M/L |
| Icon | `SnabbitIcon` (atom) |
| Audio player | `SnabbitAudioPlayer` (molecule) — **androidMain only; never referenced in commonMain** |

## Navigation / chrome
| Need | Component |
|---|---|
| Top bar | `SnabbitTopNav` (organism) — use it **via `SnabbitScreen(title =, subtitle =, onNavigateUp =, actions =)`**, not directly |
| Screen scaffold (theme + bg + top nav + insets + snackbar) | `SnabbitScreen` (`com.snabbit.runner.shared.ui`) — **mandatory wrapper for every screen** |

## Overlays, media & rich text (added with the Kavach feature)
| Need | Component | Key props |
|------|-----------|-----------|
| Modal bottom sheet | `SnabbitBottomSheet` (organism) | `visible`, `onDismissRequest`, `showClose`, `showDragHandle`, `content` (ColumnScope) — overlays a screen, driven by state |
| Local image (drawable / vector / bitmap) | `SnabbitImage` (atom) | `painter` / `imageVector` / `bitmap`, `contentScale`, `alignment`, `shape` |
| Remote / async image | `SnabbitRemoteImage` (atom) | `model`, `loading` / `error` slots, optional `imageLoader` (Coil-backed) |
| Lottie animation | `SnabbitLottie` (atom) | `spec: LottieCompositionSpec`, `iterations`, `speed`, `isPlaying` (Compottie) |
| Rich / segmented text | `SnabbitRichText` (atom) | `spans: List<SnabbitRichSpan>` — per-span `style` + optional `onClick`; inline links |

## Theme tokens — never hardcode
- `SnabbitTheme.colors.*` — `bgPrimary`, `textPrimary`/`textSecondary`, `iconBrand`, `borderDefault`, status colors, …
- `SnabbitTheme.typography.*` — set via `SnabbitText(variant = …)` in practice.
- `SnabbitTheme.spacing.*` and `SnabbitTheme.borderRadius.*`.

## Known gaps / open decisions
- **Transient messages:** `SnabbitScreen` currently hosts a **material3 Snackbar**. The DS-native option is `SnabbitToast` — revisit when standardizing feedback.
- Hand-maintained against the DS source; when the DS adds/renames components, update **here** — never in a downstream doc.
