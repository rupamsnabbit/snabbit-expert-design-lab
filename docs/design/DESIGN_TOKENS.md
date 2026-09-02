# Snabbit design tokens

## Contract and ownership

The canonical Compose/KMP source is `com.snabbit:design-system:0.19.0`, declared in `shared/build.gradle.kts`. This document records the package contract used by the app; if code and this page disagree, the installed package wins and this page must be updated in the same change.

For new Compose work, use `SnabbitTheme` semantic values and design-system components. For legacy Flutter work, use `AppTheme`, `AppColors`, and `AppTextTheme` from `lib/utils/`; choose the closest semantic equivalent below. Do not paste a hex value or raw dimension into feature code when an equivalent token exists.

## Colors

### Semantic light-theme colors

| Role | Compose token | Value | Use |
| --- | --- | --- | --- |
| Primary text | `textPrimary` | `#111827` | Titles and highest-emphasis content |
| Body text | `textBody` | `#374151` | Default readable content |
| Secondary text | `textSecondary` | `#6B7280` | Supporting content and metadata |
| Tertiary text | `textTertiary` | `#9CA3AF` | Low-emphasis, non-essential metadata |
| Disabled text | `textDisabled` | `#D1D5DB` | Disabled labels only |
| Inverse text | `textInverse` | `#FFFFFF` | Text on dark or brand fills |
| Brand text/action | `textBrand`, `bgBrand`, `borderBrand`, `iconBrand`, `interactiveDefault` | `#F70F79` | Primary brand action and selected emphasis |
| Brand hover/loading | `interactiveHover` | `#F4368D` | Package-controlled interaction state |
| Brand pressed | `interactivePressed` | `#C70C61` | Package-controlled pressed state |
| Primary canvas | `bgPrimary` | `#FFFFFF` | Screen and card surfaces |
| Secondary canvas | `bgSecondary` | `#F9FAFB` | Subtle grouped surface |
| Tertiary canvas | `bgTertiary` | `#F3F4F6` | Muted/header surface |
| Inverse canvas | `bgInverse` | `#111827` | Dark high-contrast surface/scrim base |
| Brand subtle | `bgBrandSubtle` | `#FEF1F7` | Soft brand callout or selected wash |
| Default border | `borderDefault` | `#E5E7EB` | Standard structural border |
| Subtle border | `borderSubtle` | `#F3F4F6` | Low-emphasis card boundary |
| Strong border | `borderStrong` | `#6B7280` | Strong neutral separation |
| Focus border | `borderFocus` | `#3B82F6` | Keyboard/input focus |
| Success | `textSuccess` | `#059669` | Success text and strong positive amount |
| Success surface | `bgSuccess` / `bgSuccessSubtle` | `#ECFDF5` / `#D1FAE5` | Success callout and emphasis |
| Success border/icon | `borderSuccess` / `iconSuccess` | `#10B981` | Success boundary and icon |
| Warning | `textWarning` | `#D97706` | Attention or waiting text |
| Warning surface | `bgWarning` / `bgWarningSubtle` | `#FFFBEB` / `#FEF3C7` | Warning callout and emphasis |
| Warning border/icon | `borderWarning` / `iconWarning` | `#F59E0B` | Warning boundary and icon |
| Error | `textError` | `#DC2626` | Error or destructive message |
| Error surface | `bgError` / `bgErrorSubtle` | `#FEF2F2` / `#FEE2E2` | Error callout and emphasis |
| Error border/icon | `borderError` / `iconError` | `#EF4444` | Error boundary and icon |
| Information | `textInfo` | `#2563EB` | Informational message and link-like status |
| Information surface | `bgInfo` | `#EFF6FF` | Informational callout |

Use semantic names in specifications. Palette names such as `pink600` or `gray700` are allowed only while building a semantic component token that the package does not yet expose.

### Core palette references

