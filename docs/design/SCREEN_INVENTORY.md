# Snabbit screen inventory

## Scope and maintenance

This inventory is the baseline catalog of user-facing Flutter named routes, KMP screen surfaces, and design-review entry points present in the repository on 2026-09-03. The Flutter route list was checked against route constants and `appRoutes` in `lib/main.dart`; some routes are pushed inline or nested under the Go Live controller rather than registered at the root.

Update a row in the same change that adds, removes, migrates, or materially redesigns a screen. A completed row needs: screen name, route/entry point, purpose, screenshot, components, design status, fixture, and known inconsistency.

### Status legend

| Status | Meaning |
| --- | --- |
| Preview | Intentionally available in frontend-only review mode |
| Current Flutter | Active Flutter surface following a newer domain pattern; still audit against tokens |
| Legacy Flutter | Existing supported surface; do not copy unreviewed raw styles |
| KMP current | Compose/KMP surface using the shared package and app wrappers |
| Hosted | App-shell route whose content is external/embedded |
| Debug only | Never a production destination |
| Capture required | No approved screenshot is committed yet |

### Component-family shorthand

| Label | Main components/patterns |
| --- | --- |
| App shell | `AppTheme`/`SnabbitScreen`, top navigation, safe areas |
| Form | Text/phone/PIN/date inputs, selection controls, persistent CTA |
| Selection | Selection cards/radio/chips, progress, persistent CTA |
| Status | Illustration/icon, status copy, summary, recovery/next CTA |
| Payout | Amount/metric cards, payout rows, accordions, period/status controls |
| Operational | Attendance/job/hotspot/countdown/status components and action footer |
| Sheet | Standard bottom-sheet shell, focused content, actions |
| Webview | Native app shell, webview loading/error/recovery |

“Capture required” is an explicit documentation gap, not approval evidence. New or changed screens must add a 360 × 800 dp screenshot/golden where practical.

## Design review and entry

| Screen | Route / entry | Purpose | Screenshot | Components | Status / fixture | Known inconsistency |
| --- | --- | --- | --- | --- | --- | --- |
| Loader | `loader` | Blocking application startup | Capture required | App shell, loader | Legacy Flutter | Full-screen loading behavior needs token/state audit |
| Frontend preview | `/frontend-preview` | Backend-free design review launchpad | Capture required | App shell, cards, list rows | Preview; `FrontendPreview` | Covers only Getting Started, login/OTP, Learn More |
| Debug menu | `/debug_menu` | Apply local current-state stubs and debug controls | Not required for product QA | Debug controls | Debug only; runner state stubs | Must remain unavailable in release |
| Getting Started | `/getting_started` | Product entry and onboarding start | Capture required | App shell, brand content, CTA | Preview + Legacy Flutter | Audit type, spacing, and CTA against current package |
| Learn More | `/learn_more` | Explain onboarding/product context | Capture required | App shell, informational content | Preview + Legacy Flutter | Long-copy/localization review required |

## Authentication and language

| Screen | Route | Purpose | Screenshot | Components | Status / fixture | Known inconsistency |
| --- | --- | --- | --- | --- | --- | --- |
| Select language V2 | `/select_language_v2` | Choose preferred app language | Capture required | Selection, language list, CTA | Legacy Flutter | Duplicates older language surfaces; audit selected state |
| Send OTP | `/send_otp` | Enter phone number and request OTP | Capture required | Form, phone input, CTA | Preview + Legacy Flutter | Preview path is deterministic; production errors need screenshot matrix |
| OTP input | Inline from Send OTP | Verify OTP and recover/resend | Capture required | PIN input, resend, error, CTA | Preview + Legacy Flutter | No named route; document wrong/expired/limit states |
| Language home | `/language-home` | Change language from signed-in app | Capture required | App shell, language list | Legacy Flutter | Align with Select Language V2 or consolidate |
| KMP Language | KMP host destination | Choose app language on migrated surface | Capture required | `SnabbitScreen`, selection, action footer | KMP current | Record host navigation route and parity screenshot |

## Registration and onboarding

| Screen | Route | Purpose | Screenshot | Components | Status / fixture | Known inconsistency |
| --- | --- | --- | --- | --- | --- | --- |
| Personal details | `/personal_details` | Collect core profile details | Capture required | Form, date/input, CTA | Legacy Flutter | Large screen; raw styles and validation audit required |
| Family details router | `/family_details` | Route to family-detail variant | Capture required | Form/selection | Legacy Flutter | Route orchestration should not introduce a visible pattern |
| Married family details | `/family_details_married` | Collect spouse/family details | Capture required | Form, CTA | Legacy Flutter | Duplicate form structures across variants |
| Unmarried family details | `/family_details_unmarried` | Collect relevant family details | Capture required | Form, CTA | Legacy Flutter | Duplicate form structures across variants |
| Divorced family details | `/family_details_divorced` | Collect relevant family details | Capture required | Form, CTA | Legacy Flutter | Duplicate form structures across variants |
| Widowed family details | `/family_details_widowed` | Collect relevant family details | Capture required | Form, CTA | Legacy Flutter | Duplicate form structures across variants |
| Prior experience | `/prior_experience` | Capture past work experience | Capture required | Form/selection, CTA | Legacy Flutter | Long file and custom selection patterns need audit |
| Work experience | `/work_experience` | Capture work-history selection/details | Capture required | Selection/form, CTA | Legacy Flutter | Clarify overlap with Prior Experience |
| Select service | `/select-service` | Select service category | Capture required | Selection cards, CTA | Legacy Flutter | Feature-owned card/shadow treatment |
| Skills | `/skills` | Choose skills | Capture required | Multi-selection, CTA | Legacy Flutter | Validate long translated skill names |
| Customer service | `/customer-service` | Capture customer-service detail/choice | Capture required | Form/selection | Legacy Flutter | Purpose and component contract need product audit |
| Availability details | `/availability_details` | Capture availability | Capture required | Form, time/selection, CTA | Legacy Flutter | Duplicate V2 screen |
| Availability details 2 | `/availability_details_2` | Capture revised availability | Capture required | Form, time/selection, CTA | Legacy Flutter | Decide canonical version |
| Registration code | `/registration-code` | Enter registration/referral code | Capture required | Form, CTA | Legacy Flutter | Duplicate V2 screen |
| Registration code V2 | `/registration-code-v2` | Revised registration-code entry | Capture required | Form, CTA | Legacy Flutter | Decide canonical version |
| Onboarding screen | `/onboarding-screen` | Render configured onboarding module | Capture required | App shell, dynamic content, CTA | Legacy Flutter; backend-shaped | Remote content must not bypass tokens/voice |
| Single onboarding question | `/onboarding_single_question_screen` | Render one configured question | Capture required | Form/selection, progress, CTA | Legacy Flutter; backend-shaped | Dynamic styles/copy require constraints |
| Multiple onboarding questions | `/onboarding-multiple-questions-screen` | Render configured question set | Capture required | Form/selection, progress, CTA | Legacy Flutter; backend-shaped | Long content and saved-progress audit |
| Height and weight | `/height_and_weight_information` | Capture measurements | Capture required | Form, numeric inputs, CTA | Legacy Flutter | Units, validation, and accessibility audit |
| Integrity test | `/integrity_test` | Validate device/app integrity | Capture required | Status, loading, recovery | Legacy Flutter | Technical copy and blocking-load behavior |
| Location change | `map` | Select/change location on map | Capture required | Map, search/pin, CTA | Legacy Flutter | Non-leading slash route; older implementation |
| Location change V2 | `/location_change_v2` | Revised map/location selection | Capture required | Map, search/pin, CTA | Current Flutter | Confirm canonical route and permission states |
| Training slots | `/training_slots` | Select training slot | Capture required | Selection, date/time, CTA | Legacy Flutter | Loading/empty/no-slot fixture missing |
| Training progress | `/training_progress` | Show training completion status | Capture required | Status, progress, CTA | Legacy Flutter | Route class lives in widget-heavy file; state audit |
| Verification display | `/verification_display` | Show registration verification result | Capture required | Status, summary, CTA | Legacy Flutter | Distinguish success, pending, and failed semantics |
| Registration review | `/registration_review` | Review entered registration data | Capture required | Summary/list rows, edit actions, CTA | Legacy Flutter | Ensure all edit destinations and long values work |
| Personal details review V3 | `/personal_details_review_v3` | Review revised personal details | Capture required | Summary/list rows, CTA | Legacy Flutter | Clarify overlap with Registration Review |
| Onboarding status | `/onboarding-status-view` | Show document/onboarding status | Capture required | Status, CTA | Legacy Flutter | App-bar elevation and state semantics inconsistent |
| Onboarding failed | `/onboarding-failed-view` | Explain onboarding failure and retry | Capture required | Error status, recovery CTA | Legacy Flutter | Must avoid dead-end and raw server copy |

## Identity and documents

| Screen | Route | Purpose | Screenshot | Components | Status / fixture | Known inconsistency |
| --- | --- | --- | --- | --- | --- | --- |
| Upload documents | `/upload_documents` | Document checklist/upload flow | Capture required | Upload cards, status, CTA | Legacy Flutter | Many uploader variants; consolidate state contract |
| Upload PAN | `/upload_documents_pan` | Upload PAN document | Capture required | Upload field, preview, status | Legacy Flutter | Align with shared upload pattern |
| Aadhaar details | `/aadhaar-details` | Enter/review Aadhaar details | Capture required | Form, CTA | Legacy Flutter | Sensitive-data masking and validation audit |
| Aadhaar validator | `/aadhaar-validator` | Validate Aadhaar | Capture required | Form/status, CTA | Legacy Flutter | Loading/uncertain result semantics |
| Aadhaar number updater | `/aadhaar-number_updater` | Update Aadhaar number | Capture required | Form, verification CTA | Legacy Flutter | Route naming inconsistent; sensitive data masking |
| Upload Aadhaar photos | `/upload_aadhaar_photos` | Capture/upload Aadhaar images | Capture required | Camera/upload, preview, CTA | Legacy Flutter | Permission, retry, and image-state audit |
| PAN number updater | `/pan-number-updater` | Update PAN | Capture required | Form, verification CTA | Legacy Flutter | Sensitive data masking and error copy |
| Voter ID updater | `/voter_id_updater` | Update Voter ID | Capture required | Form, verification CTA | Legacy Flutter | Route naming and app-bar elevation inconsistent |
| Aadhaar reverification | `/aadhaar-reverification` | Reverify identity using provider flow | Capture required | App shell, status/web bridge, recovery | Current Flutter | Provider/return/uncertain completion need screenshots |
| Identity card | `identity-card` | Display expert identity card | Capture required | Card, profile data, share/view actions | Legacy Flutter | Non-leading slash route; privacy and screenshot policy |
| KMP camera | KMP camera flow | Capture photo/video for a task | Capture required | `SnabbitScreen`, camera controls, status | KMP current | iOS implementation is currently stubbed |
| KMP media preview | KMP camera flow | Review captured media | Capture required | Media, retake/confirm actions | KMP current | Define compression/loading/error visual fixtures |

## Bank, UPI, and insurance registration

| Screen | Route | Purpose | Screenshot | Components | Status / fixture | Known inconsistency |
| --- | --- | --- | --- | --- | --- | --- |
| Bank details | `bank_details` | Bank setup entry/status | Capture required | Form/status, navigation cards | Legacy Flutter | Non-leading slash route; several nested patterns |
| Add bank or UPI | `/add_bank_or_upi_details` | Choose payout method | Capture required | Selection/navigation cards | Legacy Flutter | App-bar elevation and selection audit |
| Enter bank details | `/enter_bank_details` | Add bank account data | Capture required | Form, CTA | Legacy Flutter | Validation, keyboard, sensitive masking |
| Bank account details | `/bank_account_details` | Review bank account | Capture required | Summary, edit/confirm CTA | Legacy Flutter | App-bar elevation and status semantics |
| Enter UPI details | `/enter_upi_details` | Add UPI ID | Capture required | Form, CTA | Legacy Flutter | Validation and failure recovery |
| UPI details | `/upi_details` | Review UPI setup | Capture required | Summary/status, CTA | Legacy Flutter | App-bar elevation and verification states |
| Account OTP verification | `/account_otp_verification` | Verify bank/account OTP | Capture required | PIN input, resend, CTA | Legacy Flutter | Align with login OTP interaction |
| Account confirmation T&C | `/account_confirmation_tnc` | Confirm account terms | Capture required | Terms content, checkbox, CTA | Legacy Flutter | Long legal text and accessibility audit |
| Account details status | `/account-details-status-view` | Show account verification result | Capture required | Status, summary, retry/next CTA | Legacy Flutter | Distinguish submitted/pending/failed/success |
| Insurance details | `/insurance_details` | Collect insurance profile | Capture required | Form, CTA | Legacy Flutter | Duplicate V2 flow |
| Insurance details V2 | `/insurance_details_v2` | Revised insurance details | Capture required | Form, CTA | Current Flutter | Decide canonical version; fixture matrix missing |
| Children details | `/children-details` | Collect dependent details | Capture required | Form/list, CTA | Legacy Flutter | Nested child flows and long data |
| Single-child details | `/single-child-details` | Collect one dependent | Capture required | Form, CTA | Legacy Flutter | Consolidate with repeatable dependent form |
| Multiple-child details | `/multiple-child-details` | Collect multiple dependents | Capture required | Repeated form/cards, CTA | Legacy Flutter | Add/remove and validation behavior audit |

## Go Live and shift setup

| Screen | Route | Purpose | Screenshot | Components | Status / fixture | Known inconsistency |
| --- | --- | --- | --- | --- | --- | --- |
| Go Live controller | `/go-live-v2` | Own V2 nested flow routing | Not a standalone capture | Nested navigator | Current Flutter | Route/state ownership should remain centralized |
| Region selection | `/go-live-v2/region-selection` | Choose work region | Capture required | Selection, CTA | Current Flutter | Empty/error/long list fixture missing |
| Cluster selection | `/go-live-v2/cluster-selection` | Choose cluster | Capture required | Selection, CTA | Current Flutter | Verify selected state and recovery |
| Cluster no shifts | `/go-live-v2/cluster-selection-no-shifts` | Explain no available cluster shifts | Capture required | Empty status, recovery | Current Flutter | Route shares screen class; copy/next check needed |
| Hood selection | `/go-live-v2/hood-selection` | Choose hood/locality | Capture required | Selection, CTA | Current Flutter | Long locality and search states |
| Shift hours | `/go-live-v2/shift-hours` | Choose shift duration | Capture required | Selection, earnings context, CTA | Current Flutter | Ensure money/time consequence hierarchy |
| Weekend shift hours | `/go-live-v2/weekend-shift-hours` | Choose weekend duration | Capture required | Selection, earnings context, CTA | Current Flutter | Shared screen variant needs parity evidence |
| Shift time selection | `/go-live-v2/shift-time-selection` | Choose shift timing | Capture required | Time selection, CTA | Current Flutter | Disabled/unavailable slot semantics |
| Weekend shift time | `/go-live-v2/weekend-shift-time-selection` | Choose weekend timing | Capture required | Time selection, CTA | Current Flutter | Shared screen variant needs parity evidence |
| Go Live recommendations | `/go-live-v2/recommendations` | Review recommended setup | Capture required | Summary/cards, CTA | Current Flutter | Multiple navigation outcomes need hierarchy audit |
| Weekend recommendations | `/go-live-v2/weekend-recommendations` | Review weekend recommendation | Capture required | Summary/cards, CTA | Current Flutter | Shared screen variant needs parity evidence |
| Confirm shift timings V2 | `/go-live-v2/confirm-shift-timings` | Confirm selected shift | Capture required | Confirmation summary, CTA | Current Flutter | Feature-owned shadows/raw styles need audit |
| Potential earnings | `/potential-earnings` | Preview earnings for a shift | Capture required | Payout/summary, CTA, sheet | Legacy Flutter | App-bar elevation and amount hierarchy |
| Weekend earnings | `/weekend-earnings` | Preview weekend earnings | Capture required | Payout/summary, CTA, sheet | Legacy Flutter | Duplicated structure with Potential Earnings |
| Confirm shift timings | `/confirm-shift-timings` | Confirm legacy shift setup | Capture required | Confirmation summary, CTA | Legacy Flutter | Superseded by V2; clarify deprecation |
| Cluster details | `/cluster-details` | Review cluster and selected shift | Capture required | Summary/cards, CTA | Legacy Flutter | Large screen; mixed old/new patterns |
| Shift timings | `/shift-timings` | Select/review legacy shift timing | Capture required | Selection, CTA | Legacy Flutter | Superseded by V2; app-bar elevation |
| Uniform confirmation | `/uniform-confirmation` | Confirm uniform readiness | Capture required | Confirmation/selection, CTA | Legacy Flutter | Consequence and disabled states need review |
| Terms acceptance | `/tnc-accept` | Review and accept Go Live terms | Capture required | Legal content, checkbox, CTA | Legacy Flutter | Long text, app-bar elevation, rejection path |
| Phone integrity check | `/phone-integrity-check` | Start device readiness checks | Capture required | Status/checklist, CTA | Legacy Flutter | Technical language and loading/error states |
| Device testing | `/device-testing` | Run camera/audio/location/vibration checks | Capture required | Test tiles, progress, status | Legacy Flutter | Permission and partial-failure matrix needed |
| Training details | `/training-details` | Show required training details | Capture required | Content/cards, CTA | Legacy Flutter | App-bar elevation and long copy |

## Home, attendance, jobs, and safety

| Screen | Route / entry | Purpose | Screenshot | Components | Status / fixture | Known inconsistency |
| --- | --- | --- | --- | --- | --- | --- |
| Partner Home | `/partner-home` | Legacy operational home and current-state host | Capture required | Operational, drawer, banners | Legacy Flutter; all runner stubs | Complex state switch; do not add parallel state widgets |
| Attendance | `/attendance` | Attendance history/earnings view | Capture required | Status/list, date/amount | Legacy Flutter | Distinguish from home attendance decision components |
| Selfie login | `selfie-login` | Capture login selfie | Capture required | Camera, permission, CTA | Legacy Flutter; `selfieCheck` | Non-leading slash; camera/error states |
| Selfie preview | `selfie-preview` | Confirm/retake login selfie | Capture required | Image preview, actions | Legacy Flutter | Non-leading slash; upload loading/retry |
| KMP Home | KMP Home tab | Migrated operational home | AWOL references in `shared/src/androidUnitTest/snapshots/` | `SnabbitScreen`, tabs, operational cards, banners | KMP current; KMP tests | Add goldens for non-AWOL home states |
| KMP Job | KMP job host | Assigned/check-in/in-progress/completed flow | Check-in screenshot test; committed capture audit required | `SnabbitJobState`, action footer, status/sheets | KMP current; view-model fixtures | Record all lifecycle goldens and host route |
| KMP Shift Login | KMP shift flow | Start shift/login requirements | Capture required | `SnabbitScreen`, status, action footer | KMP current | Host route and fixture matrix need inventory detail |
| KMP Emergency Logout | KMP shift flow | Consequential emergency logout | Capture required | Status, confirmation sheet, destructive action | KMP current | Verify failure/uncertain/return states |
| KMP Safety Home | KMP Kavach destination | Show safety protection state | Capture required | Safety cards/sheets, status | KMP current | Domain-specific blue is not general brand color |
| KMP SOS Active | KMP Kavach SOS flow | Show active emergency state and actions | Capture required | Destructive/tertiary buttons, status, media | KMP current | High-consequence background/interrupt tests required |
| KMP Block List | KMP blocklist destination | View blocked customers | Capture required | List rows, empty/error, navigation | KMP current | Host route and unblock state fixture needed |
| KMP Unblock to Block | KMP blocklist flow | Manage customer block/unblock transition | Capture required | Form/status, action footer | KMP current | Naming and confirmation hierarchy need product review |
| KMP Coming Soon | KMP internal destination | Explain unavailable destination | Capture required | Status/empty | KMP current | Should not become a generic substitute for unfinished error states |

Runner current-state fixtures for the operational home: attendance tomorrow/today/absent/provisional/no-show/confirmed; new and last-hour job; see-you-tomorrow; suspended; cancelled; wait hotspot; selfie/location/hotspot; early-login nudge; post-accept; check-in; in-progress; logout; lunch/request/cooldown; post-checkout; pre-arrival; error.

## Earnings, payout, bonuses, and referrals

| Screen | Route | Purpose | Screenshot | Components | Status / fixture | Known inconsistency |
| --- | --- | --- | --- | --- | --- | --- |
| Payout home | `/payout-home` | Earnings/payout overview | Capture required | Payout, navigation cards | Legacy Flutter | Heavy custom elevation and component duplication |
| Net earnings | `/net-earnings` | Show earnings total/breakdown | Capture required | Amount, payout rows | Legacy Flutter | High app-bar elevation and typography drift |
| Performance | `/performance` | Show shift performance | Capture required | Metrics, progress, list | Legacy Flutter | Status colors and comparison semantics audit |
| Overtime details | `/overtime-details` | Explain overtime earnings | Capture required | Amount, rows, status | Legacy Flutter | High elevation and raw style risk |
| Deduction details | `/deduction-details` | Explain deductions | Capture required | Amount, rows, warning/status | Legacy Flutter | Negative meaning must not rely on red alone |
| Incentive details | `/incentive-details` | Explain incentives | Capture required | Amount, rows, progress | Legacy Flutter | High elevation and raw style risk |
| Bonus home | `/bonus-home` | Bonus overview | Capture required | Amount/cards, navigation | Legacy Flutter | High elevation and multiple campaign treatments |
| Festive bonus | `/festive-bonus` | Show festive bonus program | Capture required | Campaign/status, progress, CTA | Legacy Flutter | Campaign styling is domain-only, not reusable token source |
| Daily earnings list | `/daily-earnings-list` | List earnings by day | Capture required | Date selector, amount rows | Legacy Flutter | High elevation and loading/empty coverage |
| Daily earnings state | `/daily-earnings-state` | Show one day's earnings state | Capture required | Status, amount, job rows | Current Flutter | Route requires typed arguments; deep-link/error handling |
| Tips info | `/tips-info` | Explain tips | Capture required | Amount/info cards | Legacy Flutter | High elevation and long-copy audit |
| Transaction history | `/transaction-history` | List payout transactions | Capture required | List rows, status/amount | Legacy Flutter | Add empty/loading/error and pagination states |
| Early payouts | `/early-payouts` | Explain/use early payout | Capture required | Requirements, account state, CTA | Current Flutter | Mixed raw styles; disabled eligibility reason critical |
| Referral home | `/referral-home` | Referral program overview | Capture required | Campaign cards, stats, CTA | Legacy Flutter | Campaign colors/shadows are not system tokens |
| Wallet | `/wallet-home` | Referral earnings wallet | Capture required | Amount, transaction rows | Legacy Flutter | Align money/status semantics with payout surfaces |
| Referral contacts | `/referral-contacts` | Select/invite contacts | Capture required | Search/list/selection, CTA | Legacy Flutter | Permission, privacy, empty contacts, long names |
| Diwali contest | `/diwali-contest-page` | Time-bound referral contest | Capture required | Campaign/status/rank cards | Legacy Flutter | Seasonal styles are not reusable design-system rules |

## Profile, support, leave, disputes, and hosted surfaces

| Screen | Route | Purpose | Screenshot | Components | Status / fixture | Known inconsistency |
| --- | --- | --- | --- | --- | --- | --- |
| Insurance support | `/insurance-support` | Show insurance benefits/claim support | Capture required | Status/cards, CTA | Legacy Flutter | Tier/domain card styles and claim recovery audit |
| Long leave | `/long-leave` | View/apply for extended leave | Capture required | Status/list, form/sheets | Legacy Flutter | High elevation; multiple status subviews need consistent semantics |
| Issue history | `/issue-history` | List support disputes/issues | Capture required | Status cards/list, CTA | Legacy Flutter | Custom colors/elevation; empty and filter states |
| New issue reporter | `/new-issue-reporter` | Raise a support dispute | Capture required | Form/selection/sheets, CTA | Legacy Flutter | Custom sheet/button patterns should converge |
| Chat | `/chat` | Communicate with support/customer channel | Capture required | Message list, composer, status | Current Flutter | Loading/offline/send-failure/privacy states |
| BCP degraded | `/bcp_degraded` | Show degraded-service continuity state | Covered by widget test; capture required | Full-screen status, recovery | Current Flutter | Clarify retry/exit and persisted availability |
| App web view | `/app-web-view` | Host approved embedded experience | Capture required per hosted flow | Webview shell, loading/error, navigation | Hosted | Hosted content must follow native shell/voice and origin safety |
| KMP Profile | KMP Profile tab | Show profile and account destinations | Capture required | `SnabbitScreen`, list/navigation cards | KMP current | Record host route and parity with legacy drawer |

## Screenshot registry

Approved screenshot evidence currently committed:

- `shared/src/androidUnitTest/snapshots/awol_home_card_breach.png`
- `shared/src/androidUnitTest/snapshots/awol_home_card_red_card.png`
- `shared/src/androidUnitTest/snapshots/awol_home_section_breach.png`
- `shared/src/androidUnitTest/snapshots/awol_overlay_breach.png`
- `shared/src/androidUnitTest/snapshots/awol_overlay_movement_required.png`

The repository also contains screenshot-test sources for KMP Home and Check-in. If a test references a golden that is not committed, the inventory remains “capture required.”

## Priority audit queue

1. Capture baseline screenshots for the frontend preview, login/OTP, Partner Home fixture states, Go Live V2, payout home, and KMP Home/Job.
2. Mark which duplicate legacy routes are canonical: availability, registration code, insurance, location, shift timing, and overlapping review/status screens.
3. Replace per-feature raw color/type/elevation decisions with package or documented semantic tokens.
4. Expand frontend preview navigation and fixtures beyond the three current entry screens.
5. Add route/host identifiers and state-specific goldens for all KMP screens.

