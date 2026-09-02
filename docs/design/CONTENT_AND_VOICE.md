# Snabbit content and voice

## Voice

Snabbit sounds like a capable, respectful coordinator: warm, direct, practical, and honest. The expert should always understand what is happening and what to do next.

- **Warm:** acknowledge the person and their effort without forced cheerfulness.
- **Direct:** lead with the state or action; remove internal terminology.
- **Practical:** include the time, amount, location, or recovery step that changes the decision.
- **Trustworthy:** name consequences and uncertainty. Never claim success before confirmation.
- **Human:** use familiar words and active voice. Do not blame the expert for technical failures.

## Information order

For operational copy, use this order:

1. What happened or what state is active.
2. What the expert needs to do.
3. The important consequence: time, money, attendance, safety, or eligibility.
4. Recovery or what happens next.

Example: “You’re outside the job location. Move closer to the pin, then try check-in again. Your job remains active.”

## CTA language

Use a verb plus a concrete object or outcome.

| Intent | Prefer | Avoid |
| --- | --- | --- |
| Advance | `Review details`, `Choose shift` | `Next`, `Continue` when outcome matters |
| Submit | `Submit documents`, `Confirm attendance` | `Submit`, `Done` |
| Authentication | `Send OTP`, `Verify OTP` | `Proceed`, `Login now` |
| Retry | `Try again`, `Retry check-in` | `OK` |
| Navigation | `View earnings`, `Go to home` | `Click here` |
| Destructive | `Mark absent`, `Reject job`, `Log out` | Euphemisms such as `Skip` when consequences exist |
| Dismiss | `Not now`, `Cancel`, `Close` according to consequence | `Maybe later` for urgent states |

Use sentence case. Keep a phone CTA to roughly 2–4 words when possible. Do not end button labels with punctuation. Use the same verb for the same action across screens.

## Titles, body, and labels

- Titles name the state or task: “Confirm attendance”, “Payout pending”.
- Body copy explains only what is needed for this decision.
- Labels are nouns or short questions; helper copy adds format or consequence.
- Avoid repeating the title in the first body sentence.
- Prefer active voice: “We couldn’t verify your location” rather than “Location could not be verified.”
- Do not expose backend enum names, endpoint language, stack traces, or raw error codes.

## Error messages

Every error should say what happened and what to do. Add whether retrying is safe when it may be unclear.

| Situation | Pattern | Example |
| --- | --- | --- |
| Field validation | Requirement + correction | “Enter a 10-digit mobile number.” |
| Network | State + recovery | “You’re offline. Check your connection and try again.” |
| Location | Specific problem + recovery + task status | “We couldn’t verify your location. Move closer to the job and retry; your job is still active.” |
| Server/unavailable | Honest limitation + recovery | “Attendance is temporarily unavailable. Try again in a few minutes.” |
| Permission denied | Why needed + route forward | “Camera access is needed for your check-in selfie. Allow access in Settings to continue.” |
| Submission uncertain | Do not imply failure/success | “We’re checking whether your attendance was recorded. Don’t submit again yet.” |

Do not say “Something went wrong” alone. Do not blame the user (“You entered wrong”). Do not promise a time to resolution unless the product can guarantee it.

## Empty-state copy

Empty is not error. Name the missing content, set expectation, and give an action only if the expert can change it.

- “No payouts yet. Completed payouts will appear here.”
- “No shifts available right now. Check again later.”
- “No open support issues. New issues you raise will appear here.”

Avoid “Oops”, “Nothing here”, or a generic sad illustration without explanation.

## Success, pending, and confirmation

- Use “Confirmed” only after authoritative confirmation.
- Use “Submitted” or “Under review” when a later decision remains.
- Repeat the essential result: date/time, amount, account, or attendance state.
- State what happens next: “Your shift starts at 10:00 am tomorrow.”
- Celebration should match consequence; routine saved changes need brief feedback, not a full success screen.

## Hindi and English

Use the expert's chosen language consistently within a flow. Avoid unreviewed Hinglish in interface chrome.

- Keep common product/legal terms in English only when research or the approved translation glossary requires it; explain unfamiliar terms in the chosen language.
- Do not concatenate translated fragments around dynamic values. Use complete localized templates.
- Preserve natural Hindi word order and allow expansion; do not force English line breaks onto Hindi.
- Format names, currency, dates, times, and phone numbers independently of translated sentence fragments.
- Audio or image-based guidance must have equivalent readable text.
- Remote-config/backend copy must use approved localization keys or be reviewed as content; it does not bypass these rules.

Example patterns:

| English | Hindi |
| --- | --- |
| `Confirm attendance` | `उपस्थिति कन्फर्म करें` |
| `Try again` | `फिर से कोशिश करें` |
| `View earnings` | `कमाई देखें` |

These examples establish tone, not a complete glossary. Product/content review owns final translations.

## Capitalization and punctuation

- Use sentence case for titles, labels, tags, and CTAs.
- Use periods for complete explanatory sentences; omit periods from buttons, short labels, and standalone status tags.
- Use one exclamation mark only for a genuinely celebratory moment; never in warnings or errors.
- Avoid ALL CAPS except legally required acronyms or established identifiers such as OTP, PAN, UPI, or SOS.
- Use the proper multiplication sign (`×`) only in measured dimensions; do not use it as a close-button label.
- Avoid ampersands in prose; use “and”.

## Numbers, money, dates, and time

- Use Indian grouping and the rupee sign: `₹1,250`, `₹12,500`.
- State whether an amount is earned, estimated, pending, deducted, or unavailable.
- Pair durations with units: `15 min`, `2 hr`; use localized units in Hindi.
- Use one time format in a flow, for example `10:00 am–6:00 pm`; do not mix `18:00` and `6:00 pm`.
- Include the date when “today” or “tomorrow” could become ambiguous after midnight or refresh.
- Never expose raw ISO dates or timestamps.

## Content review checklist

- [ ] The current state is the first thing the expert reads.
- [ ] The primary CTA names its outcome.
- [ ] Time, money, attendance, safety, and destructive consequences are explicit.
- [ ] Error copy contains a recovery step and does not blame the expert.
- [ ] Success is not claimed before confirmation.
- [ ] English and Hindi have been reviewed as complete messages.
- [ ] Dynamic values and long translations wrap without losing meaning.
- [ ] Capitalization, punctuation, date/time, and currency formats are consistent.

