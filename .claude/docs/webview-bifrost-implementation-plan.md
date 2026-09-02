# WebView Bifrost — Implementation Plan

**Status:** Draft for review · **Author:** Mehar + Claude · **Last updated:** 2026-04-20
**Companion to:** [webview-bifrost-proposal.md](webview-bifrost-proposal.md)

---

## 0. Context

This plan implements the design in the proposal doc. It does not restate decisions; it sequences them into commits, PRs, and test gates. Read the proposal first.

### 0.1 Decisions locked in

- **Access token TTL:** weeks (backend-confirmed). Refresh flow is Phase 2. Phase 1 ships minimal `tokenExpired` (close-on-expiry only).
- **Analytics:** bifrost-forwarded to native via `trackEvent` → MixPanel. No web-side SDK.
- **Fixture distribution:** symlink from `app-webview/test/fixtures/` → this repo's `test/fixtures/bifrost_contract/`.
- **Shorebird runbook:** owned by Mehar. Drafted during Phase 1a.
- **Back-button watchdog:** 1500ms from Phase 1a. Metric `back_watchdog_fired` measured in beta; tuning is data-driven.
- **Request IDs:** `crypto.randomUUID()` from Phase 0.

### 0.2 Decisions still open

- **Observability routing table** (§2.10 of proposal). MixPanel + Coralogix confirmed; Crashlytics likely dropped. Final table must land **before Phase 1a slice for `observabilityEvent` merges.** Does not block Phase 0.

### 0.3 Scope

- **In scope:** everything in Phases 0, 1a, 1b of the proposal. Phase 2 is documented but not scheduled here.
- **Out of scope for this plan:** backend changes to tokens or the refresh endpoint, CleverTap/MixPanel SDK upgrades, Shorebird pipeline changes.

---

## 1. Strategy

### 1.1 Vertical slicing, parallel repos, contract-first

Already justified in chat; summary:

- Every slice lands on **both** repos (where applicable) plus the shared fixture.
- The fixture is written first. It is the contract.
- Dart and TS each test against the same fixture. Contract drift becomes a test failure, not a production bug.
- No slice merges until all three test signals (Dart unit + TS unit + integration sanity) are green.

### 1.2 Slice rhythm

Every slice follows this loop:

1. **Fixture.** Add/update JSON files under `test/fixtures/bifrost_contract/<action>/`.
2. **Dart test (red).** Unit + contract test for the handler or router change. Watch them fail.
3. **Dart impl (green).** Minimum code to pass.
4. **TS test (red).** Contract test in `app-webview` repo against the same fixture.
5. **TS impl (green).** Update the web bifrost or add the action wrapper.
6. **Integration check.** Run the bifrost harness on a real emulator; exercise the new action end-to-end. (For refactor-only slices, skip and rely on existing Seva/Merch smoke.)
7. **Commit in each repo.** Cross-reference PR links in both descriptions.

Steps 2–3 and 4–5 can overlap if you trust yourself to hold the contract; in practice, do them serially for the first few slices until the rhythm is automatic.

### 1.3 Repo-level branch plan

- Flutter repo: one long-lived feature branch `feature/webview-bifrost-v2`, slices land as squash-merged PRs.
- Web repo (`app-webview`): matching `feature/bifrost-v2` branch.
- Master/main always ships to prod; all Phase 0/1 behaviour stays behind the `webviewBifrostV2` remote-config flag until rollout is approved.

### 1.4 Test layers — what runs when

| Layer | Tool | Runs on | Speed |
|---|---|---|---|
| Dart unit | `flutter test` | Every PR in Flutter repo | Seconds |
| Dart contract (fixture-driven) | `flutter test` (same target) | Every PR in Flutter repo | Seconds |
| TS unit/contract | `vitest` (or existing runner in `app-webview`) | Every PR in web repo | Seconds |
| Widget | `flutter test` with WidgetTester | Every PR in Flutter repo | ~30s |
| Integration (real InAppWebView + harness HTML) | `flutter drive` against emulator | Nightly + on bifrost-touching PRs | ~5 min |

---

