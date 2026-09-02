# Design QA checklist

Use this checklist before design approval and again before merging frontend implementation. Record exceptions in the component brief or screen inventory; do not silently waive a row.

## Source and consistency

- [ ] The design-system package was checked first.
- [ ] Relevant design principles, tokens, component library, screen pattern, screen inventory, content rules, and fixtures were read.
- [ ] Existing components are reused wherever they correctly express the need.
- [ ] Every visible color, type role, spacing, radius, border, icon size, and button size maps to a documented token/component.
- [ ] No arbitrary `Color`, `TextStyle`, spacing, elevation, or interaction pattern was introduced.
- [ ] Any new local decision has a completed brief, reason, owner, and path to the shared system.
- [ ] A missing-system solution is classified as a screen composition, variant, domain component, shared component, or intentional one-off.
- [ ] Experimental extensions record lifecycle status, validation evidence, and a promotion or removal trigger.
- [ ] The screen was compared with the closest consistent Snabbit screen, not an isolated legacy exception.

## Hierarchy and interaction

- [ ] The current state is understandable within two seconds.
- [ ] There is one obvious primary CTA per decision area.
- [ ] CTA labels name the outcome and follow the content guide.
- [ ] Secondary/destructive actions have the correct hierarchy.
- [ ] Time, money, attendance, safety, and irreversible consequences are visible before commitment.
- [ ] Back, close, scrim, cancellation, and interrupted-session behavior are defined.
- [ ] Duplicate taps and duplicate responses do not submit or navigate twice.
- [ ] Scroll content remains clear of persistent footers and system gestures.

## Complete states

- [ ] Default state is implemented and fixture-backed.
- [ ] Loading preserves layout and blocks unavailable actions.
- [ ] Empty state is distinguished from error and sets an expectation.
- [ ] Success reflects authoritative completion and explains what happens next.
- [ ] Error identifies the problem, recovery, and whether retry is safe.
- [ ] Disabled state is readable and its reason is apparent.
- [ ] Offline/permission states have a recovery path.
- [ ] Timeout/expiry, cancellation, and partial/uncertain completion are covered when relevant.
- [ ] Refresh does not unnecessarily discard existing content or user input.

## Content and localization

- [ ] Copy is warm, direct, practical, trustworthy, and non-blaming.
- [ ] No raw backend enums, error strings, or internal terminology are exposed.
- [ ] Sentence case, punctuation, currency, date, time, and duration formats are consistent.
- [ ] English and Hindi are reviewed as complete localized messages.
- [ ] Long names, addresses, amounts, translations, and two-line labels are tested.
- [ ] Dynamic values do not create broken grammar or ambiguous truncation.

## Accessibility

- [ ] Every interactive target is at least 48 × 48 dp.
- [ ] Text and essential UI have readable contrast in every state.
- [ ] Meaning is not communicated through color alone.
- [ ] Icons without obvious universal meaning have text or accessible labels.
- [ ] Reading/focus order follows visual order.
- [ ] Controls expose role, label, state, value, and action to accessibility services.
- [ ] Important async state changes are announced.
- [ ] Font scaling does not clip essential copy or controls.
- [ ] Motion respects reduced-motion settings and essential information is available without animation/audio.

## Android and responsive behavior

- [ ] The screen works at 320, 360, and 412 dp widths; primary sign-off uses 360 × 800 dp.
- [ ] Status/navigation bars, display cutouts, keyboard, and bottom gesture inset are handled.
- [ ] Portrait layout works with short height and scrolls correctly.
- [ ] Cards and content use one consistent 16 or 24 dp screen grid.
- [ ] Bottom-sheet content fits or scrolls below the 90% height cap.
- [ ] Loading, keyboard, and validation do not cause disruptive layout jumps.
- [ ] One-handed reach is reasonable for the primary action.

## Domain safety checks

- [ ] Attendance changes show date, shift, and earnings/penalty impact.
- [ ] Job states show current stage, time pressure, and valid next action.
- [ ] Payouts label earned, pending, estimated, deducted, failed, and unavailable values in text.
- [ ] SOS/safety actions define confirmation, active state, cancellation, background/return, and failure recovery.
- [ ] Location/camera/notification permissions explain why access is needed and how to recover after denial.

## Evidence and handoff

- [ ] Frontend-only fixtures cover all relevant states and contain no production data.
- [ ] The screen inventory includes route, purpose, component families, fixture, status, screenshot, and known inconsistencies.
- [ ] A screenshot/golden exists at a realistic Android size, or “capture required” is recorded.
- [ ] Design and implementation use the same names for components and states.
- [ ] Automated tests cover important state transitions; visual regression coverage is added where layout is high-risk.
- [ ] Documentation was updated for any reusable decision.

## Approval result

- Reviewer:
- Date:
- Screen/component:
- Result: Approved / Changes required / Approved with documented exception
- Exception link:
