# New component / pattern brief

Copy this file for any new reusable component, screen pattern, banner, sheet, or interaction. Delete the guidance in parentheses before review.

## Summary

- Name:
- Owner:
- Date:
- Surface: Compose/KMP / legacy Flutter / webview-hosted
- Category: Screen composition / Existing component variant / Domain component / Design-system component / Intentional one-off
- Lifecycle status: Proposed / Experimental / Validated / Promoted / Deprecated / Rejected
- Related flow or screen:
- Why this is needed:

## User moment

(What just happened? What does the expert need to understand or do next?)

- Trigger:
- User goal:
- Success condition:
- Consequence of delay or error:

## Pattern decision

- Existing component or pattern considered:
- Why it is insufficient:
- Is this reusable in two or more flows? Yes / No
- Is this a screen-level composition instead of a new component? Yes / No
- Smallest ownership level: Screen / Domain / App wrapper / Design-system package
- What is genuinely new: Structure / Behavior / State / Semantic token / Visual treatment

## Anatomy

List the visible parts in reading order.

1.
2.
3.

## Token and component mapping

| Element | Approved component | Semantic token / variant | Exception and reason |
| --- | --- | --- | --- |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |

## Visual compatibility

- Nearest screen with the same user moment:
- Canonical Snabbit screen used for visual comparison:
- Existing components shown beside this extension:
- Default-state screenshot/golden:
- State-matrix screenshots/goldens:
- What makes this recognizably Snabbit:

## State matrix

| State | Visual treatment | User action | Copy / accessibility announcement |
| --- | --- | --- | --- |
| Default |  |  |  |
| Focused / pressed |  |  |  |
| Disabled |  |  |  |
| Loading |  |  |  |
| Success |  |  |  |
| Error |  |  |  |
| Empty |  |  |  |
| Offline / permission |  |  |  |
| Timeout / expired |  |  |  |

## Behavior

- Primary action:
- Secondary action:
- Dismissal or back behavior:
- Repeated tap behavior:
- Timeout / expiry:
- Destructive confirmation and recovery:
- What persists after navigation or refresh:

## Content and localization

- Title limit:
- Body/helper limit:
- Button label:
- Long-name or long-translation behavior:
- Numeric, currency, date, and time format:
- Empty/error copy:

## Accessibility and practical use

- Minimum touch target is 48 dp: Yes / No, with reason:
- Meaning is communicated without color alone: Yes / No
- Focus order:
- Screen-reader label or announcement:
- Keyboard and safe-area behavior:
- One-handed reach:

## Lifecycle and promotion

- Initial implementation location:
- Current consumers:
- Review owner:
- Validation evidence:
- Promotion trigger:
- Target if promoted: Domain / App wrapper / Design-system package
- Migration or deprecation plan:

## Review checklist

- [ ] User moment and success condition are clear.
- [ ] Surface and existing pattern are identified.
- [ ] Every visible element maps to an approved token/component.
- [ ] All meaningful states are designed.
- [ ] Time, money, safety, and destructive consequences are explicit.
- [ ] Long content and localization are checked.
- [ ] Accessibility and touch targets are checked.
- [ ] The design was compared with the nearest existing app screen.
- [ ] The design was compared beside existing components at 360 × 800 dp.
- [ ] Category, ownership level, lifecycle status, and promotion criteria are recorded.
- [ ] Exceptions are documented and approved.