## 2. Phase 0 — Foundations (~1 week)

Goal: refactor the current bifrost into the target shape **without changing the contract visible to existing consumers** (Seva, Merch). Everything ships behind invisible refactor; end-of-phase deliverable is the fixed `initData` race.

### Slice 0.1 — `WebViewChannel` abstraction

**Scope:** introduce the seam between `AppWebViewPage` and `InAppWebViewController`.

**Flutter changes:**
- `lib/services/webview/webview_channel.dart` (new) — abstract class per §4.2 of proposal.
- `lib/services/webview/inapp_webview_channel.dart` (new) — real adapter wrapping controller.
- `lib/pages/app_web_view_page.dart` — hold a `WebViewChannel` instead of raw controller. Optional constructor param `WebViewChannel Function()? channelFactory` for tests.
- `test/unit/webview/inapp_webview_channel_test.dart` (new) — thin tests over the adapter.
- `test/unit/webview/fake_webview_channel.dart` (new) — test double used by later slices.

**Web changes:** none.

**Fixtures:** none.

**Exit criteria:**
- Seva + Merch + existing flows smoke-tested manually on iOS + Android.
- Existing widget tests pass unchanged.
- `FakeWebViewChannel` is used by at least one new widget test to prove it works.

**Estimate:** 1 day.
**Risk:** pure refactor; main risk is forgetting to delegate a controller call. Mitigate: grep `_controller.` usage before and after.

---

### Slice 0.2 — Envelope + router + origin gate, port existing handlers

**Scope:** introduce the typed envelope, the router, and the origin gate. Move the four existing handlers (`openUrl`, `callPhone`, `closeWebView`, `requestInitData`) behind them. No contract change visible to web.

**Flutter changes:**
- `lib/services/webview/bifrost_envelope.dart` (new) — `BifrostEnvelope` + `BifrostError` + `tryParse`.
- `lib/services/webview/bifrost_error_codes.dart` (new) — string constants.
- `lib/services/webview/origin_gate.dart` (new) — exact-origin allowlist.
- `lib/services/webview/bifrost_router.dart` (new) — router skeleton per §4.3.
- `lib/services/webview/bifrost_handlers/` (new dir) — one file per existing action. Port logic from `webview_event_handler.dart`.
- `lib/services/webview_event_handler.dart` — retained for now as facade calling router; delete in slice 1b.
- `test/unit/webview/bifrost_envelope_test.dart` — full parser coverage per §5.3.
- `test/unit/webview/origin_gate_test.dart` — including the `a.coins.snabbit.com.attacker.com` case.
- `test/unit/webview/bifrost_router_test.dart` — all branches.
- `test/unit/webview/bifrost_handlers/*_test.dart` — one per ported handler.

**Web changes:** none yet.

**Fixtures:** create structure + fixtures for the four existing actions. They describe the _current_ contract, which slice 0.3 will extend.

**Exit criteria:**
- Origin gate active: messages from non-allowlisted origins silently dropped with log. Verified by a unit test using a hostile URL.
- All four existing actions route through new handlers. Seva + Merch manual smoke green.
- `bifrost_parse_failed` and `bifrost_origin_blocked` logs appear in Coralogix for deliberately malformed test inputs.
- Branch coverage ≥99% on `bifrost_envelope`, `origin_gate`, `bifrost_router`.

**Estimate:** 2 days.
**Risks:**
- Origin gate over-blocks and breaks Seva/Merch → mitigate with an explicit integration test against the real Seva URL in staging before merging.
- Parser leniency mismatch (current handler accepts some malformed input we reject) → grep existing usage and add fixtures for every format currently in production.

---

### Slice 0.3 — RPC response, unified web receiver, `crypto.randomUUID()`, top-level `error` field — **fixes the `initData` race**

**Scope:** this is the single biggest correctness fix. End of this slice, `requestInitData()` resolves in <100ms instead of hanging 10s.

