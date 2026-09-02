# WebView Bifrost — Architectural Proposal

**Status:** Draft for review · **Author:** Mehar + Claude · **Last updated:** 2026-04-17
**Version:** 3 (supersedes v1 and v2 drafts)

---

## How to read this document

This is a design doc, not a spec. The goal is to argue every significant decision from first principles so anyone on the team can defend, critique, or extend it later without re-deriving the reasoning.

The structure:

- **Part 1 — Foundational Principles.** Eight principles that act as the lenses through which every later decision is made. Read these first; everything in Part 2 refers back to them.
- **Part 2 — Design Decisions (the deep one).** Thirteen decisions, each treated as a small essay: the problem, the alternatives, the trade-offs, what other mature systems do, our choice, and the failure modes we accept. This is the bulk of the doc. Read end-to-end the first time; use as reference after.
- **Part 3 — The Contract.** The exact wire format, action registry, error codes. The output of Part 2. Short.
- **Part 4 — Architecture.** How the code is organized, what the abstractions are. Short.
- **Part 5 — TDD Plan.** What we test, at which layer, with what fixtures. Medium.
- **Part 6 — Migration & Rollout.** How we get from today's bifrost to this one without breaking production. Short.
- **Part 7 — Open Questions.** Things we don't have answers for yet.
- **Appendices.** Glossary, references, rejected options log.

If you have 30 minutes: read Part 1 and skim Part 2 headings. If you have an afternoon: read the whole thing.

---

## Table of Contents