| Family | 50 | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Pink | `#FEF1F7` | `#FDE4EF` | `#FBC9DF` | `#F9AECF` | `#F65CA1` | `#F4368D` | `#F70F79` | `#C70C61` | `#97094A` | `#670632` |
| Gray | `#F9FAFB` | `#F3F4F6` | `#E5E7EB` | `#D1D5DB` | `#9CA3AF` | `#6B7280` | `#4B5563` | `#374151` | `#1F2937` | `#111827` |
| Green | `#ECFDF5` | `#D1FAE5` | `#A7F3D0` | `#6EE7B7` | `#34D399` | `#10B981` | `#059669` | `#047857` | — | — |
| Red | `#FEF2F2` | `#FEE2E2` | `#FECACA` | `#FCA5A5` | `#F87171` | `#EF4444` | `#DC2626` | `#B91C1C` | — | — |
| Yellow | `#FFFBEB` | `#FEF3C7` | `#FDE68A` | `#FCD34D` | `#FBBF24` | `#F59E0B` | `#D97706` | `#B45309` | — | — |
| Blue | `#EFF6FF` | `#DBEAFE` | `#BFDBFE` | `#93C5FD` | `#60A5FA` | `#3B82F6` | `#2563EB` | `#1D4ED8` | — | — |

### Legacy Flutter bridge

`lib/utils/colors.dart` is the current Flutter source. Its neutral scale (`n0`–`n90`) and older success/warning/error scales do not map one-to-one to the package palette. Use semantic intent first:

| Intent | Preferred Flutter token | Migration note |
| --- | --- | --- |
| Brand action | `AppColors.brand` / `p50` (`#F70F79`) | Direct match |
| White surface | `AppColors.n0` | Direct match |
| Primary legacy text | `AppColors.n90` (`#101840`) | Legacy value; do not copy into Compose |
| Secondary legacy text | `AppColors.n70` or `n80` | Select by established screen hierarchy |
| Legacy success | `g50`–`g10` | Use package success semantics for migrated work |
| Legacy warning | `y60`–`y0` | Use package warning semantics for migrated work |
| Legacy error | `r60`–`r0` | Use package error semantics for migrated work |
| Information wash | `AppColors.bgInfo` (`#EFF6FF`) | Direct semantic match |

Feature-specific colors in `AppColors` (tier, Kavach, AWOL, auto-OT, and campaign colors) are approved only in their named domain. They are not general palette tokens.

## Typography

Compose/KMP uses Outfit through `SnabbitTheme`. Do not create another font family.

| Variant | Size / line height | Weight | Use |
| --- | --- | --- | --- |
| `Display` | 32 / 40 sp | SemiBold | Rare hero result or safety state |
| `Heading1` | 28 / 37.3 sp | SemiBold | High-salience screen title |
| `Heading2` | 24 / 32 sp | SemiBold | Major section or result |
| `Heading3` | 20 / 28 sp | SemiBold | Card or section title |
| `Title` | 18 / 24 sp | Medium | Navigation title or prominent label |
| `BodyLg` | 16 / 24 sp | Regular | Primary explanation |
| `BodyMd` | 14 / 20 sp | Regular | Default supporting content |
| `Caption` | 12 / 16 sp | Regular | Metadata and helper content |
| `Small` | 10 / 14 sp | Regular | Compact, non-essential metadata only |
| `ButtonLg` | 16 / 16 sp | SemiBold | Large CTA |
| `ButtonMd` | 14 / 14 sp | SemiBold | Standard/compact CTA |

Legacy Flutter uses `AppTextTheme` and the configured `AppStrings.fontFamily` (Metropolis on existing surfaces). Do not normalize an existing Flutter screen by introducing ad hoc Outfit `TextStyle`s. When migrating a screen, map roles to the Compose scale and preserve hierarchy.

Rules:

- Use sentence case for UI text.
- Use at most three hierarchy levels on one screen.
- Do not use `Small` for actions, errors, payment status, safety guidance, or essential instructions.
- Respect system font scaling and verify two-line labels and titles.

## Spacing

| Token | Value | Typical use |
| --- | --- | --- |
| `0` | 0 dp | Intentional flush alignment |
| `1` | 2 dp | Optical correction only |
| `2` | 4 dp | Tight icon/text or inline gap |
| `3` | 8 dp | Small internal gap |
| `4` | 12 dp | Standard internal gap |
| `5` | 16 dp | Default component padding and screen margin |
| `6` | 20 dp | Large component padding |
| `7` | 24 dp | Section gap or spacious screen margin |
| `8` | 32 dp | Large section separation |
| `9` | 40 dp | Major separation |
| `10` | 48 dp | Touch target or major separation |
| `11` | 64 dp | Rare hero separation |

Named aliases: component padding is 4/8/16/24/32 dp; component gaps are 4/8/12/16 dp; layout padding is 16/24/32 dp; layout gaps are 16/24/32 dp.

Do not add arbitrary 6, 10, 14, 18, or 22 dp layout values. An internal value owned by a design-system component, such as the 6 dp tag gap or 10 dp medium-button radius, is valid through that component and should not become a new global token.

## Corner radius and borders

| Radius token | Value | Use |
| --- | --- | --- |
| `none` | 0 dp | Dividers and intentionally square joins |
| `sm` | 4 dp | Small controls and tags |
| `md` | 8 dp | Inputs and compact controls |
| `lg` | 12 dp | Default card and large control |
| `xl` | 16 dp | Selected card, sheet, prominent surface |
| `xxl` | 24 dp | Large hero surface only |
| `full` | 9999 dp | Pill/avatar/circle |

Border widths are `thin` 1 dp, `thick` 1.5 dp, and `thicker` 2 dp. Use 2 dp for selection or strong emphasis, not as routine decoration.

## Shadows and elevation

The package does not expose a global shadow scale in 0.19.0. The default is flat (`0 dp`) with border/background hierarchy. Use elevation only when the surface must appear above another surface:

| Role | Value | Use |
| --- | --- | --- |
| `flat` | 0 dp | Screens, cards, buttons, app bars |
| `floating` | 4 dp | Floating map/control surface already established in app code |
| `modal` | Component-owned | Use `SnabbitBottomSheet`; do not recreate its scrim/elevation |

Any new shadow value is a local decision that must be documented in the component brief and proposed for the design-system package. Legacy Flutter elevations from 2–10 dp are existing inconsistencies, not reusable tokens.

## Icon sizes and touch targets

Use the design-system icon component and its semantic icon names. Standard visual sizes are 16, 20, 24, 32, and 40 dp. Use 24 dp for normal navigation/action icons and 20 dp in medium controls. A visual icon may be smaller than its hit area, but the interactive target must be at least 48 × 48 dp.

Button-owned icon sizes are 16/18/20/24 dp for XS/S/M/L respectively. Do not override those sizes inside `SnabbitButton`.

## Button sizes

| Package size | Height | Horizontal padding | Radius | Icon | Label |
| --- | --- | --- | --- | --- | --- |
| `XS` | 32 dp | 12 dp | 6 dp | 16 dp | 12 sp Medium |
| `S` | 40 dp | 16 dp | 8 dp | 18 dp | 14 sp Medium |
| `M` | 48 dp | 20 dp | 10 dp | 20 dp | 16 sp SemiBold |
| `L` | 56 dp | 24 dp | 12 dp | 24 dp | 16 sp SemiBold |

Prefer M for standard actions and L for full-width bottom actions. XS and S need a 48 dp parent hit area when interactive. Loading keeps the label visible and adds a spinner. Disabled and loading states must block duplicate taps.

## Grid, screen margins, and safe areas

- Baseline Android review viewport: 360 × 800 dp; also verify 320 dp and 412 dp widths.
- Default horizontal screen margin: 16 dp.
- Use 24 dp only for a deliberately spacious task layout; use one margin consistently within the screen.
- Cards align to the screen grid. Nested content uses 12 or 16 dp internal padding.
- Section gaps use 24 or 32 dp.
- Bottom actions use 16 dp horizontal/top padding plus the system safe-area inset.
- Keep scroll content clear of a persistent footer by the footer height plus safe area.
- Do not center long form content in a fixed-width column on phone surfaces.

## Adding or changing a token

1. Confirm the package has no semantic token for the need.
2. Check this document and the closest existing pattern.
3. Record the proposed name, value, purpose, affected states, contrast, and migration plan in [NEW_COMPONENT_BRIEF_TEMPLATE.md](./NEW_COMPONENT_BRIEF_TEMPLATE.md).
4. Prefer adding the token to the design-system package. If temporarily local, isolate it in the app design-system layer, not a feature file.
5. Update this page, the component library, and affected screenshots in the same change.