**Flutter changes:**
- `bifrost_router.dart` — if inbound has `requestId`, handler's result is sent back as a response via `channel.sendResponse`.
- `inapp_webview_channel.dart` — `sendResponse` implementation. JSON-encodes `{event, data, requestId, error?}` and executes via `callAsyncJavaScript` calling `window.onFlutterMessage`.
- `bifrost_handlers/request_init_data_handler.dart` — convert from push-on-callback to returning a `BifrostResult` that router echoes with `requestId`.
- **Retain** the legacy `initData` push on `onPageCommitVisible` for one more release (dual-mode) so old web clients still work. Delete in slice 1b.
- New test: `request_init_data_handler_test.dart` with both a requestId-bearing request (expects RPC response) and no-requestId (backwards-compat push path).

**Web changes (`app-webview`):**
- `bifrost/bifrost.ts`:
  - Replace `setupGlobalReceiver` to install a single `window.onFlutterMessage`; keep `onFlutterEvent` as a thin alias that rewrites to the new shape (back-compat for one release).
  - Accept top-level `error` field; if present, `request()` promise rejects with `BifrostError`.
  - Change `generateId()` to `crypto.randomUUID()`.
- `bifrost/types.ts` — add `error?: BifrostError` to `BifrostMessage`. Add `BifrostError` type.
- `bifrost/actions.ts` — `requestInitData` catches the new error shape, surfaces typed `InitError`.
- New TS tests: contract test that loads `initData/request.valid.json`, posts it through a spy channel, asserts received bytes match; contract test for error response.

**Fixtures:**
- `test/fixtures/bifrost_contract/initData/request.valid.json` — with requestId.
- `test/fixtures/bifrost_contract/initData/response.success.json` — full init data shape including capabilities array.
- `test/fixtures/bifrost_contract/initData/response.token_unavailable.json` — error response.

**Integration:**
- Open the bifrost harness (slice 0.3 also needs the harness scaffolded — see Appendix A). Verify `requestInitData` promise resolves on real emulator.
- Time-to-resolve metric: log `bifrost_handler_done` with `durationMs`; confirm p95 < 200ms locally.

**Exit criteria:**
- Phase 0 kill: `requestInitData().then(...)` receives data in <1s with zero hangs over 100 opens. (Today: 10s hang every time.)
- Both `window.onFlutterMessage` and legacy `window.onFlutterEvent` work.
- Contract fixtures load identically in Dart and TS tests.
- Seva + Merch regressions: none (those apps don't call `requestInitData`, they ignore the response; verify via staging build).

**Estimate:** 3 days.
**Risks:**
- `callAsyncJavaScript` with `window.onFlutterMessage` fails on an old InAppWebView version → verify on the minimum-supported OS we ship (Android 8, iOS 14) before merging.
- Old web client still deployed receives new envelope with `error` field → it'll just ignore the unknown field; forward-compat by design. Smoke on Seva to confirm.

---

### Phase 0 exit review

Before moving to Phase 1a:
- [ ] `initData` race gone.
- [ ] All four existing actions working via router.
- [ ] Origin gate in place.
- [ ] Fixture infrastructure live, first three actions covered.
- [ ] `webviewBifrostV2` remote-config flag wired but default-on (it gates Phase 1a additions, not Phase 0 refactors).

---

## 3. Phase 1a — Rate Card 2.0 Blockers (~2 weeks)

Goal: ship everything Rate Card 2.0 needs to launch. Each slice is one new action.

### Slice 1a.1 — `navigate` action (~3 days)

**Scope:** the big one. Web can open native screens via `snabbit://` URIs.

**Flutter changes:**
- `lib/services/webview/route_registry.dart` (new) — URI pattern → Flutter route + typed args parser/validator.
- `lib/services/webview/bifrost_handlers/navigate_handler.dart` (new).
- `lib/services/webview/app_navigator.dart` (new, small) — wraps `GlobalKey<NavigatorState>` with `pushNamed` / `pushReplacementNamed`. Testable.
- `test/unit/webview/route_registry_test.dart`.
- `test/unit/webview/bifrost_handlers/navigate_handler_test.dart` — happy path, `UNKNOWN_ROUTE`, `INVALID_ARGS`, `DEBOUNCED`, `closeBehavior=replace`.

**Web changes:**
- `bifrost/actions.ts` — `navigate(route, data, closeBehavior?): Promise<void>`.
- `bifrost/types.ts` — `OutgoingEventMap.navigate`.
- Contract test.

**Fixtures:** `navigate/request.valid.json`, `request.invalid_route.json`, `request.replace.json`, `response.success.json`, `response.unknown_route.json`, `response.debounced.json`.

**Exit criteria:**
- From harness, navigating to `snabbit://add-bank-upi` opens the real screen with typed args.
- Rapid double-tap produces exactly one navigation + one `DEBOUNCED` response.
- Unknown route returns `UNKNOWN_ROUTE` without exception.

**Risk:** `Navigator.pushNamed` from bifrost handler may race with ongoing transitions. Mitigate with the proposal's 300ms debounce; document that sequencing beyond debounce belongs to web.

---

### Slice 1a.2 — Capability negotiation on `initData` (~1 day)

**Scope:** web's `initData` request payload now includes `capabilities: string[]`. Response echoes intersection.

**Flutter changes:**
- `bifrost_handlers/request_init_data_handler.dart` — accept `data.capabilities`, compute intersection with native's supported set, return in response.
- `lib/services/webview/native_capabilities.dart` (new) — single source of truth for what this Flutter build supports.
- Tests.

**Web changes:**
- `bifrost/actions.ts` — `requestInitData` takes an optional `capabilities` param.
- `bifrost/capabilities.ts` (new) — list of what this web build wants.
- `InitData` type gains `capabilities: string[]`.

**Fixtures:** update `initData/request.valid.json`, `response.success.json` to include capabilities.

**Exit criteria:**
- A Phase 2 capability advertised only on native side but absent from web's request → not in intersection. Verified via contract test.
- Code consuming `init.capabilities.includes('X')` compiles and works.

---

### Slice 1a.3 — `trackEvent` action (~1 day)

**Scope:** web → MixPanel via bifrost.

**Flutter changes:**
- `bifrost_handlers/track_event_handler.dart` — validates payload, calls existing MixPanel Dart plugin.
- `lib/services/webview/analytics_sink.dart` (new, thin interface) — so tests don't hit MixPanel SDK directly.
- Tests with `FakeAnalyticsSink`.

**Web changes:**
- `bifrost/actions.ts` — `trackEvent(name: string, properties: Record<string, unknown>)`. FAF.

**Fixtures:** `trackEvent/request.valid.json`, `request.missing_name.json`.

**Exit criteria:**
- Sample event from harness reaches MixPanel dashboard.
- FAF enforcement: if web sends with a `requestId`, router returns `PATTERN_MISMATCH`.

---

### Slice 1a.4 — `tokenExpired` minimal (~1 day)

**Scope:** web on 401 calls `tokenExpired` → native responds `{closing: true}` → webview pops.

**Flutter changes:**
- `bifrost_handlers/token_expired_handler.dart` — responds with `{closing: true}`, triggers `AppWebViewPage` pop via an injected `CloseIntent` callback.
- Tests.

**Web changes:**
- `bifrost/actions.ts` — `tokenExpired(): Promise<{closing: boolean}>`. RPC.

**Fixtures:** `tokenExpired/request.valid.json`, `response.closing.json`.

**Exit criteria:**
- Simulated 401 on harness → webview pops within 500ms.
- Phase 2 full refresh flow reserves same action name; no rename needed later.

---

### Slice 1a.5 — `observabilityEvent` (blocked on routing decision)

**Status:** cannot merge until §2.10 routing table is finalized.

**Scope:** web → native → [Coralogix + MixPanel per finalized routing].

Work we can start before the decision:
- Fixture structure.
- Dart: batcher + rate-limiter logic. These are orthogonal to the routing destination.
- Web-side: batcher that flushes every 2s or on `fatal` severity.

Work we must pause until the decision:
- Dart handler's emit call (which SDK(s) get which severity).
- Redaction rule set (somewhat SDK-dependent).

**Estimate:** 2 days once routing is decided.

---

### Slice 1a.6 — Back-button watchdog (~0.5 day)

Lightweight slice — add the 1500ms watchdog in `AppWebViewPage` `PopScope` handler. Log `back_watchdog_fired`. No contract change; web's `closeWebView` already handles the normal path.

Integration test: mount page with a `FakeWebViewChannel` that never responds to `backPressed` → watchdog fires → page pops.

---

### Slice 1a.7 — Shorebird release runbook (~0.5 day)

Not code. Draft `docs/webview-bifrost-release-runbook.md` with the four-section template from earlier. Land as its own PR. No staging needed.

---

### Phase 1a exit review

Rate Card 2.0 launch blockers all green. Specifically:
- [ ] `navigate` works for every Rate Card URI in the registry.
- [ ] Analytics events from web land in MixPanel.
- [ ] `tokenExpired` cleanly dismisses.
- [ ] `observabilityEvent` merged (routing resolved).
- [ ] Watchdog live.
- [ ] Runbook reviewed.
- [ ] Remote config `webviewBifrostV2` flipped on for beta cluster; 24h of telemetry with zero new error classes in Coralogix.

---

## 4. Phase 1b — Legacy Cleanup (~3 days)

Once web telemetry confirms zero reliance on legacy `initData` push + `window.onFlutterEvent`:

- Delete legacy push from `onPageCommitVisible`.
- Delete `onFlutterEvent` compatibility shim in web.
- Delete `webview_event_handler.dart` facade (router is now primary).
- Remove legacy fixture variants.
- Telemetry gate: Coralogix confirms `onFlutterEvent` invocation count has been 0 for 7 consecutive days.

---

## 5. Phase 2 — Later

Documented in proposal §6.2. Scheduled in a separate plan once Phase 1 ships. Known items:
- Token refresh flow (backend may not need it given weeks-long TTL, but add for defense in depth).
- `trackUserProperties`, `dataSync` / `dataUpdated`, `permissionRequest`, `tokenRefreshed`, `memoryWarning`.

---

## 6. Testing

### 6.1 CI gates per repo

- **Flutter repo:** unit + contract + widget on every PR. Branch-coverage gate 100% on: `bifrost_envelope`, `origin_gate`, `bifrost_router`, each handler.
- **Web repo:** unit + contract on every PR. TypeScript strict mode.
- **Integration:** nightly GitHub Action running harness against an emulator image. Also triggered on PRs that touch `lib/services/webview/**` or `app-webview/bifrost/**`.

### 6.2 Harness

See Appendix A.

### 6.3 Manual smoke checklist per slice

- Runner app cold-start → open Seva → close: no regression.
- Runner app cold-start → open Merch → buy → close: no regression.
- (Phase 1a+) open Rate Card → navigate to each registered native screen → return: all paths work.

---

## 7. Release & Rollout

### 7.1 Remote config flags

- `webviewBifrostV2` (bool, default false) — gates all Phase 1a handler additions. Off = handlers return `{error: {code: "DISABLED"}}`. Legacy bifrost unaffected.
- Per-capability flags for Phase 2 (`capability.dataSync`, etc.) added as they ship.

### 7.2 Rollout ladder

1. Internal/dogfood cluster: flip `webviewBifrostV2` on for one day. Watch Coralogix for new error classes.
2. Beta cluster (5% of production runners): flip on for 3 days.
3. Staged rollout: 25% → 50% → 100% over 5 days, holding at each stage for one business day to inspect metrics.

### 7.3 Rollback

Flip `webviewBifrostV2` off. Web bifrost falls back to "action unsupported" path; for Rate Card specifically, there's a separate `rateCardUrl` kill switch that falls back to the native rate card screen. Two independent levers.

---

## 8. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| Backend's refresh endpoint not ready for Phase 2 | Low (Phase 2 delayed, not Phase 1) | Medium | Confirm before Phase 2 starts; Phase 1 doesn't depend on it. |
| InAppWebView `callAsyncJavaScript` behaves differently on minimum-supported OS | Slice 0.3 broken on old devices | Low | Manual test on Android 8 + iOS 14 before merging 0.3. |
| Fixture symlink breaks on a developer's machine | One dev blocked | Medium | Fallback `cp` script in CI; README note. |
| Observability routing delay blocks Phase 1a | Rate Card 2.0 ships without web-forwarded errors | Medium | Work 1a.5 non-emit parts in parallel; decision deadline = end of week 2. |
| Capability list drifts between repos | Compat bugs | Low | Capabilities live in a single registry file; fixture tests assert. |
| Rate Card product team adds a route we don't have in registry | Launch-day bug | Low | Lock route registry one week before launch; product sign-off on URI list. |

---

## 9. Ownership & Estimates

Single-person implementation (Mehar). Claude pairs.

| Phase | Estimate | Calendar |
|---|---|---|
| Phase 0 | 6 days | Week 1 |
| Phase 1a (excluding 1a.5 observability) | 6 days | Week 2–3 |
| Phase 1a.5 observability | 2 days (post-decision) | Week 3 |
| Phase 1b | 3 days | Week 4 |
| **Rate Card 2.0 launch-ready** | | **End of week 3** |
| Phase 2 | ~3 weeks | TBD |

Estimates assume no major blocker. Buffer = 1 week before Rate Card 2.0 target launch.

---

## Appendix A — Bifrost Harness

Scaffolded during slice 0.3. Purpose: exercise the bifrost end-to-end without pulling in the full React app.

**Location:** `test_resources/bifrost_harness/index.html`.

**Content:** single HTML page that imports the compiled web bifrost (symlinked from `app-webview/dist/bifrost.js`) and exposes a global `runScenario(name)` function. Scenarios are defined in `test_resources/bifrost_harness/scenarios.ts` and include:
- `initData` — call `requestInitData`, log result.
- `navigate` — call `navigate('snabbit://add-bank-upi', {source: 'harness'})`.
- `closeWebView` — call after 2s.
- `hostile_origin` — load from a non-allowlisted origin and attempt `callPhone`; expected: silent drop.

**Driver:** `integration_test/bifrost_harness_test.dart` opens the harness URL in a real `AppWebViewPage`, invokes scenarios via `controller.evaluateJavascript`, asserts expected log lines + response values.

Runs on every bifrost-touching PR + nightly.

---

## Appendix B — File Additions Summary

### Flutter repo

```
lib/services/webview/
├── webview_channel.dart                  (0.1)
├── inapp_webview_channel.dart            (0.1)
├── bifrost_envelope.dart                  (0.2)
├── bifrost_error_codes.dart               (0.2)
├── origin_gate.dart                      (0.2)
├── bifrost_router.dart                    (0.2)
├── route_registry.dart                   (1a.1)
├── app_navigator.dart                    (1a.1)
├── analytics_sink.dart                   (1a.3)
├── native_capabilities.dart              (1a.2)
└── bifrost_handlers/
    ├── open_url_handler.dart             (0.2, ported)
    ├── call_phone_handler.dart           (0.2, ported)
    ├── close_webview_handler.dart        (0.2, ported)
    ├── request_init_data_handler.dart    (0.2, ported; 0.3 RPC; 1a.2 capabilities)
    ├── navigate_handler.dart             (1a.1)
    ├── track_event_handler.dart          (1a.3)
    ├── token_expired_handler.dart        (1a.4)
    └── observability_event_handler.dart  (1a.5, blocked)

test/fixtures/bifrost_contract/            (0.2 onwards, per action)
test/unit/webview/                        (test files mirror lib structure)
test_resources/bifrost_harness/            (0.3)
integration_test/bifrost_harness_test.dart (0.3)

docs/webview-bifrost-release-runbook.md    (1a.7)

Deletions in 1b:
lib/services/webview_event_handler.dart   (absorbed into handlers/)
```

### Web repo (`app-webview`)

```
bifrost/
├── bifrost.ts                     (0.3 unify receiver, error support, UUIDs)
├── types.ts                      (0.3 error field, capabilities)
├── actions.ts                    (1a.* per action)
├── capabilities.ts               (1a.2, new)
└── error_codes.ts                (0.3, new)

test/fixtures/                    → symlink to Flutter repo
test/contract/                    (0.3 onwards)
```
