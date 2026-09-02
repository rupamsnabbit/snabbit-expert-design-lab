# Golden reference families

These are the preferred starting points for new Expert App work. They are reference families, not permission to copy every legacy detail. Use the closest user moment, inspect the current code/Figma, and check known inconsistencies in [SCREEN_INVENTORY.md](./SCREEN_INVENTORY.md).

## Current reference set

| Family | Prefer for | Primary implementation references | Evidence status | Important caution |
| --- | --- | --- | --- | --- |
| Home | Operational hierarchy, current state, priority actions, banners | `shared/.../features/home/presentation/HomeScreen.kt`, `features/home/presentation/ui/`, `HomeScreenScreenshotTest.kt` | Preferred by product designer; expand committed goldens | Use Partner Home only for domain behavior when its raw Flutter styling conflicts with current tokens |
| Job lifecycle | Assigned, check-in, in-progress, completion, persistent actions | `shared/.../features/job/presentation/JobScreen.kt`, `shared/.../ui/components/SnabbitJobState.kt`, job presentation subfolders | Preferred; Check-in screenshot test exists | Choose the reference matching the lifecycle moment; do not collapse consequential states into one generic card |
| Attendance confirmation | Confirm/change attendance, explain earnings impact, recover from failure | `features/home/presentation/ui/sheets/MarkTomorrowAttendanceSheet.kt`, `ChangeAttendanceConfirmSheet.kt`, `EarningLossSheet.kt`, `AttendanceSheetShell.kt` | Preferred; captures required | Preserve consequence clarity and confirmation hierarchy; audit all state goldens before promotion |
| Bottom sheets | Sheet shell, action placement, dismissal, high-consequence confirmation | `shared/.../ui/components/SnabbitBottomSheet.kt`, `AttendanceSheetShell.kt`, `CheckInSheet.kt`, `CheckoutSheet.kt` | Preferred component family; captures incomplete | Select by behavior, not appearance; destructive and non-dismissible sheets need explicit rules |
| Payout summary | Amount hierarchy, breakdown rows, status and explanation | `lib/payout/widgets/earnings_summary_view.dart`, `final_payout_view.dart`, `payout_breakdown.dart`, `lib/widgets/payout/` | Preferred information pattern; legacy visual audit required | Adapt information architecture, then map it to current tokens/components; do not reuse raw elevation or campaign styling |
| Success and error | Clear outcome, recovery action, status semantics | `shared/.../ui/components/GeneralErrorState.kt`, `features/job/presentation/checkin/SuccessfulCheckIn.kt`, `features/shift/presentation/login/ErrorSheet.kt` | Preferred family; captures required | Do not use a generic success/error treatment when money, safety, attendance, or job consequences need domain-specific explanation |

`shared/...` abbreviates `shared/src/commonMain/kotlin/com/snabbit/runner/shared/`.

## How to use a golden reference

1. Match by user moment and behavior before visual resemblance.
2. Compare with the relevant component and token documentation.
3. Use at least one domain-near reference. For a new pattern, also compare with a general hierarchy reference such as Home or a current bottom sheet.
4. Preserve proven information hierarchy and interaction grammar, then adapt content and domain behavior.
5. Do not copy a known inconsistency, an isolated campaign treatment, or a legacy hardcoded value.

External references may contribute a useful interaction or information-architecture idea. Record the insight in the design brief, but express it using Snabbit foundations.

## Promoting a reference

A screen/state becomes an approved golden only when:

- the design owner confirms it represents the intended quality;
- its key states use deterministic fixtures;
- a stable 360 × 800 dp capture or golden is committed;
- long content and meaningful error/disabled states are reviewed;
- its inventory row records known exceptions.

Until then, label it “preferred; capture required” rather than treating it as unquestionable source material. Add new evidence to the screenshot registry in [SCREEN_INVENTORY.md](./SCREEN_INVENTORY.md).