- [Part 1 — Foundational Principles](#part-1--foundational-principles)
  - [1.1 The bifrost is a product, not an implementation detail](#11-the-bifrost-is-a-product-not-an-implementation-detail)
  - [1.2 Symmetry reduces cognitive load](#12-symmetry-reduces-cognitive-load)
  - [1.3 Pull is safer than push](#13-pull-is-safer-than-push)
  - [1.4 Errors are first-class citizens](#14-errors-are-first-class-citizens)
  - [1.5 Capabilities scale; version numbers don't](#15-capabilities-scale-version-numbers-dont)
  - [1.6 Treat every inbound message as adversarial](#16-treat-every-inbound-message-as-adversarial)
  - [1.7 You cannot improve what you cannot measure](#17-you-cannot-improve-what-you-cannot-measure)
  - [1.8 Test the contract, not the implementation](#18-test-the-contract-not-the-implementation)
- [Part 2 — Design Decisions](#part-2--design-decisions)
  - [2.1 Wire protocol: envelope shape](#21-wire-protocol-envelope-shape)
  - [2.2 Communication patterns: fire-and-forget vs. RPC vs. push](#22-communication-patterns-fire-and-forget-vs-rpc-vs-push)
  - [2.3 Request/response correlation (RPC mechanics)](#23-requestresponse-correlation-rpc-mechanics)
  - [2.4 Bootstrap / init: pull, not push](#24-bootstrap--init-pull-not-push)
  - [2.5 Authentication & token lifecycle](#25-authentication--token-lifecycle)
  - [2.6 Origin security model](#26-origin-security-model)
  - [2.7 Navigation: deeplink URIs and close semantics](#27-navigation-deeplink-uris-and-close-semantics)
  - [2.8 Versioning via capability negotiation](#28-versioning-via-capability-negotiation)
  - [2.9 Error handling: structured, coded, stable](#29-error-handling-structured-coded-stable)
  - [2.10 Observability: native-authoritative, web-forwarded](#210-observability-native-authoritative-web-forwarded)
  - [2.11 Lifecycle & teardown](#211-lifecycle--teardown)
  - [2.12 Back button & navigation ownership](#212-back-button--navigation-ownership)
  - [2.13 Serialization format: JSON, not protobuf](#213-serialization-format-json-not-protobuf)
- [Part 3 — The Contract](#part-3--the-contract)
- [Part 4 — Architecture](#part-4--architecture)
- [Part 5 — TDD Plan](#part-5--tdd-plan)
- [Part 6 — Migration & Rollout](#part-6--migration--rollout)
- [Part 7 — Open Questions](#part-7--open-questions)
- [Appendices](#appendices)

---

# Part 1 — Foundational Principles

These are not rules; they are values. When two design options both "work", these tell us which to pick.

## 1.1 The bifrost is a product, not an implementation detail

The bifrost is a long-lived interface between two teams that will evolve independently. Every action, every field, every error code is part of a contract that some other engineer — probably someone not in this conversation — will read, extend, and depend on for years.

Consequences:
- Actions should be named like public API methods, not like internal function calls. `navigate`, not `doNavigation`. `trackEvent`, not `handleAnalytics`.
- Breaking changes are expensive. Prefer additive evolution.
- The contract deserves its own documentation, its own tests, its own review process. It is not an artifact of whoever last touched the code.
- Field names, once shipped, are effectively immutable. Name them as if a hostile reader will mock you in three years.

## 1.2 Symmetry reduces cognitive load

When the same concept appears in two places (e.g., a message shape going native→web and web→native), it should have the same name, the same structure, and the same semantics.

Today's web bifrost has an asymmetry: outbound messages are `{event, data}` but inbound are `{type, payload}`. This asymmetry exists for historical reasons, not design reasons. Every new engineer on either side trips on it.

Consequences:
- Unify shapes across directions.
- Use the same word for the same concept everywhere. Pick one of `event` / `type` and stick with it.
- When native talks to web, responses should look structurally identical to messages web sent. Flipping direction should not flip mental model.

This principle is cheap to honor at design time and expensive to retrofit. Pay now.

## 1.3 Pull is safer than push

A sender that doesn't know whether the receiver is ready will either push too early (data lost) or push repeatedly (wasted or duplicated). A receiver that knows when it's ready and asks for what it needs is always right.

Today's `initData` push is a textbook example of the former: Flutter pushes on `onPageCommitVisible` hoping React has already installed `window.onFlutterEvent`. It often has; sometimes it hasn't. The system has a second mechanism (`requestInitData`) to handle the race. Two mechanisms is one too many.

Consequences:
- Bootstrap is a pull: web requests, native responds. One code path.
- Lifecycle signals that are time-sensitive (e.g., back press, memory warning) remain pushes — there's no sensible "ready to receive back press" handshake. Accept the asymmetry where it's fundamental.
- Pushed events should be idempotent or obviously loss-tolerant. If "did the receiver handle this?" matters, it should be a request, not a push.

## 1.4 Errors are first-class citizens

In protocols designed by accident, success is encoded in a payload's shape and failure is squeezed into whatever leftover field was lying around: a null `data`, a magic `-1`, a `"status": "error"` string. This conflates "what happened" with "what came back", makes parsers complex, and makes partial success impossible to express.

Good protocols separate the two. Success data lives in one field; error information lives in another. Both can be present (warnings with partial results); either can be absent.

Consequences:
- Envelope has a top-level `error` field, distinct from `data`.
- Errors have machine-readable codes (for routing retry / display) separate from human-readable messages (for logs).
- A handler returning an error is not an exceptional path; it is a documented outcome. Contracts enumerate error codes per action.

## 1.5 Capabilities scale; version numbers don't

Monotonic version numbers (`v1`, `v2`) force lockstep releases and coarse-grained compatibility. Every feature addition becomes a version bump, or worse, an unadvertised behavior change.

Capability declaration — each side enumerating what it supports — allows:
- Forward compat: newer web can detect that native doesn't yet support `observability` and disable its reporter.
- Backward compat: older web keeps working because capabilities it doesn't know about are simply not used.
- Graceful degradation paths encoded in product logic, not in bifrost branches.

Consequences:
- Drop any `v` field from the envelope.
- Capabilities travel with `initData` (web declares what it can do; native responds with the intersection).
- Runtime feature detection is a supported idiom: `if (capabilities.includes('X'))`.

## 1.6 Treat every inbound message as adversarial

The webview may be redirected — intentionally or not — to a third-party origin. That origin can call any globally-exposed function including `window.flutter_inappwebview.callHandler`. A bifrost that doesn't gate inbound messages by origin has a cross-origin exploit surface for whatever native actions it exposes (`callPhone`, `openUrl`, `navigate`, etc.).

Consequences:
- Every inbound message is validated against an allowlisted origin before any handler runs.
- Validation failures are silent drops, not error responses. Error responses leak information about which actions exist.
- The default posture is fail-closed: if origin cannot be determined, block.
- Scheme allowlists (`openUrl`), phone number sanitization (`callPhone`), route allowlists (`navigate`) are defense-in-depth. Origin is the first gate.

## 1.7 You cannot improve what you cannot measure

The bifrost is invisible by default. JS errors sink into the webview's console and nobody sees them. Native handlers that throw are swallowed or log a single line. Promises that never resolve just... stay unresolved.

A bifrost with no self-telemetry will accrete silent failures for months. By the time you notice, you can't correlate; you can only rewrite.

Consequences:
- Every bifrost decision point emits a structured log: inbound parse outcome, origin check, handler dispatch, response sent, timeout fired.
- Web-side errors (JS exceptions, unhandled rejections) ride the bifrost to native observability. One dashboard, one retention policy.
- Rate limits and sampling are first-class so the observability channel itself doesn't become a noise source.

## 1.8 Test the contract, not the implementation

Bridges fail because the two sides drift apart. Unit tests that exercise only one side's implementation won't catch "Dart now sends `userId` but TS still reads `user_id`".

The cure is shared fixtures: canonical request/response JSON files checked into both repos (or one, symlinked). Dart tests load the fixture, run the handler, assert output matches the corresponding response fixture. TS tests load the same fixture, run the web handler, assert parse succeeds and behavior matches.

Consequences:
- Contract-level fixtures are the source of truth. Implementations conform; tests enforce.
- TDD isn't optional — it's the mechanism by which fixtures and implementations stay in sync.
- Coverage percentages are secondary. Branch coverage on security-critical paths (envelope parser, origin gate, router) is 100%, no exceptions.

---

# Part 2 — Design Decisions

Each subsection follows the same shape:

1. **The problem.** What we're actually deciding.
2. **Alternatives.** The options on the table.
3. **Trade-offs.** The honest pros and cons of each.
4. **Prior art.** What mature systems do.
5. **Decision.** Our choice, with reasoning.
6. **Failure modes.** What goes wrong, and how we know.

## 2.1 Wire protocol: envelope shape

### Problem

Every message — in either direction — needs a structural shape. That shape is the single most consequential decision in the design, because it's the hardest to change later. The choice determines how messages are parsed, how errors are expressed, how RPC is correlated, and how future fields (telemetry, versioning, tracing IDs) can be added without breaking clients.

### Alternatives

**A. Flat with a discriminator tag.**
```json
{ "type": "navigate", "route": "snabbit://foo", "closeBehavior": "push" }
```
Every field sits at the top level. The `type` field discriminates for routing.

**B. Wrapped with a payload.**
```json
{ "event": "navigate", "data": { "route": "snabbit://foo", "closeBehavior": "push" } }
```
Metadata (event, requestId) is separated from payload. This is the web side's current outbound shape.

**C. Positional array (the old React Native bifrost).**
```json
[7, 3, [{"route": "snabbit://foo"}], 42]
```
Where each index has a meaning: moduleId, methodId, args, callbackId.

**D. JSON-RPC 2.0 standard.**
```json
{ "jsonrpc": "2.0", "method": "navigate", "params": { ... }, "id": "..." }
```
A published standard with ecosystem tooling.

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: Flat | Compact on wire. TypeScript discriminated unions feel natural. | Parser must know every type's full shape up front. Adding metadata (requestId, error) pollutes the payload namespace. |
| B: Wrapped | Clean separation of metadata and payload. Parser can extract metadata generically, defer payload parsing to handler. Forward-compatible: new metadata fields go alongside, not inside. | Slightly more verbose. Two levels of nesting for deep payloads. |
| C: Positional | Very compact. Fast to serialize. | Unreadable in logs. Every index is a magic number. Hostile to debugging. React Native moved away from it for a reason. |
| D: JSON-RPC 2.0 | Standard. Tooling exists. Clear semantics. | Overkill; we're not a general-purpose RPC server. The `jsonrpc` preamble is dead weight. `method` vs `event` naming is different from what we already have. Ecosystem tooling is for the network case, not intra-process. |

### Prior art

- **React Native (old bifrost)** used a positional array `[moduleId, methodId, args, callbackId]`, serialized to JSON. It was fast to produce but painful to read and debug. The new architecture (JSI / Fabric / TurboModules) is synchronous and no longer uses bifrost messages; the lesson from the old system is: optimize for readability first, micro-serialization later.
- **Capacitor** uses a wrapped shape: `{pluginId, methodName, callbackId, options}`. Metadata wraps payload, exactly our approach B.
- **VS Code webviews** use `{type, ...body}` (flat with discriminator), relying on TypeScript discriminated unions and strict message-type contracts on both ends. It works because both ends are TypeScript. Our Dart side loses the type-level discrimination benefit.
- **Chrome Extensions' `chrome.runtime.sendMessage`** is wrapped: `{action, payload}` is the de facto convention.
- **JSON-RPC 2.0** is the reference for RPC semantics; adopting its *semantics* (id correlation, structured errors) while not adopting its exact *shape* is reasonable.

### Decision

**Wrapped envelope, symmetric in both directions:**

```json
{
  "event": "navigate",
  "data": { ... },
  "requestId": "optional-string",
  "error": { "code": "...", "message": "...", "details": {} }
}
```

- `event` is always the action name (both directions — no `event`/`type` asymmetry).
- `data` is the action's payload. Always an object (even empty `{}`); never omitted; never primitive.
- `requestId` is present when this message participates in RPC (either as the request or as its response). Absent for fire-and-forget and pushes.
- `error` is present only on failed responses. When present, `data` may still carry partial results (see §2.9).

Reasoning:

1. **`event`/`data` over `type`/`payload`** because the web side already uses `event`/`data` outbound. Changing the inbound receiver's shape to match is a small patch; renaming the well-known outbound field is a larger migration.
2. **Symmetric both directions** because §1.2 (symmetry). Web's current `__bridge_receive__` uses `{type, payload}` — that gets patched to `{event, data}` in the same PR that lands capability negotiation, which is already a coordinated change.
3. **Wrapped, not flat**, because handler metadata (`requestId`, `error`) must not collide with action payloads. A `navigate` action has its own notion of what fields exist; it should not have to avoid reserved names.
4. **No `timestamp`** because native can record receive-time locally and web can record send-time locally. An on-wire timestamp introduces a clock-skew ambiguity without adding information. If we ever need distributed tracing, a `traceId` is a better fit than a `timestamp`.
5. **No `v` / `version`** because capability negotiation (§2.8) is strictly more expressive and we want one mechanism, not two.

### Failure modes

- **Malformed JSON** → parser returns null; router logs `parse_failed`; no response is possible because we don't know the `requestId`. Web's promise times out.
- **Extra unknown top-level fields** → ignored. Forward compatible with future additions on the sending side.
- **Missing `event`** → treated as malformed. Silent drop with log.
- **Missing `data`** → substitute `{}`. Lenient because senders may genuinely have no payload.
- **Both `data` and `error` present** → valid (partial success). Handler-specific interpretation.

---

## 2.2 Communication patterns: fire-and-forget vs. RPC vs. push

### Problem

Not every action needs a response. `trackEvent` doesn't care whether CleverTap acknowledged. `navigate`, by contrast, very much does — the caller needs to know if the route was valid. Treating all actions the same way either wastes bandwidth on useless acks or forces callers to invent side-channels when they do need a reply.

A bifrost needs to support the three patterns that cover essentially all webview traffic:

1. **Fire-and-forget command** — "do X, I don't care about the result."
2. **Request/response (RPC)** — "do X and tell me what happened."
3. **Push event** — receiver-initiated notification from the other side; no reply expected.

### Alternatives

**A. One pattern for everything.** Force all actions to be RPC (or all to be fire-and-forget). Simplest model.
**B. Pattern per direction.** Web→native is RPC; native→web is push. Matches the common case but falls apart when native wants to ask web something.
**C. Pattern per action, declared in the contract.** Each action's spec says whether it's FAF, RPC, or push. Bifrost enforces.

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: Uniform | Simple mental model. Single code path. | Wastes traffic on acks nobody reads. Or makes useful responses impossible. |
| B: By direction | Clear rules. | Inflexible. `navigate` becomes RPC but `trackEvent` does too. Native-→-web "are you ready?" is impossible. |
| C: Per action | Each action is designed for its need. Bifrost can enforce the rules. | Engineers must declare the pattern; miss one = bug. |

### Prior art

- **JSON-RPC 2.0** has explicit notifications (no `id`) vs. requests (has `id`). Pattern selected by the sender per message, not fixed per method. Our model is similar but stricter: pattern is fixed per action.
- **gRPC** has unary / server-streaming / client-streaming / bidi, one per RPC. Different stubs for each; can't accidentally call a unary method as streaming. This rigidity is the right default.
- **Electron IPC** has `ipcMain.on` (fire-and-forget) vs. `ipcMain.handle` (RPC). Registration itself picks the pattern. Sending side chooses between `ipcRenderer.send` and `ipcRenderer.invoke` — you cannot misuse.
- **React Native's old bifrost** had both callbacks and events, but with no enforcement; it was easy to register a callback and never call it.

### Decision

**Pattern per action, declared in the contract (Option C).** The framework enforces:

- If an action is declared **FAF**, the bifrost rejects any inbound message for it that includes a `requestId` (and logs). The sender is misusing the contract.
- If an action is declared **RPC**, the bifrost rejects messages without a `requestId` (and logs). Caller can't ignore the response they requested.
- **Push** is always native→web; web doesn't send pushes to Flutter. (Web→native fire-and-forget is the symmetric concept and handles the other direction.)

The declaration lives in one place: the action registry (Part 3). Both Dart handlers and TS senders consult the same registry; shared JSON fixtures enforce it in tests.

Reasoning:
- **Per-action declaration** because each action has a natural fit. Forcing all to one pattern (Option A) either adds noise (acks for FAF) or removes signal (no ack for RPC).
- **Enforcement at the framework level** because discipline by convention is discipline by hope. If a bug in TS forgets to pass a `requestId`, the Dart handler should refuse to execute rather than silently run and leave the web promise hanging forever.
- **The enforcement is symmetric**: Dart refuses invalid inbound; TS's bifrost code refuses to `send()` a message for an action declared RPC (or to `request()` one declared FAF). Catches misuse at both ends.

### Failure modes

- **Contract drift** (FAF on one side, RPC on the other): contract fixture tests catch this in CI. See §5.
- **Handler declared RPC but code forgets to return**: bifrost wrapper always sends a default `{data: {}}` if handler returns void. Add a lint: RPC handlers must have an explicit return.
- **Web sends RPC message to an action the server has demoted to FAF**: server responds with `{error: {code: "PATTERN_MISMATCH"}}`. Web resolves promise with error. No crash.

---

## 2.3 Request/response correlation (RPC mechanics)

### Problem

When a caller sends a request, it needs to know which inbound message is the reply. Over a single-threaded message channel with multiple outstanding calls, correlation is essential.

### Alternatives

**A. Sender-generated opaque ID echoed by receiver.** Caller puts `requestId: "xyz"` on the request; callee puts `requestId: "xyz"` on the response. Most common pattern.
**B. Monotonic sequence number.** Caller counts 1, 2, 3, ...; responses come in order.
**C. Dedicated reply channel per call.** Open a new channel for each request, close on reply. Rich but heavy.
**D. Callback function passed in the call.** Impossible across serialization; ruled out for any JSON transport.

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: Opaque ID | Order-independent. Simple. Debuggable in logs. Works with concurrent outstanding calls. | Requires ID generation. Collision must be avoided. |
| B: Sequence number | Slightly smaller. Can detect missed responses. | Order-dependent: one lost response breaks alignment for all subsequent calls. Retries complicated. |
| C: Dedicated channel | Strongest isolation per call. Stream responses possible. | Overkill for our use case. Channel setup overhead per RPC. |
| D: Closure | Ergonomic in-process. | Doesn't survive JSON serialization. Inapplicable. |

### Prior art

- **HTTP/2** uses stream IDs — equivalent to opaque IDs (odd for client-initiated, even for server-initiated).
- **JSON-RPC 2.0** uses `id` — sender-chosen, echoed by receiver. Null means notification.
- **GraphQL subscriptions over WebSocket** use `id` — same pattern.
- **Electron IPC** uses an internal sequence under the hood but exposes promises to the developer.
- **Our web bifrost today** uses opaque IDs: `${Date.now()}-${Math.random().toString(36).slice(2, 9)}` ([bifrost.ts:271-273](../../../app-webview/bifrost/bifrost.ts)).

All winners. Opaque ID is the universal choice for good reasons.

### Decision

**Opaque sender-generated IDs.** Format: `<timestamp-ms>-<6-char-random-base36>`, matching the web bifrost's existing scheme.

Per-request timeout policy:

- **Default: 10 seconds.** Long enough for a network request + UI animation; short enough that a silent failure is noticed quickly.
- **Override per action.** Actions that involve user interaction (permission dialog, re-auth) override to 60s. Actions that are synchronous in native (track event, log observability) override to 2s.
- **No retry at the bifrost layer.** Retries belong to the caller. The bifrost is a transport, not a reliability layer.

On timeout:
- Web rejects the promise with `{code: "BIFROST_TIMEOUT", message: "..."}`.
- The pending entry is removed from the correlation map. If the native response arrives later, it's matched against an empty map and logged as `late_response`.
- Native side has no notion of timeout for its own outbound awaits unless it explicitly races.

Uniqueness guard:
- Native keeps a bounded sliding window (60s) of seen `requestId`s. Duplicates are dropped with a log. Defends against accidental or malicious replay.

### Failure modes

- **Caller's promise leaks** (web forgets to handle): the promise stays pending until timeout, then garbage-collected. Tolerable.
- **Receiver sends two responses**: the second matches no pending entry and is logged as `late_response`. The first wins.
- **ID collision within 60s window**: astronomically unlikely with our format (~40 bits of randomness). If it happens, the second request gets the first's response — wrong data. Mitigation: use `crypto.randomUUID()` instead of timestamp+random. The fix is local; revisit if collisions appear in telemetry.
- **Handler crashes mid-work**: no response sent, caller's promise times out. Native-side crash log correlates via `requestId`.

---

## 2.4 Bootstrap / init: pull, not push

### Problem

Before web can do anything meaningful, it needs auth context (access token), device context (platform, version), and user context (runner profile). Who initiates the transfer, and when?

### Alternatives

**A. Native pushes on page-ready.** When the page commits visible, native calls `window.onFlutterEvent({event: "initData", data: ...})`. Web must have subscribed before the call.
**B. Web pulls on bifrost-ready.** Web calls `bifrost.request('initData', {})` when its Bifrost instance is constructed. Native responds.
**C. Both, for robustness.** Push on page-ready AND respond to pulls. Whichever arrives first wins.

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: Push | Web doesn't need to ask. Data arrives as early as possible. | Race: web may not be subscribed yet. Today this manifests as a 25-second promise hang on every webview open (web calls `requestInitData`, native ignores the `requestId`, native pushes without `requestId`, web's request promise never resolves until timeout, and the `onInitData` subscriber fires separately). |
| B: Pull | Web controls timing. One code path. No race. Symmetric (bootstrap is just another RPC). | Web is blocked until response (~50ms on a real device; immaterial). |
| C: Both | Maximum robustness. | Two code paths on both sides. Web has to deduplicate (or choose which source wins). The code that handles this is subtle and has been wrong in practice. |

### Prior art

- **Electron's contextBridge / preload script** exposes APIs synchronously but runtime data is always pulled. There is no push equivalent; the renderer calls when it's ready.
- **iframe `postMessage`** patterns converge on "child posts `{ready: true}`, parent sends init on receipt." Pull-triggered.
- **Web Workers:** `new Worker()` → main thread sends initial message only when worker fires `onmessage`-ready event, explicit or implicit.
- **React Native bifrost:** both models exist. Module initialization is push (native pushes constants at startup). Later module calls are pull. The push-at-startup was a known pain point — constants couldn't be async, which became problematic and was fixed in the new architecture.

The pattern across mature systems: **use push only when the sender can guarantee receiver readiness**. Across an async boundary like webview load, no such guarantee exists. Pull wins.

### Decision

**Option B: Pull-based init.** Native never pushes `initData`. Web calls `bifrost.request('initData', {capabilities: [...]})` when its Bifrost instance is constructed (which is at module import time, i.e., as early as possible). Native responds.

Migration note: the current Flutter code pushes on `pageCommitVisible`. Phase 0 of the migration (§6) keeps the push alongside the new pull, then drops the push once web has migrated to `requestInitData()` exclusively. This is a short-lived dual-mode, not a permanent hybrid.

Reasoning:
- Kills the race described above.
- Aligns with §1.3 (pull is safer than push).
- One code path on both sides.
- `initData` becomes structurally indistinguishable from any other RPC action — symmetric (§1.2).

The one thing we *must* retain as a push is `initError` — the case where native wants to signal that init is impossible even before web asks (e.g., token unavailable at webview mount time). This is rare but real; the push shape is `{event: "initError", data: {reason: ...}}` with no `requestId`. Web subscribes.

### Failure modes

- **Web never calls `requestInitData`**: nothing happens. The page loads, the bifrost is silent. This is the same failure as the current code having `onInitData` never fire. Caught by widget tests.
- **Native can't produce init data** (e.g., token fetch fails): respond with `{error: {code: "TOKEN_UNAVAILABLE"}}`. Web shows error UX.
- **Web calls `requestInitData` twice**: both resolve independently with current state. Idempotent.

---

## 2.5 Authentication & token lifecycle

### Problem

The React app needs authenticated access to backend APIs. Where do credentials live? How do they get into the webview? What happens when they expire?

### Alternatives

**A. Bearer token via bifrost, in-memory JS.** Dart reads access token from secure storage, sends in `initData` response, React uses it as `Authorization: Bearer <token>` header.
**B. HttpOnly cookie via `CookieManager`.** Dart sets cookie before loadUrl; browser sends it on every same-origin request; React never sees the token.
**C. Hybrid: cookie for API auth + `initData` push for non-secret context.**

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: Bearer + JS memory | Already working in production (Seva, Merch). No backend changes. React code identical to the browser-only version. Token cleared on webview teardown. Simple to test — inspect what went through the bifrost. | Token lives in JS heap. An XSS on the React app leaks the token. Mitigated by our control of the origin + CSP, but the residual risk exists. |
| B: HttpOnly cookie | JS cannot read it; XSS can't exfiltrate. Automatic on every request. | Requires backend to accept cookie auth: SameSite, CSRF protection, CORS with credentials. Android `CookieManager` is a process-wide singleton — cross-webview cookie pollution is a known issue ([flutter_inappwebview #2009](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2009)). React must use `credentials: 'include'` everywhere. Cookie domain must match API domain (subdomain alignment pressure). |
| C: Hybrid | Best security (HttpOnly for secret) + convenience (initData for context). | All the costs of B plus dual auth pathways. Worth it only if the threat model demands it. |

### Prior art

- **SPAs using OAuth 2.0 PKCE** traditionally put access tokens in memory (JS) and refresh tokens in httpOnly cookies. Access token exposure is accepted as the SPA trade-off.
- **Mobile apps with OIDC** put both in Keychain/Keystore. Our split (access→JS, refresh→Dart) is intermediate: best-of-both for the mobile-webview hybrid.
- **Capacitor apps** typically use bearer tokens stored in `SecureStorage` and passed to the webview via a similar `initData`-like mechanism. Same pattern.
- **Electron apps** generally use IPC to fetch tokens on demand (pull-based) rather than pre-populating them, reducing the exposure window.

### Decision

**HttpOnly cookie via `CookieManager` (Option B). Dart sets `access_token` as an `HttpOnly; Secure; SameSite=LAX` cookie on the webview's origin before the first URL load; the browser attaches it on every request automatically; React never sees the raw token.**

**Rationale for reversing from the earlier bearer-first decision:**

- **Security.** HttpOnly closes the XSS exfiltration path entirely. The token exists only in `SecureStorage` (Dart) and the browser's cookie jar (inaccessible to JS). An XSS on the React app can misuse the session in-browser, but can't steal a token that would outlive the session or be replayed on a different device.
- **Correctness.** Browser attaches the cookie on *every* request to the origin — fetch, XHR, WebSocket, page subresources — so auth coverage doesn't depend on every developer remembering to route through an `api.ts` helper. Bearer-header injection breaks silently when a code path bypasses the helper; cookie auth doesn't.
- **Refresh simplicity.** When Dart rotates the token, it calls `CookieManager.setCookie(...)` with the new value and web is unaware. No `snabbit:tokenRefreshed` push, no web-side store update, no in-flight-request coordination.
- **First-request auth.** Cookie is set before the webview mounts (behind a `_cookieReady` gate in `AppWebViewPage` with a 5s timeout fallback), so the initial HTML + any auto-fired API calls ship with auth on the first attempt — no 401-retry dance.

**Prerequisites:**

- **Backend accepts cookie auth.** The target API must read `Cookie: access_token=<jwt>` as a valid credential. BFF team is aligned; Merch backend migration is tracked separately (Phase B).
- **Same-origin API calls.** The cookie is bound to the webview's initial-URL origin; the browser won't send it to different origins unless CORS credentials are explicitly configured. Web code must therefore call APIs relatively (e.g. `/bff/...`) routed through a same-origin proxy, not to absolute cross-origin URLs.

### Transitional state (current)

At the time of this decision, the implementation is split:

- **Flutter side** (ECPO-135 + this change): cookie prep wired in `AppWebViewPage._prepareAuthCookie`. `isHttpOnly: true`. Works for any webview whose API calls are same-origin.
- **Web side**: `src/services/api.ts` still attaches `Authorization: Bearer <token>` header from `initData.token`. Redundant for same-origin callers (BFF accepts both), load-bearing for **Merch**, which calls an absolute cross-origin URL (`VITE_MERCH_API_URL`) where cookies aren't sent without CORS credentials.

The bearer path stays until **Phase B** lands. In the transitional state, same-origin requests (Payouts) carry both cookie and bearer; cross-origin requests (Merch) carry only bearer. BFF accepts either.

### Phase B — full convergence

When Merch's backend is reachable via a same-origin proxy (or accepts CORS with credentials), bearer is removed everywhere:

1. Remove `Authorization: Bearer` block from `src/services/api.ts`.
2. Remove `token` field from `InitData` type and from the `requestInitData` RPC response.
3. Replace `useAuthToken` sentinel usage in `PrivateRoutes` with `!!initData` (or a dedicated `isInitialised` selector).
4. Delete the `useAuthToken` selector itself.

Unblocking Phase B requires a backend/infra change on the Merch side: either reverse-proxy Merch under the web-host origin (like Payouts' `/bff`), or enable `Access-Control-Allow-Credentials: true` with a strict origin allowlist. The former is operationally simpler; the latter is more common for SaaS APIs.

### Additional hardening rules

All enforced by code review and tests:

1. **Refresh tokens never leave Dart.** Only the access token is materialised as a cookie. Refresh logic runs in Dart, updates the cookie in place, web never sees either form.
2. **Cookie is cleared on webview teardown.** `AppWebViewPage.dispose()` calls `deleteCookie` for the auth cookie; subsequent sessions re-mint from a fresh `SecureStorage` read.
3. **Cookie value is not written to logs or telemetry.** The envelope logger (§2.10) has an allowlist of serializable fields; `token`, `password`, `Cookie`, etc. are masked.
4. **Scheme-conditional `isSecure`.** `isSecure: uri.scheme == 'https'` so local dev (HTTP) works; production (HTTPS) gets the secure flag automatically.
5. **SameSite=LAX.** Sufficient for our same-origin fetch pattern; blocks third-party cross-site requests from carrying the cookie (CSRF protection).
6. **Short-lived access tokens.** Target ≤15min TTL. Limits replay-attack windows if a cookie does leak (e.g. via device compromise).
7. **Token refresh flow (Phase 2 of Bifrost — separate from Phase B of this auth migration):**
   - Web detects 401 response.
   - Web calls `bifrost.request('tokenExpired', {})`.
   - Dart checks local token expiry. If still valid: ignore (handles clock-skew false positives). If expired: call backend refresh endpoint.
   - Response: `{closing: false, refreshed: true}` — Dart has already updated the cookie; web retries original request.
   - Fallback: `{closing: true}` — refresh failed, Dart will pop the webview.
   - Guard: after 2 consecutive `refresh_failed`, stop retrying. Prevents loops.
8. **Phase 1 minimal (current):** web on 401 calls `tokenExpired()`; Dart responds `{closing: true}` and pops after a 100ms delay (time for the RPC response to reach web). Refresh flow is Phase 2.

### Action item

**Confirm access token TTL with backend.** If ≥1 hour, Phase 1's close-on-expiry is acceptable for day-one. If ≤15 min, we need Phase 2's refresh flow on launch.

### Failure modes

- **Cookie prep fails or times out (5s):** `_cookieReady` stays false past the timeout; the InAppWebView mounts anyway via the `whenComplete` fallback (avoiding a hung-spinner UX). First API call 401s; `tokenExpired` closes the webview; runner retries.
- **Token null in SecureStorage at webview open:** `_prepareAuthCookie` logs `webview_set_auth_cookie_token_null` and skips the cookie set. Webview still mounts; first API call 401s; runner sees close-and-retry.
- **Cookie refresh while a request is in flight:** the in-flight request already had the old cookie in its headers. Backend 401s; web retries with new cookie. Acceptable ≥99% of the time.
- **XSS on React:** attacker can make authenticated API calls while the user is active, but can't exfiltrate the token for later use. Blast radius = one active session. Significantly tighter than bearer-in-JS.
- **Cross-origin API call (Merch during transition):** cookie doesn't attach; bearer header from `api.ts` kicks in. After Phase B lands, any cross-origin call would fail auth outright — intentional, flags the architectural break at runtime.

---

## 2.6 Origin security model

### Problem

The webview loads from `coins.snabbit.com` at open. During the session it may navigate — to an OAuth provider, a support page, an attacker-controlled redirect — and the current page can call any injected globals including `window.flutter_inappwebview.callHandler`. Without a gate, any loaded origin can trigger `callPhone`, `openUrl`, `navigate`, `trackEvent`, etc.

This is exploit surface. Mobile web views have had documented CVEs from exactly this class.

### Alternatives

**A. Trust everything loaded in the webview.** Implicit. Today's state.
**B. URL allowlist at navigation time** (reject loading certain URLs). Prevents 3p from ever loading.
**C. Origin gate on every inbound message** (reject messages from non-allowlisted origin). Allows 3p to load but prevents it from calling bifrost.
**D. Per-action origin rules** (e.g., `trackEvent` accepted from any origin, `callPhone` only from our origin).

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: Trust all | Zero code. | Full exploit surface. |
| B: URL allowlist | Hardest gate; 3p can't even show UI. | Breaks OAuth and other legitimate redirects. Too strict. |
| C: Origin gate | Blocks bifrost abuse while allowing 3p UI. Matches React Native's `originWhitelist`. | Requires every handler to know its origin check passed (or trust the router). |
| D: Per-action rules | Fine-grained; lets us expose safe actions to 3p. | Complex. Most actions should be gated; this would be a small set of exceptions. YAGNI unless we have a real use case. |

### Prior art

- **React Native WebView** has an `originWhitelist` prop.
- **VS Code webviews** have strict CSP + explicit allowed origins via `webviewOptions`.
- **Cordova/Capacitor** use a `server.allowNavigation` list.
- **Electron** has `contextBridge` that only injects APIs into the main renderer — 3p origins loaded via `<webview>` tags don't get the APIs at all.

The universal pattern: **isolate or gate bifrost access by origin**. We don't have isolation primitives (InAppWebView injects globally), so we gate.

### Decision

**Option C: origin gate on every inbound message.**

- Allowlist has two layers:
  1. **Primary**: the initial URL's origin, captured at webview open. Immutable for the session.
  2. **Secondary (optional, per-launch)**: explicit additional origins for cases like OAuth return. Empty by default.
- Gate runs before any handler dispatch. Failures are silent drops (no response, to avoid leaking which actions exist). Every drop is logged.
- Fail-closed: if `controller.getUrl()` returns null (navigation in progress), block until a URL is known.
- Gate does not depend on request origin header or any value from the message. Only on the *currently-loaded* URL from the native side. The message sender has no way to forge it.

For Phase 1 (Rate Card 2.0), the secondary allowlist is empty — we don't plan to redirect outside our origin. If a future journey needs OAuth, add with design review.

### Failure modes

- **Origin check itself fails** (e.g., `getUrl()` throws): fail-closed. Block, log.
- **Race between navigation and message**: URL may update between message receipt and handler execution. Check origin at receipt time; cache for the handler. Don't re-check mid-handler.
- **Subdomain confusion**: exact-origin match, not suffix match. `coins.snabbit.com` ≠ `attacker.coins.snabbit.com.evil.co`. Standard URL parsing handles this; add test for hostile input.
- **DNS rebinding**: not applicable to same-session webview.

---

## 2.7 Navigation: deeplink URIs and close semantics

### Problem

React needs to open native Flutter screens. Two sub-problems:

1. How does React identify a native screen? (the "what" of navigation)
2. How does the webview integrate with the Flutter navigation stack? (the "how" of transitions)

### Alternatives for identifier

**A. Named Flutter routes** (`/payout-home`, `/add-bank-upi`). Flutter's own route names.
**B. Deeplink URIs** (`snabbit://payout-home`). Scheme we already own for external links and push notifications.
**C. Integer codes or opaque tokens.** Server-controlled IDs.

### Trade-offs (identifier)

| Approach | Pros | Cons |
|---|---|---|
| A: Flutter routes | Direct mapping to existing code. Minimal translation. | Coupled to Flutter internals. Not reusable for push / external. Routes change means breaking API. |
| B: Deeplink URIs | Decoupled from implementation. Reusable across push notifications, external links, in-app deeplinks. Flutter can refactor routes internally without breaking web contract. | One layer of indirection (URI → Flutter route), which is a registry we maintain. |
| C: Integer codes | Compact. Server-controllable. | Opaque in logs. Hostile to debugging. Requires a registry to read anything. |

### Alternatives for close behavior

**A. Bundled flag** (`closeBehavior: "push" | "replace"` on the `navigate` action).
**B. Separate close action** (web sends `navigate`, then sends `closeWebView` if needed).
**C. Enum with richer options** (`push` / `replace` / `closeAfter` / `popToRoot` / `replaceAll`).

### Trade-offs (close)

| Approach | Pros | Cons |
|---|---|---|
| A: Bundled | Atomic — one intent, one message. Web never has to sequence two messages. Native can pick the animation. | Requires pre-enumerating the needed behaviors. |
| B: Separate | Flexible — web composes primitives. | Two messages = opportunity for bugs (one fails, other succeeds). Animation worse: pop-then-push versus atomic replace. |
| C: Rich enum | Covers every future case. | YAGNI. Hard to test. Not supported by all navigation stacks. |

### Prior art

- **Apple Universal Links / Android App Links** use URIs. Our push-notification stack already does this.
- **Flutter `go_router`** routes are URI-like; our registry can integrate cleanly.
- **React Navigation deep linking** uses URIs.
- **iOS `UINavigationController`** has `pushViewController:animated:` and `setViewControllers:animated:` — both primitives exist; the "replace" concept is native. Our `closeBehavior: "replace"` maps directly.

### Decision

**Deeplink URIs for identifiers. Bundled `closeBehavior` with just `push` (default) and `replace` for Phase 1.**

URI structure:
- `snabbit://<host>[/<path>][?<query>]`
- `host` is the logical screen name: `add-bank-upi`, `payout-home`, `issue-history`.
- `path` for sub-navigation: `add-bank-upi/verify` (if we need it later; not in Phase 1).
- `query` for typed arguments: `?source=payout_page&returnEvent=BANK_ADDED`.

Registry (`route_registry.dart`):
- Single source of truth. Each route: (URI pattern, Flutter route name, args parser, args validator).
- The args parser returns a typed args object or null on invalid. The bifrost validates BEFORE navigating. Prevents partial navigations.
- The registry is iterated in `initData` response so web can feature-detect known routes.

`closeBehavior`:
- `"push"` (default): `Navigator.pushNamed(target)`. Webview stays in the stack. User returning from target lands back in webview.
- `"replace"`: `Navigator.pushReplacementNamed(target)`. Webview is replaced by target. Smoothest animation. Used for one-way flows ("exit to old rate card" on Red Coins screen).

Why just two: YAGNI. Adding `popToRoot` later is an additive enum value; current callers default to `"push"` and stay correct. We don't pay for flexibility we don't need.

### Failure modes

- **Unknown route host**: `{error: {code: "UNKNOWN_ROUTE", details: {route: "snabbit://foo"}}}`. Web can show fallback UX or log.
- **Invalid args**: `{error: {code: "INVALID_ARGS", details: {...}}}`.
- **Race: two rapid `navigate` requests within 300ms**: debounce — second is ignored with a response `{ok: false, error: {code: "DEBOUNCED"}}`. Prevents double-tap producing double-push.
- **Navigation from web when native is already mid-transition**: Navigator queues or drops per Flutter's semantics; we don't add our own queueing.

---

## 2.8 Versioning via capability negotiation

### Problem

Over time, new actions are added, old ones deprecated, payload shapes evolve. Both sides (Dart, TS) ship on independent release trains (the whole point of this project is that TS can ship without App Store review). How do they coordinate compatibility?

### Alternatives

**A. Monotonic version field.** `v: 1`, `v: 2`. Either matches or it doesn't.
**B. Semantic versioning.** `"2.3.1"` with compatibility rules.
**C. Capability declaration.** Each side announces what actions/features it supports. Intersection is the shared vocabulary.
**D. Feature flags outside the bifrost.** Use existing remote config; ignore versioning at bifrost level.

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: Monotonic `v` | Simple check. Widely understood. | Every feature addition becomes a version bump (or a silent behavior change). Coarse-grained. Forces lockstep deploy for any divergence. |
| B: SemVer | Well-understood rules for compat. | Overkill for a contract with ~15 actions. Most bridges do not version payload shapes. |
| C: Capabilities | Forward- and backward-compat without lockstep. Enables runtime feature detection in product code. | Requires discipline: every new feature is a new capability string, enumerated in docs and tested. |
| D: External flags | Reuses existing infra. | Conflates bifrost compat with product feature rollout. Can't feature-detect at the bifrost layer. |

### Prior art

- **HTTP `Accept` / `Accept-Encoding`** headers are content negotiation via capabilities. Canonical.
- **WebRTC SDP** lists codecs; peers intersect.
- **Bluetooth GATT** characteristic discovery = capabilities.
- **gRPC reflection** is runtime service discovery — same idea at RPC granularity.
- **The web platform itself**: `if (window.IntersectionObserver)` is the idiom. Feature detection, not UA-string versioning.

Where monotonic version numbers appear, it's typically because the protocol is frozen and old versions cannot be retrofitted — e.g., `TLS 1.2` vs `TLS 1.3`. That's not our situation; both sides are in our control.

### Decision

**Capability negotiation. No `v` field.**

Mechanism:
- Web's `requestInitData` payload: `{capabilities: ["navigate", "trackEvent", "observability"]}`. These are things web is prepared to use.
- Native's response `data.capabilities` = intersection with native's supported set.
- Product code on both sides can feature-detect: `if (init.capabilities.includes('observability')) enableReporter();`.

Adding a new action (process):
1. Pick a capability name, lowercase kebab-case: `data-sync`.
2. Ship support on either side first. The other side doesn't see it in its intersection yet; no breakage.
3. Ship the other side. Capability appears in intersection; product code enables behavior.
4. Document in the action registry (Part 3).

Removing (deprecation) process:
1. Remove capability from advertised set on whichever side wants to drop it.
2. Other side stops using it (feature-detect returns false).
3. Remove handler once telemetry confirms zero usage.

### Failure modes

- **Web uses an action without feature-detecting**: bifrost responds `UNKNOWN_ACTION`. Web logs, user sees error. Caught by code review + contract tests.
- **Capabilities list grows unbounded**: retire old capabilities as features are removed. Telemetry (§2.10) reports usage.
- **Typo in capability name**: caught by the registry being a single source of truth imported on both sides.

---

## 2.9 Error handling: structured, coded, stable

### Problem

When a handler fails — bad payload, unknown route, downstream API error, permission denied — the caller needs enough structure to decide what to do: retry, show a specific message to the user, fall back, report it. Protocols that encode errors as bare strings or as magic nullable fields punish their callers.

### Alternatives

**A. String error in the payload.** `{data: {error: "not found"}}`. Today's informal approach.
**B. HTTP-style integer codes.** `{error: 404, message: "not found"}`. Numbers as tags.
**C. Structured error object with string code, message, details.** `{error: {code: "NOT_FOUND", message: "...", details: {...}}}`.
**D. Exceptions that propagate.** Only works in-process; ruled out for JSON.

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: String | Simplest. | Not machine-readable. Localization impossible at caller. Changing the string (typo fix) is a breaking change. |
| B: Integer codes | Compact. HTTP-like. | Requires a number registry; numbers are forgettable in logs. No namespace. Runs out of well-known numbers quickly. |
| C: String code + message | Self-documenting in logs. Machine-routable. Localization at caller. Extensible with `details`. | Slightly more bytes. Requires discipline to keep codes stable. |
| D: Exceptions | Idiomatic. | Doesn't cross JSON. |

### Prior art

- **gRPC status**: `{code: int, message: string, details: []}`. Canonical. We use strings over ints because of §1.1 (debuggability in logs).
- **JSON-RPC 2.0**: `{code: int, message: string, data: any}`. Numeric codes. Still well-known for this reason.
- **HTTP problem+json (RFC 7807)**: `{type, title, status, detail, instance}`. Richer, overkill for us.
- **AWS SDK errors**: `{Code: "InvalidParameter", Message: "...", ...}`. String code + message + extra fields. Most similar to our pick.

### Decision

**Option C, top-level (not nested in `data`).**

Envelope:
```json
{
  "event": "navigate",
  "data": { "partialResult": ... },
  "error": {
    "code": "UNKNOWN_ROUTE",
    "message": "No route registered for snabbit://foo",
    "details": { "attemptedRoute": "snabbit://foo" },
    "retryable": false
  },
  "requestId": "..."
}
```

Fields:
- **`code`** (required): stable `SCREAMING_SNAKE_CASE` identifier. Never changes once shipped. Web maps to localized strings.
- **`message`** (required): developer-facing English, for logs. May change freely.
- **`details`** (optional): structured, for debugging and richer UI (e.g., "which field was invalid").
- **`retryable`** (optional, default false): hint for caller. `TIMEOUT` and `TRANSIENT_*` are retryable; `UNKNOWN_ACTION` and `INVALID_PAYLOAD` are not.

Why top-level and not nested:
- `data` represents successful result semantics, not failure semantics. Conflating makes parsing error-prone.
- Partial success is possible: `data` and `error` coexist (the error is a warning).
- Matches §1.4 (errors as first-class).

Code naming convention:
- Category prefix: `INVALID_` (payload/arg problems), `UNKNOWN_` (unregistered identifiers), `PERMISSION_` (user/auth refusal), `TIMEOUT` (exceeded deadline), `INTERNAL_` (unexpected handler failure).
- Noun after prefix describes what.
- Avoid non-specific codes (`ERROR`, `FAILURE`). If in doubt, create a new code.

Code registry: `bifrost_error_codes.dart` + `bifrost-error-codes.ts`, shared by fixture. Adding a code is a PR with doc + test.

### Failure modes

- **Handler throws unexpectedly**: router catches, responds with `{error: {code: "INTERNAL_ERROR", message: "<exception.toString()>", retryable: false}}`. Also logs with stack trace to native observability.
- **Code not in registry (typo)**: caught at PR time by enum check. Runtime: web's error-code handler has a default case that logs and shows a generic message.
- **Error message exposes sensitive data**: logger redaction rules apply (§2.10). `message` values are dev-facing English; do not include tokens, user data, etc.

---

## 2.10 Observability: native-authoritative, web-forwarded

> **Status: routing table DEFERRED.** The envelope, the `observabilityEvent` action, rate limiting, batching, and the "bifrost-to-native, not web-SDK" backend choice are finalized. The specific routing — which SDKs receive which severity × category — is being re-evaluated. MixPanel is in the mix alongside Coralogix; Crashlytics is likely dropped from bifrost observability to protect the crash-free-users metric. Decision must land before Phase 1a `observabilityEvent` slice ships.

### Problem

The webview is a black box unless we instrument it. JS exceptions, network failures, performance metrics, unhandled promise rejections — all are invisible to native monitoring by default. A production bifrost that doesn't bring these into the light accrues silent debt.

Two decisions interact: *where do errors land* (observability backend), and *what granularity* (message-level vs. batched).

### Alternatives (backend)

**A. Web forwards to web-side SDK.** Sentry Web, Datadog RUM, Coralogix RUM. Separate dashboard, separate budget.
**B. Web forwards to native via bifrost; native emits to existing SDKs** (Crashlytics, Coralogix).
**C. Both.** Maximum coverage, duplicated spend and noise.

### Alternatives (granularity)

**X. Per-message immediate forward.** Each event is its own bifrost call.
**Y. Batched, flushed on interval.** Collect in a buffer, flush every N seconds or N events.
**Z. Hybrid** — batched with immediate flush on `severity: fatal`.

### Trade-offs

| Backend | Pros | Cons |
|---|---|---|
| A: Web-side | Native-like UX; SDKs mature. | Adblockers common in India (our market) block web analytics. Separate dashboard = fragmented view. Incremental vendor cost. |
| B: Via bifrost to native | Single dashboard. Uses existing vendor spend. Not adblockable. Unified correlation with native events. | Bifrost traffic + our code to ferry events. |
| C: Both | Redundant. | Doubles cost; requires dedup across dashboards. |

| Granularity | Pros | Cons |
|---|---|---|
| X: Per-message | Lowest latency. Simpler. | Chatty. A JS error loop floods the bifrost. |
| Y: Batched | Backpressure-friendly. | Loses data on webview crash (flush never happens). |
| Z: Hybrid | Balanced. | Slight complexity. |

### Prior art

- **Sentry's own React Native integration** forwards JS errors via the bifrost to native to unify with native crashes. Our pick aligns.
- **Datadog's RUM** has both web and native variants; combined view requires careful correlation-ID wiring.
- **OpenTelemetry** batches spans by default (interval + size); flushes immediately for errors.

### Decision

**Backend: Option B — via bifrost to native observability.**
**Granularity: Option Z — hybrid, with severity-aware flushing.**

Bifrost action: `observabilityEvent`, fire-and-forget.

Payload:
```json
{
  "category": "jsError" | "networkFailure" | "performance" | "unhandledRejection" | "warning",
  "severity": "fatal" | "error" | "warning" | "info",
  "message": "...",
  "data": { "stackTrace": "...", "url": "...", "durationMs": ... },
  "pageUrl": "https://coins.snabbit.com/..."
}
```

Native side:
- Forward `fatal` and `error` to Crashlytics (non-fatal) + Coralogix.
- Forward `warning` to Coralogix only.
- Forward `info` (performance metrics) to Coralogix with sampling.

Rate limiting (mandatory):
- **Token bucket: 50 events/sec per session.** Excess dropped, with one aggregated "observability_flooded" log per burst.
- **Per-(category, message) dedup** within 10s window. Prevents loop-generated spam.
- **Per-session cap: 100 distinct errors.** After cap, drop + log count.
- **Performance sampling: 10%** (remote-config adjustable). Errors always pass.

Batching:
- Web-side batcher collects events; flushes every 2s or immediately on `severity: fatal`.
- On webview teardown, flush remaining batch synchronously before destroying.

Redaction:
- Native logger has an allowlist of fields: `category`, `severity`, `message`, `pageUrl`, numeric `data.*`. Raw `data.stackTrace` passes but is scanned for known-sensitive patterns (JWT shape, `token=`, phone numbers) and masked.

### Failure modes

- **Observability flood blocks real traffic**: rate limit buckets separately from other bifrost traffic. Observability overflow doesn't affect `navigate`.
- **Flush on teardown fails**: events lost. Acceptable; teardown is rare, and critical errors flushed immediately anyway.
- **Redaction misses**: follow-up engineering task. Add known patterns to the redaction scanner as they're discovered.

---

## 2.11 Lifecycle & teardown

### Problem

Webviews hold resources: JS heap, GPU surface, cookies, cache, in-flight network requests, subscriptions. When a user closes the webview, or the app is low on memory, these must be freed deterministically. Leaking across sessions risks memory pressure; leaking across users (shared device) risks data exposure.

### Concerns

1. When the webview is dismissed by user action, resources are released.
2. When the app receives a memory warning, we can shed load.
3. When the user switches accounts (logout), no stale session persists.
4. Between discrete webview openings (open A, close, open B), state doesn't bleed.

### Alternatives

**A. Implicit.** Rely on `State.dispose()` + Dart garbage collection + InAppWebView's own cleanup.
**B. Explicit destroy signal to web + explicit resource clear on native.**
**C. Keep-alive webview.** Don't destroy; reuse across opens. (Rejected for Runner app — resource constrained.)

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: Implicit | No code. | Non-deterministic. Cookies persist. Cache persists. JS listeners retained until GC. Cross-user risk on shared devices. |
| B: Explicit | Predictable. Tests straightforward. | Small amount of code on both sides. |
| C: Keep-alive | Fast re-open. | Memory-hostile. Stale state risk. Not needed for Phase 1. |

### Prior art

- **Electron `BrowserWindow.destroy()`** is explicit; `close()` is graceful.
- **VS Code webview panels** have `onDidDispose` → extension clears its state.
- **iOS `WKWebView`**: `stopLoading`, `configuration.processPool` management for memory control. Apps typically reset these on logout.

### Decision

**Option B: explicit teardown, both sides.**

Native side (`_AppWebViewPageState.dispose`):
1. Send `memoryWarning` or `closeIntent` push to web — best-effort, non-blocking.
2. Call `channel.clearSession()` which:
   - `controller.clearCache()` — clears HTTP cache for our origin.
   - `CookieManager.deleteCookies(url: ourOrigin)` — cookies for our origin only (not process-wide wipe, which would break other webviews).
   - `controller.stopLoading()` — aborts in-flight requests.
3. Null `_controller`.

Web side (`Bifrost.destroy()`):
- Existing implementation already: removes global hooks, rejects pending requests, clears listeners.
- No change needed.

Memory warning:
- iOS's `didReceiveMemoryWarning` observed via platform channel (or `MemoryPressureLevel` on newer Flutter).
- Level `warning`: emit `memoryWarning` push to web with `{level: "warning"}`. Web optionally drops caches.
- Level `critical`: emit with `{level: "critical"}` AND pop webview after 500ms. No draft-state risk in Rate Card 2.0 (read-only screens); revisit if forms are added.

Cross-open hygiene:
- Webview B's controller is a new instance. No JS state carries over because the JS context is fresh.
- Cookies for our origin were cleared in A's teardown, so B starts clean.

### Failure modes

- **Teardown runs while a request is in flight**: native's stopLoading cancels. Web's promise-rejection-on-destroy handles web side.
- **Clear cookies during OAuth return**: if OAuth flow is mid-redirect, we'd lose state. Not a Phase 1 concern (no OAuth); add explicit allowlist in clearSession for auth domains if/when needed.
- **Memory critical during critical flow**: Rate Card 2.0 has no critical flows. If one is added later, introduce a grace-period mechanism.

---

## 2.12 Back button & navigation ownership

### Problem

On Android, the system back button is a hardware/OS affordance. In iOS, swipe-from-left is the equivalent. When a webview is open, who handles back: native (pops the webview route) or web (navigates internally)?

### Alternatives

**A. Native always pops.** Back button = close webview.
**B. Web always handles.** Native forwards `backPressed`; web decides.
**C. Two-tier: native first tries `controller.canGoBack()`; if no history, forwards to web; if web has no internal stack, web signals close.**
**D. Web always handles, but with a hard timeout — if web doesn't respond in N ms, native pops.**

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: Native pops | Simple. Predictable for users. | Breaks SPAs — user loses in-page navigation. |
| B: Web handles | SPA-friendly. | If web crashes, back button is dead. |
| C: Two-tier | Handles URL-history and SPA. Comprehensive. | More code; two negotiation paths to test. |
| D: Web with timeout | SPA-friendly + fault-tolerant. | Timeout value is arbitrary. Premature close if web is slow. |

### Prior art

- **React Native's `BackHandler`** lets JS register a handler; default behavior falls through if nothing handled. Similar to our Option B but with a built-in fallback.
- **Flutter's `PopScope`** with `canPop: false` intercepts; our current code uses this to forward to web.
- **iOS**: swipe-back is not easily interceptable pre-route-transition; historically developers either disable it or live with inconsistency.
- **Android Chrome Custom Tabs**: back always closes the tab. No web handling. Users have gotten used to this.

### Decision

**Option B with a watchdog fallback (cousin of D).**

- Native's `PopScope(canPop: false)` intercepts back. Push `backPressed` event to web. Start a 1500ms watchdog.
- Web listens (`onBackPressed`). Web decides:
  - If it has internal history, navigate internally. Web does nothing further.
  - If it's at its internal root, call `closeWebView`. Native pops on receipt.
- If watchdog fires without a `closeWebView` message, native pops anyway. Log as `back_watchdog_fired`.

Why not Option C's two-tier: we don't actually use the webview's URL history in our React SPA (it's a single-page flow per webview). `controller.canGoBack()` is always false for us. Adding the tier complicates code for no benefit.

Watchdog rationale: if web crashes or the JS is stuck (e.g., blocking loop), the user must not be trapped. 1500ms is generous enough for any real navigation decision but short enough that a dead-button experience is avoided.

### Failure modes

- **Web navigates then crashes before `closeWebView`**: user presses back again → native tries to push another `backPressed` → web doesn't respond → watchdog fires → native pops. Recovers in 1.5s.
- **Watchdog fires but web eventually responds**: native has already popped; late `closeWebView` has no effect. Acceptable.
- **Web responds faster than watchdog**: watchdog cancelled. Normal path.

---

## 2.13 Serialization format: JSON, not protobuf

### Problem

Every message is bytes over a `String` channel. The format of those bytes affects size, parse cost, type safety, debuggability.

### Alternatives

**A. JSON.** Human-readable. Universal.
**B. Protobuf / FlatBuffers / Cap'n Proto.** Binary, schema-driven, compact.
**C. MessagePack / CBOR.** Binary, schemaless, compact.
**D. Custom delimited format.** Tiny.

### Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| A: JSON | Native to JS. `dart:convert` handles it. Readable in logs. No codegen. | Verbose. Parse cost on large payloads. Weak schema enforcement without external tooling. |
| B: Protobuf | Compact. Strong schema. Codegen for both sides. | Huge tooling investment. Binary in logs. flutter_inappwebview JS channels transport strings; encoding binary as base64 negates size wins. |
| C: MessagePack | Compact without codegen. | Requires libraries on both sides. Binary debugging headache. Minor size wins don't matter for <10 KB payloads. |
| D: Custom | Minimal code. | Historically a source of parse bugs. Everyone reinvents quoting. Do not do this. |

### Prior art

- **React Native** uses JSON in both old and new architectures. Performance wins in new architecture come from removing batching, not changing format.
- **Capacitor, Cordova** use JSON.
- **VS Code webviews** use JSON (auto-serialized by `postMessage`).
- **Browser APIs in general**: JSON as a first-class citizen; no mainstream webview bifrost uses protobuf.

### Decision

**Option A: JSON, full stop.**

Reasoning:
- Our payloads are <10 KB in the normal case. JSON parse time is microseconds on a modern device. Not a bottleneck.
- Readability trumps compactness for debugging a single-point-of-failure layer.
- Protobuf's real win is on server-to-server traffic where schema enforcement and compact size pay back codegen cost. Neither matches our situation.
- Schema enforcement we want (typed payloads per action) can be had via TypeScript types + Dart freezed classes + shared fixture tests. Cheaper and more iterable than .proto files.

### Failure modes

- **Large payload (e.g., base64 image)**: degrades gracefully. If we ever need to transport binary, revisit. For Phase 1, no large payloads exist.
- **Non-JSON-serializable value leaks into payload** (e.g., `undefined`, a Function): web's `JSON.stringify` silently drops it. Testing catches. Add a lint.
- **Parse cost shows up in profiling**: unlikely, but if it does, first optimization is reducing payload size (trim fields), not format change.

---

# Part 3 — The Contract

This is the specification: the single source of truth both sides implement and test against.

## 3.1 Envelope

All messages, both directions:

```typescript
interface BifrostEnvelope {
  event: string;                    // action name, camelCase
  data: Record<string, unknown>;    // always an object, may be empty
  requestId?: string;               // present for RPC; absent for FAF/push
  error?: {
    code: string;                   // SCREAMING_SNAKE_CASE stable code
    message: string;                // developer-facing English
    details?: Record<string, unknown>;
    retryable?: boolean;
  };
}
```

## 3.2 Transport

- **Web → native**: `window.flutter_inappwebview.callHandler('flutterHandler', JSON.stringify(envelope))`.
- **Native → web**: a single receiver, `window.onFlutterMessage(rawJson)`, installed by the web bifrost on init. (This replaces today's dual `onFlutterEvent` + `__bridge_receive__` — see migration note in §6.)

## 3.3 Patterns per action

Each action is one of `FAF` (fire-and-forget), `RPC` (request/response), or `PUSH` (native→web only).

## 3.4 Action registry

| Event | Direction | Pattern | Phase | Purpose |
|---|---|---|---|---|
| `initData` | W→N | RPC | 1 | Web requests bootstrap context (token, runner, device, capabilities). |
| `initError` | N→W | PUSH | 1 | Native signals init is impossible before web asked. |
| `navigate` | W→N | RPC | 1 | Open native Flutter screen via `snabbit://` URI. |
| `closeWebView` | W→N | FAF | 1 | Dismiss webview route; optional result. |
| `openUrl` | W→N | RPC | 1 | Open external URL via OS. |
| `callPhone` | W→N | RPC | 1 | Place a phone call. |
| `trackEvent` | W→N | FAF | 1 | CleverTap action event. |
| `observabilityEvent` | W→N | FAF | 1 | JS error / network failure / performance metric. |
| `tokenExpired` | W→N | RPC | 1 (min) / 2 (full) | Phase 1: `{closing:true}` → native pops webview. Phase 2: attempts refresh, returns new token. |
| `backPressed` | N→W | PUSH | 1 | System back button pressed. |
| `trackUserProperties` | W→N | FAF | 2 | CleverTap user profile update. |
| `dataSync` | W→N | FAF | 2 | Web signals native that entity X was updated. |
| `dataUpdated` | N→W | PUSH | 2 | Native signals web that entity X was updated. |
| `permissionRequest` | W→N | RPC | 2 | Request OS permission on demand (replaces `WebViewArgs.fetchLocation`). |
| `tokenRefreshed` | N→W | PUSH | 2 | Native proactively signals new token (rare; e.g., admin forced rotation). |
| `memoryWarning` | N→W | PUSH | 2 | OS reported memory pressure. |

## 3.5 Error codes (starting set)

| Code | Used by | Retryable? | Meaning |
|---|---|---|---|
| `UNKNOWN_ACTION` | router | no | Event not registered. |
| `INVALID_PAYLOAD` | any | no | Required field missing or wrong type. |
| `ORIGIN_BLOCKED` | (not sent, logged only) | — | Inbound blocked by origin gate. |
| `UNKNOWN_ROUTE` | navigate | no | URI host not in registry. |
| `INVALID_ARGS` | navigate | no | URI args failed validation. |
| `DEBOUNCED` | navigate | no | Duplicate request within debounce window. |
| `PATTERN_MISMATCH` | router | no | FAF action received with requestId, or RPC without. |
| `INTERNAL_ERROR` | any | yes | Handler threw unexpectedly. |
| `TOKEN_UNAVAILABLE` | initData | yes | Native has no token to give. |
| `TOKEN_EXPIRED` | any | yes | Access token rejected by backend. |
| `BIFROST_TIMEOUT` | web-side | yes | Native did not respond within deadline. |
| `PERMISSION_DENIED` | permissionRequest | no | User denied. |
| `PERMISSION_UNAVAILABLE` | permissionRequest | no | Permission cannot be requested (e.g., "never ask again"). |
| `INVALID_URL_SCHEME` | openUrl | no | Scheme not allowlisted. |
| `INVALID_PHONE_NUMBER` | callPhone | no | Number failed sanitization. |
| `CAPABILITY_NOT_SUPPORTED` | any | no | Action's capability not negotiated in initData. |

Per-action JSON schemas live alongside fixtures at `test/fixtures/bifrost_contract/<action>/`. Filled in during handler PRs.

---

# Part 4 — Architecture

## 4.1 Module layout (Dart)

```
lib/services/webview/
├── bifrost_envelope.dart          # Typed envelope. Parse + serialize. No I/O.
├── bifrost_error_codes.dart       # Stable codes (String constants).
├── bifrost_router.dart            # Origin gate, RPC correlation, dispatch.
├── bifrost_handlers.dart          # All inbound handlers. One function each.
├── bifrost_pusher.dart            # Outbound: backPressed, memoryWarning, dataUpdated.
├── route_registry.dart           # snabbit:// URI → Flutter route map + arg parsing.
└── webview_channel.dart          # Abstraction over InAppWebViewController (mockable).

lib/pages/
└── app_web_view_page.dart        # Thin widget. Lifecycle + scaffold + route args.
```

Philosophy: start with a small number of files. Split only when a file crosses ~300 lines and has a natural fault line. Don't pre-divide.

## 4.2 Key abstractions

```dart
// The seam between bifrost code and the InAppWebView API.
// Every handler depends on this; nothing depends on InAppWebViewController directly.
abstract class WebViewChannel {
  Future<String?> getCurrentUrl();
  Future<void> pushEvent(String event, Map<String, dynamic> data);
  Future<void> sendResponse({
    required String event,
    required String requestId,
    Map<String, dynamic>? data,
    BifrostError? error,
  });
  void registerInboundHandler(String handlerName, InboundHandler cb);
  Future<void> clearSessionForOrigin(String origin);
  Future<void> stopLoading();
}

class InAppWebViewChannel implements WebViewChannel { /* adapter */ }
class FakeWebViewChannel implements WebViewChannel { /* test double; records calls */ }

// Typed envelope.
class BifrostEnvelope {
  final String event;
  final Map<String, dynamic> data;
  final String? requestId;
  final BifrostError? error;

  static BifrostEnvelope? tryParse(String raw);  // null on malformed
  String toJson();
}

// Handler pattern: each handler declares its pattern and implementation.
abstract class BifrostHandler {
  String get actionName;
  BifrostPattern get pattern;                   // FAF or RPC
  Future<BifrostResult> handle(Map<String, dynamic> data);
}

// Dependencies injected into handlers: no BuildContext, no controllers.
class HandlerDependencies {
  final AppNavigator navigator;                // uses GlobalKey<NavigatorState>
  final AnalyticsSink analytics;               // wraps CleverTapPlugin
  final TokenService tokens;
  final PermissionService permissions;
  final UrlLauncher urlLauncher;
  final MonitoringService monitor;
}
```

Every dependency is injectable. Every collaborator is a small interface. Handlers are pure functions from `(deps, data) → result`, easy to test.

## 4.3 Router sketch

```dart
class BifrostRouter {
  final WebViewChannel channel;
  final OriginGate originGate;
  final Map<String, BifrostHandler> handlers;
  final MonitoringService monitor;
  final DuplicateRequestIdCache requestIdCache;

  Future<void> onInbound(String rawJson) async {
    final stopwatch = Stopwatch()..start();

    final env = BifrostEnvelope.tryParse(rawJson);
    if (env == null) {
      monitor.log('bifrost_parse_failed', {'raw': rawJson});
      return;
    }

    final currentUrl = await channel.getCurrentUrl();
    if (!originGate.isAllowed(currentUrl)) {
      monitor.log('bifrost_origin_blocked', {
        'event': env.event,
        'url': _maskOrigin(currentUrl),
      });
      return; // silent drop
    }

    if (env.requestId != null && requestIdCache.contains(env.requestId!)) {
      monitor.log('bifrost_duplicate_request', {'event': env.event});
      return;
    }
    if (env.requestId != null) requestIdCache.record(env.requestId!);

    final handler = handlers[env.event];
    if (handler == null) {
      await _respondErrorOrLog(env, 'UNKNOWN_ACTION');
      return;
    }

    if (!_patternMatches(handler.pattern, env.requestId != null)) {
      await _respondErrorOrLog(env, 'PATTERN_MISMATCH');
      return;
    }

    try {
      final result = await handler.handle(env.data);
      if (handler.pattern == BifrostPattern.rpc) {
        await channel.sendResponse(
          event: env.event,
          requestId: env.requestId!,
          data: result.data,
          error: result.error,
        );
      }
    } catch (e, st) {
      monitor.logError('bifrost_handler_threw', {
        'event': env.event, 'error': e.toString(), 'stack': st.toString(),
      });
      if (env.requestId != null) {
        await _respondErrorOrLog(env, 'INTERNAL_ERROR', message: e.toString());
      }
    } finally {
      stopwatch.stop();
      monitor.log('bifrost_handler_done', {
        'event': env.event,
        'durationMs': stopwatch.elapsedMilliseconds,
        'ok': true, // set false on error in catch
      });
    }
  }
}
```

Every decision point is a log event. Every branch is a test case.

---

# Part 5 — TDD Plan

## 5.1 Why TDD specifically

The bifrost is a small-surface, high-criticality, protocol-shaped layer. That combination is TDD's sweet spot:

- **Small surface** means tests can exhaustively cover behavior without blowing up in line count.
- **High criticality** means the cost of a regression is high — every web-driven screen breaks simultaneously.
- **Protocol-shaped** means inputs are concrete (JSON strings) and outputs are concrete (side effects + JSON strings). Easy to express as assertions.

Writing tests second here is writing the proof-of-correctness after the crime. Writing them first forces the contract to be concrete before the implementation can cheat.

## 5.2 Test layers

```
┌──────────────────────────────────────────────────┐
│ Integration (real InAppWebView + harness HTML)   │ Nightly CI. 3–5 scenarios.
├──────────────────────────────────────────────────┤
│ Widget (AppWebViewPage with FakeWebViewChannel)  │ 10–15 scenarios.
├──────────────────────────────────────────────────┤
│ Contract (shared JSON fixtures, Dart + TS)       │ One per action × outcome.
├──────────────────────────────────────────────────┤
│ Unit (envelope, router, handler, gate, registry) │ 80+ tests. Fast, pure Dart.
└──────────────────────────────────────────────────┘
```

## 5.3 Unit tests — exhaustive coverage

### Envelope (`bifrost_envelope_test.dart`)

- Valid envelope parses (happy path).
- Missing `event` → null.
- Missing `data` → substituted `{}`.
- `data` as non-object → null.
- Extra unknown top-level fields → ignored.
- `requestId` present but not string → null.
- `error` present with invalid shape → null.
- Non-JSON input → null.
- Nested payload parses.
- Property tests on random valid JSON: never throws (optional; if we adopt `glados`).

### Origin gate (`origin_gate_test.dart`)

- Exact match → allowed.
- Null URL → blocked.
- Different origin → blocked.
- Subdomain shenanigans (`a.coins.snabbit.com.attacker.com`) → blocked.
- Secondary allowlist entry → allowed.
- URL with non-http scheme → blocked.

### Router (`bifrost_router_test.dart`)

- Unknown action with `requestId` → error response with `UNKNOWN_ACTION`.
- Unknown action without `requestId` → logged, no response.
- Blocked origin → no handler invoked, no response.
- Handler throws → `INTERNAL_ERROR` response (if RPC) + error log.
- Handler with `pattern = FAF` + `requestId` present → `PATTERN_MISMATCH` response.
- Handler with `pattern = RPC` + no `requestId` → `PATTERN_MISMATCH` (or just log; TBD).
- Handler with RPC returns normally → response sent with matching `requestId`, correct shape.
- Duplicate `requestId` within window → dropped, logged.
- Logs fire for each decision point.

### Route registry (`route_registry_test.dart`)

- Each known host → returns correct Flutter route + typed args.
- Unknown host → null.
- Unknown scheme → null.
- Query args parsed and type-checked.
- Missing required arg → null.

### Per-handler tests

One file per handler. Each has:

- Happy path: valid payload → expected side effect + expected response.
- Every error code in its documented code list → matching response.
- Payload validation: missing field, wrong type, out-of-range value.
- Side effect mocking: navigator.push called with expected args, analytics.track called, etc.

Example (`navigate_handler_test.dart`):

```dart
group('NavigateHandler', () {
  late FakeAppNavigator navigator;
  late NavigateHandler handler;

  setUp(() {
    navigator = FakeAppNavigator();
    handler = NavigateHandler(navigator: navigator);
  });

  test('pushes named route with typed args', () async {
    final result = await handler.handle({
      'route': 'snabbit://add-bank-upi',
      'data': {'source': 'payout_page', 'returnEvent': 'BANK_ADDED'},
    });
    expect(result.isOk, isTrue);
    expect(navigator.pushed, hasLength(1));
    expect(navigator.pushed.first.routeName, '/add-bank-upi');
    expect(navigator.pushed.first.args['source'], 'payout_page');
  });

  test('rejects unknown route', () async {
    final result = await handler.handle({'route': 'snabbit://nonexistent'});
    expect(result.error?.code, 'UNKNOWN_ROUTE');
    expect(navigator.pushed, isEmpty);
  });

  test('rejects missing route field', () async {
    final result = await handler.handle({});
    expect(result.error?.code, 'INVALID_PAYLOAD');
  });

  test('uses pushReplacementNamed when closeBehavior=replace', () async {
    await handler.handle({
      'route': 'snabbit://payout-home',
      'closeBehavior': 'replace',
    });
    expect(navigator.pushed.first.isReplace, isTrue);
  });

  test('debounces rapid duplicate requests', () async {
    final first = await handler.handle({'route': 'snabbit://payout-home'});
    final second = await handler.handle({'route': 'snabbit://payout-home'});
    expect(first.isOk, isTrue);
    expect(second.error?.code, 'DEBOUNCED');
  });
});
```

Coverage targets:
- **100% branch coverage** on envelope parser, origin gate, router dispatch, registry.
- **Every error code** in the per-handler registry has a test producing it.
- No blanket percentage goal. If an edge case is documented, it has a test. If it's not documented, it either shouldn't happen or the documentation is wrong.

## 5.4 Contract tests — shared fixtures

Directory:
```
test/fixtures/bifrost_contract/
├── navigate/
│   ├── request.valid.json
│   ├── request.missing_route.json
│   ├── response.success.json
│   ├── response.unknown_route.json
│   └── response.debounced.json
├── initData/
│   ├── request.valid.json
│   ├── response.success.json
│   └── response.token_unavailable.json
└── ...
```

Dart test pattern:
```dart
test('navigate/request.valid.json produces navigate/response.success.json', () async {
  final request = await loadFixture('navigate/request.valid.json');
  final result = await handler.handle(request['data']);
  final expected = await loadFixture('navigate/response.success.json');
  expect(result.toJson(), equalsJson(expected));
});
```

TS test pattern (in `app-webview/` repo):
```ts
it('navigate/request.valid.json serializes correctly', () => {
  const request = loadFixture('navigate/request.valid.json');
  const sent = bifrostSpy.captureLastSent(() => {
    bifrost.request('navigate', request.data);
  });
  expect(JSON.parse(sent)).toEqual(request);
});
```

Both sides test against the same bytes. Contract drift is a diff.

Distribution:
- Phase 0: check fixtures into this repo. Web repo symlinks during build.
- Phase 2: if drift becomes a real problem, publish as a small npm package and Dart package with auto-sync.

## 5.5 Widget tests

`test/widget/app_web_view_page_test.dart`:

- Mount page with fake channel → loading indicator visible.
- Simulate page-loaded event → indicator hidden.
- Simulate load-error → error widget shown.
- Tap retry → channel re-created, state reset.
- Back press → `backPressed` sent; if fake channel responds with `closeWebView`, page pops; else watchdog fires in 1500ms, page pops anyway.

Prerequisite: constructor of `AppWebViewPage` accepts an optional `WebViewChannel` factory for injection in tests.

## 5.6 Integration tests (nightly)

One static harness page at `test_resources/bifrost_harness/index.html` bundling the web bifrost code without React:

- Open a webview pointed at the harness on emulator.
- Drive a scripted sequence: `requestInitData` → assert `initData` response received → send `navigate` to a stub route → assert native navigated → send `closeWebView` → assert webview popped.
- Negative: load a page with a different origin, attempt `callPhone`, assert dropped.

Slow, flaky-prone. Gate on "bifrost-touching" PRs + nightly CI.

## 5.7 Coverage enforcement

CI:
- Unit tests run on every PR. Branch coverage measured; drop below 100% on the critical list triggers failure.
- Contract tests run on every PR in both repos. Mismatch triggers failure.
- Widget tests run on every PR.
- Integration tests run nightly + on bifrost-touching PRs (detected via changed-files check).

---

# Part 6 — Migration & Rollout

## 6.1 Core strategy: evolve in place

Today's web bifrost and today's Flutter handler are close enough to the target design that we don't rewrite — we incrementally add:

1. Add `requestId` parsing + response capability on Dart side.
2. Add origin gate on Dart side.
3. Unify web's `onFlutterEvent` + `__bridge_receive__` into a single `onFlutterMessage` receiver. Add top-level `error` field support.
4. Ship new handlers (`navigate`, `trackEvent`, `observabilityEvent`, `tokenExpired`-minimal) with TDD.
5. Make `initData` dual-mode: native responds to `requestInitData` requests AND keeps pushing on page-load. Web migrates to `requestInitData`-only call site.
6. Drop the legacy push.

Throughout, Seva and Merch Store continue to work because:
- Current actions (`openUrl`, `callPhone`, `closeWebView`, `requestInitData`) behave identically except they now go through the origin gate (which allows their own origin — no regression) and participate in RPC responses if web asks (which existing web code doesn't, so no difference).
- `initData` keeps pushing during the transition.

## 6.2 Phases

| Phase | Scope | Duration | Gate |
|---|---|---|---|
| **0** | Refactor: inject `WebViewChannel` into `AppWebViewPage`; add envelope parser; add origin gate; add RPC response machinery; wire up contract fixtures. No new actions. All existing actions still work. | ~1 week | Merge. |
| **1a** | New handlers: `navigate`, `trackEvent`, `observabilityEvent`, `tokenExpired` (minimal). Web patches: unified `onFlutterMessage`, top-level `error` support, `requestInitData` as the only init path. | ~2 weeks | Remote config `webviewBifrostV2` per cluster. |
| **1b** | Drop legacy `initData` push once web telemetry confirms zero reliance. | <1 week | None. |
| **2** | `trackUserProperties`, `dataSync` / `dataUpdated`, `permissionRequest`, `tokenRefreshed`, `memoryWarning`, full refresh flow. | ~3 weeks | Per-capability remote config. |

Phase 0 + 1a is the Rate Card 2.0 launch blocker.

## 6.3 Kill switches

Two levers:

- **`rateCardUrl` null** → Payout 3.0 falls back to native. User-facing.
- **`webviewBifrostV2` off** → new handlers return `{error: {code: "DISABLED"}}`. Bifrost-internal. Used for rollback if v2 bifrost misbehaves.

Independence matters: if Phase 2 observability has a bug, we disable observability capability without disabling Rate Card 2.0.

---

# Part 7 — Open Questions

1. **Access token TTL (backend).** Drives whether Phase 1's close-on-expiry is acceptable or we need the refresh flow on day one. Ask: what is the current access token lifetime?
2. **CleverTap web SDK.** Are there growth use cases that need web-side analytics? If no, our bifrost-forwarding model is correct. Confirm with growth.
3. **Fixture distribution.** Symlink, copy-on-CI, or published packages? Start with symlink; revisit if drift appears.
4. **Observability SDK routing on native.** Today: Crashlytics + Coralogix. Does routing rules (e.g., JS errors → Coralogix only, fatal → both) match product-engineering ops preferences?
5. **Shorebird OTA + bifrost compat.** If we ship a bifrost-breaking Flutter change via Shorebird without an App Store release, web must deploy first. The capability negotiation mechanism handles this, but our release runbook should document the ordering. Ask: who owns the runbook?
6. **Watchdog timeout value (1500ms).** Is that acceptable UX on low-end Android? Measure during beta.
7. **Crypto-grade request IDs.** Current format is timestamp+random(~40 bits). Collision within a 60s window is astronomically unlikely. If we grow to high-volume bridges, upgrade to `crypto.randomUUID()`.

---

# Appendices

## Appendix A — Glossary

- **Action.** A named message type (`navigate`, `trackEvent`). Part of the contract.
- **Capability.** A named feature that either side declares support for. Used for compat negotiation.
- **Envelope.** The wire-format wrapper around every message.
- **FAF / RPC / PUSH.** The three communication patterns (§2.2).
- **Handler.** The Dart function that processes a specific inbound action.
- **Origin gate.** The Dart pre-handler check that rejects messages from non-allowlisted origins.
- **Pusher.** The Dart code path that sends a native→web push event.
- **Route registry.** The `snabbit://` URI → Flutter route mapping.

## Appendix B — Rejected options log (summary)

| Decision | Rejected | Why |
|---|---|---|
| Envelope | Flat shape (`{type, route, closeBehavior}`) | Metadata and payload collide. |
| Envelope | JSON-RPC 2.0 shape | Ecosystem tooling not useful here; protocol preamble is dead weight. |
| Correlation | Monotonic sequence number | Order-dependent; one loss breaks alignment. |
| Init | Push from native | Race with web's subscription timing. |
| Auth | HttpOnly cookie | Backend doesn't support; Android CookieManager known issues; yields only marginal security vs. short-lived bearer. |
| Auth | Hybrid (cookie + bearer) | All of cookie's costs plus dual code paths. Revisit post-launch. |
| Versioning | Monotonic `v` field | Forces lockstep releases; doesn't enable runtime feature detection. |
| Serialization | Protobuf/MessagePack | No size/performance pressure justifying codegen cost. |
| Navigation | Named Flutter routes | Coupled to Flutter internals; not reusable for push/external deeplinks. |
| Back button | Native always pops | Breaks SPA internal navigation. |
| Observability | Web-side SDK | Adblocker-prone; fragments dashboards. |
| Teardown | Keep-alive / pooled webview | Memory-hostile for Runner app; premature optimization. |

## Appendix C — References

**Current repos / code:**
- [Current Flutter webview page](lib/pages/app_web_view_page.dart)
- [Current event handler](lib/services/webview_event_handler.dart)
- [Current constants](lib/utils/webview_constants.dart)
- Web bifrost: `app-webview/bifrost/` (types.ts, bifrost.ts, actions.ts, index.ts)

**Internal specs:**
- [Webview Implementation View (Payouts 3.0 HLD/LLD)](https://www.notion.so/34101ab9baf2802bb801d930d5fcb8f1)
- [Rate Card 2.0 Mobile](https://www.notion.so/33e01ab9baf28162b887f319f28b9b3a)

**External references:**
- [flutter_inappwebview JS communication docs](https://inappwebview.dev/docs/webview/javascript/communication/)
- [flutter_inappwebview bearer-token issue #1230](https://github.com/pichillilorenzo/flutter_inappwebview/issues/1230)
- [flutter_inappwebview Android cookie issues #2009](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2009)
- [React Native new architecture / bridgeless mode discussion](https://github.com/reactwg/react-native-new-architecture/discussions/154)
- [Capacitor bifrost and plugin system](https://deepwiki.com/ionic-team/capacitor/4.1-bifrost-and-plugin-system)
- [VS Code webview API guide](https://code.visualstudio.com/api/extension-guides/webview)
- [JSON-RPC 2.0 spec](https://www.jsonrpc.org/specification)
- [OpenTelemetry batch span processor](https://opentelemetry.io/docs/specs/otel/trace/sdk/#batching-processor)
- [OWASP: Securing webviews](https://owasp.org/www-project-mobile-top-10/)
