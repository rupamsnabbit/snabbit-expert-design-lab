# Screen / experience design brief

Use this lightweight brief for a new screen or meaningful redesign. Save an approved brief as `docs/design/briefs/<kebab-case-name>.md`. Keep it concise enough to review in one sitting; delete guidance that does not apply.

## Decision

- Project / branch:
- Status: Draft / Needs decision / Approved / Implemented / Validated
- Surface: Compose/KMP / Flutter / hosted
- Screen or flow:
- PRD / Figma / references:
- Recommended direction in one sentence:

## Problem and user moment

- What is the user trying to do?
- What happened immediately before this moment?
- What must they understand within two seconds?
- What is the primary action or outcome?
- What is the consequence of delay, failure, or a wrong choice?
- How will we know the design is successful?

## Current experience

- What already works and should be preserved?
- What causes confusion, friction, inconsistency, or weak hierarchy?
- Evidence or assumption behind each important observation:

## Reference synthesis

| Reference | Pattern worth adapting | Why it fits this user moment | What not to copy |
| --- | --- | --- | --- |
| Snabbit |  |  |  |
| External, if used |  |  |  |

External references inform the solution; Snabbit tokens and patterns determine its visual expression.

## Proposed experience

Describe the recommended layout and interaction in reading order.

1.
2.
3.

- Primary CTA:
- Secondary/recovery action:
- Navigation, back, and dismissal behavior:
- Important content or voice decision:
- Why this direction is stronger than the main alternative:

## Reuse and extension map

| Need | Existing component/pattern/token | Decision |
| --- | --- | --- |
|  |  | Reuse / Compose / Extend / New local decision |

- Nearest golden reference family:
- Exact capability the current system cannot express, if any:
- Gap classification: None / Screen composition / Variant / Domain component / Design-system component / Intentional one-off
- Extension brief required: Yes / No

If yes, copy [NEW_COMPONENT_BRIEF_TEMPLATE.md](./NEW_COMPONENT_BRIEF_TEMPLATE.md) into `docs/design/extensions/`.

## State and edge-case map

| State | What the user sees | Available action | Notes |
| --- | --- | --- | --- |
| Default |  |  |  |
| Loading |  |  |  |
| Empty |  |  |  |
| Success |  |  |  |
| Error / recovery |  |  |  |
| Disabled |  |  |  |
| Offline / permission |  |  |  |
| Timeout / expired |  |  |  |
| Long/localized content |  |  |  |

Mark a state `N/A` only with a short reason.

## Frontend review plan

- Fixture names:
- Preview route / selector / golden test:
- Baseline capture: 360 × 800 dp
- Additional widths: 320 and 412 dp
- Accessibility checks:
- Screenshots/goldens to capture:
- Backend dependency: None for design review

## Decisions needed before implementation

List only choices whose answers materially change the experience.

1.

## Approval

- Approved direction:
- Approved by / date:
- Exceptions accepted:
- Follow-up questions or experiments:
