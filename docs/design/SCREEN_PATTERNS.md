# Snabbit screen patterns

## Shared screen anatomy

Unless a documented operational state needs a different hierarchy, use:

1. `SnabbitScreen`/app shell and top safe area.
2. Top navigation with one title and back/close when needed.
3. Scrollable content using one 16 or 24 dp horizontal grid.
4. Current state or task context before supporting detail.
5. Inline validation or persistent status near the affected content.
6. A stable bottom action footer with one primary CTA and safe-area clearance.

Loading must preserve the layout footprint. Error recovery must not discard entered data. Long content scrolls behind a stable footer with enough bottom content padding.

## Login and OTP

**Use for:** phone-number entry, OTP verification, and session recovery.

- Top: brand or concise screen title; back only when there is a meaningful previous step.
- Body: one instruction, phone/PIN input, local helper/error, and resend/change-number action.
- Bottom: full-width primary action, M or L height.
- CTA language: “Send OTP”, “Verify OTP”, “Try again”; avoid generic “Submit”.
- States: empty, valid, invalid phone, sending, OTP sent, autofill, wrong/expired OTP, resend countdown, offline, too many attempts, disabled, success.
- Keep the number visible on OTP entry and provide “Change number”. Never imply an OTP was sent until the request succeeds.

## Forms and onboarding tasks

**Use for:** registration, personal/family/bank/insurance details, selections, permissions, and document steps.

- Use one question or coherent group per screen.
- Put label above input; helper/error below it.
- Use selection cards for choices that require explanation, radio for one choice, checkbox for many.
- Keep progress meaningful and consistent across the flow.
- Validate locally when possible, on blur or CTA for complex fields; focus the first invalid field.
- Persistent footer: action label names the next outcome (“Review details”, “Verify bank account”).
- States: initial, partially complete, invalid, saving, saved, submission error, offline, permission denied, disabled, resume with saved values.

## Cards and grouped content

**Use for:** status, metrics, navigation, summaries, and bounded information groups.

- Base cards use 12 dp radius and 1.5 dp subtle border through `SnabbitCard`.
- Selected cards use the Selected variant and a non-color indicator when needed.
- Use 12 or 16 dp internal padding and 8/12/16 dp internal gaps.
- A clickable card has one destination/action and the entire card is the target.
- Avoid card-in-card nesting. Use dividers/spacing for rows inside one group.
- Do not place decorative elevation on routine cards.

## Bottom sheets

**Use for:** a focused confirmation, picker, short explanation, recovery choice, or permission rationale.

- Use `SnabbitBottomSheet`; default maximum height is 90% of viewport.
- Anatomy: dismiss control when allowed, title, one-sentence context, focused content, optional secondary action, primary action, bottom safe area.
- Scrim tap, back, and close invoke the same dismissal path. Block dismissal only for a truly non-interruptible step and document why.
- Sheet content scrolls; the action area stays reachable.
- Do not stack sheets. Close the first sheet before navigating or opening another.
- States: opening, default, action loading, validation error, success/dismissal, offline, interrupted.

## Empty states

**Use for:** expected absence of records or a first-use state—not request failure.

- Anatomy: optional helpful illustration, specific title, one short explanation, primary action only when the user can change the state.
- Say what is empty (“No payouts yet”), why when useful, and what happens next.
- Do not use a sad/error visual for an expected first-use state.
- Keep global navigation available unless the empty state belongs to a blocking task.

## Error states

**Inline error:** place next to the affected input or row.

**Section error:** preserve unaffected content; replace only the failed section and offer retry.

**Full-screen error:** use `GeneralErrorState` when the screen cannot function.

Every error answers: what happened, what the expert can do now, and whether retrying is safe. Distinguish offline, permission, timeout, validation, unavailable, and unknown failures. Never show raw API copy or error codes as the main message.

## Confirmation screens

**Use for:** completed registration/action, attendance confirmed, shift selected, payout/bank setup, or other meaningful result.

