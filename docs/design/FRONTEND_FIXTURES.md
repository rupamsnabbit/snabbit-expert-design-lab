# Frontend fixtures

## Purpose

Frontend fixtures are deterministic, frontend-owned review states. They let design, product, and engineering review UI without depending on authentication, a live backend, current time, remote config, or production data.

Fixtures are not production fallback data. Production distribution must not activate them, and fixture data must never be uploaded as real expert/customer data.

## Existing fixture entry points

### Flutter frontend preview

- Mode gate: `lib/config/frontend_preview.dart`
- Preview route: `/frontend-preview`
- Preview home: `lib/pages/frontend_preview/frontend_preview_home.dart`
- Current coverage: Getting Started, login/OTP, and Learn More.
- Contract: no API, authentication, OTP service, or production session is required for the preview path.
- Current gate: enabled by default in debug and available through the explicit `FRONTEND_ONLY` build define. Production release pipelines must leave this define off or use a dedicated non-production flavor.

### Flutter runner current-state stubs

- Fixture source: `lib/debug/runner_app_current_state_stubs.dart`
- Activation UI: debug menu at `/debug_menu`
- Transport seam: `GlobalState.debugStubRunnerAppCurrentStateBody`, consumed by `RunnerHttp.runnerAppCurrentState`
- Safety: guarded by `kDebugMode`; release must use the real service.
- Contract test: `test/unit/services/runner_app_current_state_stub_test.dart`

Available named states:

| Domain | Fixture states |
| --- | --- |
| Attendance | `attendanceTomorrow`, `attendanceToday`, `attendanceAbsent`, `attendanceAbsentProvisionalToday`, `attendanceAbsentNoShow`, `attendanceConfirmed` |
| Job assignment | `newJobAssigned`, `newJobAssignedLastHour`, `jobCancelled` |
| Login/location | `selfieCheck`, `loginLocation`, `loginHotspot`, `stubTestEarlyLogin`, `waitHotspot` |
| Job lifecycle | `jobPostAccept`, `jobCheckIn`, `jobInProgress`, `postCheckout`, `preMarkArrival` |
| Shift/lunch | `logout`, `lunch`, `lunchRequest`, `lunchCooldown`, `seeYouTomorrow` |
| Account/system | `suspended`, `errorWidget` |

### Compose/KMP test fixtures and screenshots

KMP feature tests contain deterministic view-model/repository fixtures. Approved rendered references currently live in `shared/src/androidUnitTest/snapshots/` for AWOL states, with screenshot tests for AWOL, Home, and Check-in. Add new golden images beside those tests when the Compose surface is the owner.

## Required fixture matrix

Every new screen or reusable component must cover the applicable rows. “Not applicable” must be explicit in the design brief.

| State | Fixture requirement | Review expectation |
| --- | --- | --- |
| Default | Typical valid content | Primary hierarchy and normal action |
| Loading | Initial and/or refresh load | Stable layout; duplicate actions blocked |
| Empty | Valid zero-data response | Clear expectation and optional next action |
| Success | Authoritatively completed action | Result, essential summary, next step |
| Error | Recoverable and non-recoverable variants | Specific explanation and recovery |
| Disabled | Visible action unavailable | Reason is apparent; contrast and semantics remain readable |
| Offline | No connectivity before and during action | Persistent status and safe retry path |
| Permission | Denied, permanently denied, restored | Rationale and Settings/retry path |
| Long content | Long name, address, Hindi copy, large amount | Wrapping, truncation, scrolling, alignment |
| Slow response | Delayed completion without fake progress | Honest loading and timeout behavior |
| Duplicate action | Repeated tap / repeated response | Idempotent UI and no double navigation |
| Expired | Timer/OTP/job/action expires | State changes clearly and offers a valid path |

## Domain fixture contracts

### Attendance

Cover today/tomorrow, present/confirmed, absent, provisional absent with change allowed, no-show with red cards/penalty, change unavailable, submission loading, submission error, offline, disabled/expired, and long shift text. Include earnings or penalty values when they affect the decision.

### Jobs

Cover assigned, last-hour assigned, accepted, travelling/hotspot, pre-arrival, check-in, delayed/outside-location check-in, in progress, lunch overlap, checkout, post-checkout/rating, cancelled, suspended, and action error. Use obviously fictional customer details and non-sensitive phone/location data.

### Payouts

Cover no earnings, earned, estimated, pending, deducted, payout processing, payout failed, payout complete, bank/UPI missing, verification pending/failed, withdrawal disabled, and unusually large/zero/negative display values.

### Forms and login

Cover empty, partially entered, valid, invalid, keyboard open, submission loading, field error, server error, offline, permission denied, saved/resumed, wrong/expired OTP, resend countdown, and attempt limit.

## Fixture data rules

- Use stable identifiers and fixed clock values. Inject “now” for timers rather than calling wall-clock time inside a fixture.
- Use fictional names, phone numbers, addresses, bank/UPI/PAN/Aadhaar values, and job IDs. Never copy production payloads into the repository.
- Include boundary values: zero, one, many, long text, absent optional fields, and maximum realistic amounts/counts.
- Match the production domain model or transport schema at the seam under review. Do not let fixtures create a separate UI-only model unless the production UI also uses it.
- Keep each fixture small and named by user-visible state, not ticket number.
- Keep fixture activation debug/test/design-build-only and visibly indicate fixture mode. Production distribution must prohibit the frontend-only build define.
- Do not make random fixture values; deterministic rendering is required for review and golden tests.

## Where new fixtures belong

| Scope | Location |
| --- | --- |
| Flutter screen preview navigation | `lib/pages/frontend_preview/` |
| Flutter current-state API envelopes | `lib/debug/runner_app_current_state_stubs.dart` |
| Flutter unit/widget fixture builders | `test/unit/...` near the domain tests |
| KMP view-model/domain fixtures | `shared/src/commonTest/...` near the feature |
| KMP Android screenshot fixtures/goldens | `shared/src/androidUnitTest/...` and `shared/src/androidUnitTest/snapshots/` |

Do not add a second global fixture registry. Extend the closest existing seam and add a link from the screen inventory.

## Definition of done for a fixture-backed screen

- [ ] It opens without a production login or backend dependency.
- [ ] Default, loading, empty, success, error, and disabled are covered or marked not applicable.
- [ ] Domain states such as attendance/job/payout transitions are covered.
- [ ] Offline, permission, timeout, and duplicate-tap behavior are covered when relevant.
- [ ] Data is fictional, deterministic, and safe to commit.
- [ ] Long English/Hindi content and Android widths are represented.
- [ ] The route and fixture names are recorded in [SCREEN_INVENTORY.md](./SCREEN_INVENTORY.md).
- [ ] The production distribution configuration cannot activate the fixture; any release-mode design build is isolated and visibly non-production.
