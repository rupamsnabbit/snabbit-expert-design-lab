# Bifrost Release Runbook

How to ship a Bifrost (webview↔native bridge) change safely, and how to
roll back when something goes wrong. This doc is specifically about
bridge changes — general Shorebird ops live in the engineering wiki.

> **Audience:** whoever is pushing a Flutter release (Mehar today,
> anyone tomorrow). Read top-to-bottom before your first bridge-touching
> release.

---

## 1. What counts as a bridge-breaking change

A release is **bridge-breaking** if any of the following is true:

- **Wire protocol change** — envelope field renamed, error code renamed,
  action name renamed, request/response shape changed.
- **Action removed** from `NativeCapabilities.supported` (native build
  drops support; web may still try to call it).
- **Handler semantics change** — same action name, different behavior
  (e.g. `closeWebView` now always requires a result arg).
- **Origin-gate tightened** — a previously-allowed origin is now
  rejected; any loaded URL that now fails to match becomes a silent drop.
- **`kDebugMode`-only code paths touched** in a way that could leak into
  release (review the diff; `kDebugMode` tree-shakes in release builds,
  but defensive checks still matter).

A release is **bridge-additive** (safer — Shorebird OTA-safe) when:

- A new action is added with its handler. Web still works without calling
  it; old web doesn't know the action exists.
- A new capability is added to `NativeCapabilities.supported`. Web asks
  for it; intersection handles mismatches.
- A new route URI is added to `defaultWebViewRouteRegistry`. Web can
  navigate to it once both repos know about it.
- Logging added, error messages reworded, test fixtures updated.

**Default assumption:** if unsure, treat as bridge-breaking.

---

## 2. Release ordering (critical)

**Never OTA-patch a bridge-breaking change via Shorebird alone.** The
web app and the native app evolve on different release cadences. An OTA
patch that changes the wire protocol on one side while the other side
is still running the old version produces silent failures in
production.

Canonical order for a bridge-breaking release:

1. **Merge the web change.** Deploy the web build. All runners still on
   the old native app may now be hitting the new web — ensure the web is
   backward-compatible with old native for at least one release cycle.
   - If the web change is not backward-compatible with old native, this
     step is gated on step 4 (native rollout complete).
2. **Cut a native release with the matching Bifrost changes.** Go
   through the normal Play Store / App Store submission path. Do NOT
   Shorebird-patch the bridge as the primary rollout mechanism for a
   breaking change — breakage will surface inconsistently across devices
   depending on who got the patch.
3. **Ramp staged rollout on the store.** Hold at each stage for at least
   one business day; watch Coralogix for `bifrost_*` error spikes.
4. **Confirm telemetry is clean.** Specifically:
   - `bifrost_parse_failed` → zero new entries
   - `bifrost_origin_blocked` → no unexpected origins
   - `bifrost_unknown_action` → legitimate unwired actions only
   - `bifrost_pattern_mismatch` → zero
   - `bifrost_back_watchdog_fired` rate → stable
   - RPC error-code histogram — no unexpected codes
5. **Shorebird patches after this point** are for bug fixes on the
   native code that already shipped. They MUST NOT change the bridge
   contract.

---

## 3. Rollback

### When to roll back

Within the first 24h of rollout, roll back if any of the following
triggers fire in production:

- **Crash-free users < baseline − 0.5 percentage points** on the new
  build vs the previous stable.
- **`bifrost_parse_failed` rate > 0.1%** of bridge messages. (Parser
  failure usually means wire-protocol drift.)
- **`bifrost_back_watchdog_fired` rate > 5× baseline** on the new
  build. (Web is now consistently not responding to backPressed.)
- Sev-1 incident linked to the new build.

### How to roll back

**For a Shorebird-patched release (bridge-additive changes):**

1. `shorebird patches list` — find the bad patch number.
2. `shorebird patches promote --patch <n> --track stable --percentage 0`
   — sets the bad patch to 0% rollout; devices on it will download the
   previous patch on next launch.
3. Announce in #eng-runner-oncall: patch number, trigger, ETA.

**For a store-released build (bridge-breaking changes):**

1. In Play Console / App Store Connect: halt staged rollout and promote
   the previous stable version.
2. If a bridge-breaking change is live for runners who can't update
   (Android < release in staged rollout): ship a Shorebird patch to the
   new build that reverts the bridge-relevant diff only. This is a
   **partial revert** — cherry-pick the revert commit onto the release
   branch and Shorebird-patch it.
3. Web side: deploy a compensating web release that tolerates both the
   old and new bridge shapes, if feasible.
4. Post-incident: blameless postmortem covering (a) why the mismatch
   wasn't caught pre-release, (b) what tests would have caught it, (c)
   runbook updates.

---

## 4. Post-rollout verification

After 100% rollout has been live for 24h, confirm:

- [ ] Coralogix dashboard `bifrost-health` (TODO: create) shows all
      error rates within normal band.
- [ ] MixPanel event counts for bridge-forwarded analytics match
      pre-rollout expectations (no drops = web isn't hitting the new
      action; no spikes = not double-firing).
- [ ] Manual smoke: drawer → Seva → Merch → a route that uses
      `navigate()` → back out of each. No unexpected pops, no hangs.
- [ ] `bifrost_handler_done` p95 duration < 200ms for RPC actions.

If anything deviates, treat as a late-detected regression and follow
§3 triggers.

---

## 5. Pre-release checklist for bridge-touching PRs

Before clicking "merge" on any PR that touches `lib/services/webview/` or
`bifrost/` (web):

- [ ] `flutter analyze` and `flutter test test/unit/services/webview`
      both clean
- [ ] `npx tsc -b` clean on web side (no NEW errors vs base branch)
- [ ] Fixture files updated for every new action / response shape
- [ ] Both sides of the contract actually match — open both
      `test/fixtures/bifrost_contract/<action>/` and spot-check
- [ ] If adding an action: added to `NativeCapabilities.supported` AND
      `WebRequestedCapabilities`
- [ ] If adding a route: URI added to `defaultWebViewRouteRegistry`
      with product sign-off on the URI string
- [ ] Manual smoke on a physical device for at least one happy path

---

## Appendix: Contacts

- **Bridge design & implementation:** Mehar
- **Shorebird account owner:** (TODO)
- **Play Console releases:** (TODO)
- **App Store Connect releases:** (TODO)
- **Coralogix alert owner:** (TODO)