- Lead with the result and its status icon/illustration.
- Show the essential summary: date/time, amount, destination, or attendance state.
- Explain what happens next.
- Primary CTA goes to the next useful destination; secondary action is optional.
- Do not use green success treatment for pending review. Name it “Submitted” or “Under review”.
- States: confirmed, submitted/pending, partial success, duplicate request, follow-up unavailable.

## Loading screens and skeletons

- Use a full-screen loader only for startup or a blocking transition with no meaningful shell.
- For content refresh, keep navigation and stable layout visible; use skeletons/placeholders matching final geometry.
- Keep existing data visible during non-destructive refresh where safe.
- Button loading keeps the label and blocks duplicate taps.
- After a reasonable delay, add honest status or recovery; never show false percentage progress.
- Define timeout, offline, and retry behavior for every blocking load.

## Navigation and CTA hierarchy

- Bottom navigation owns primary app destinations. Do not duplicate those destinations as a new local nav bar.
- Top navigation owns back/close and screen title.
- One primary CTA per decision area: brand Primary for normal action, Destructive for irreversible danger, Success only for an explicitly positive completion action.
- Secondary/tertiary actions must not compete with Primary.
- Use Link/Text Link for low-emphasis navigation or help, not the main completion action.
- Back preserves safe progress unless the user explicitly discards it. Confirm discard only when data loss is real.
- A bottom footer is persistent for task completion and includes 16 dp top/horizontal padding plus safe area.

## Operational home

Home is a state surface, not a generic dashboard. For every state define status, next action, countdown meaning, earnings/job impact, and recovery.

Supported review states include attendance tomorrow/today/absent/confirmed, new job, last-hour job, wait for hotspot, selfie/login location/login hotspot, job accepted/check-in/in progress/post-checkout, lunch/request/cooldown, logged out, see-you-tomorrow, suspended, cancelled, pre-arrival, and error.

Use existing `SnabbitJobState`, attendance components, hotspot/location components, and [FRONTEND_FIXTURES.md](./FRONTEND_FIXTURES.md). Do not build a parallel state card for a state the model already represents.

## Attendance

- Show date and shift time before the decision.
- Present/absent/change actions must explain earnings, red-card, or other consequences before confirmation.
- Confirmed/absent states remain visible and include a clear change path only when allowed.
- Time-sensitive states define expiry and server-refresh behavior.
- Fixtures must cover tomorrow, today, absent, provisional change, no-show/red-card, confirmed, loading, submit error, and disabled/expired.

## Job lifecycle

Use the established sequence: assigned → accepted → travel/hotspot → check-in → in progress → checkout/completion → rating/earnings.

- Make time pressure and the current stage prominent.
- Customer/location information remains stable during refresh.
- Place safety/help actions consistently.
- Rejection, deallocation, late check-in/out, and outside-location states explain consequence and recovery.
- Prevent duplicate acceptance/check-in/checkout.

## Earnings and payouts

- Order: amount, period/status, breakdown, next action.
- Label earned, pending, deducted, unavailable, and estimated values explicitly.
- Use tabular alignment for repeated amounts and consistent Indian currency formatting.
- Provide loading, no earnings, partial data, payout pending, payout failed, bank/UPI missing, disabled withdrawal, and success states.
- Never rely on green/red alone for financial meaning.

## Safety, permissions, and offline recovery

- Safety/SOS screens prioritize the active status and safe action over navigation.
- Permission rationale explains why, what is collected/used, and how to continue after denial.
- Offline state is persistent while it affects the task and must say what remains safe/available.
- Destructive or emergency actions define confirmation, cancellation, duplicate tap, app-background, and return-to-app behavior.

## Responsive and accessibility rules

- Review at 320, 360, and 412 dp widths and at least 800 dp height.
- Minimum interactive target: 48 × 48 dp.
- Support font scaling, two-line CTA labels where allowed, long Hindi/English copy, keyboard, safe area, and system gesture navigation.
- Reading/focus order follows visual order.
- Announce important asynchronous status changes.
- Pair color with text/icon/shape and maintain readable contrast.

