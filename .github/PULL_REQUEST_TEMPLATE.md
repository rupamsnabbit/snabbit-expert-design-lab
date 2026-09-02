## Summary
<!-- 1–3 lines: what changed and why -->

## Jira
<!-- e.g. ECPO-173, SNCON-92, or "n/a — hotfix" -->

## Type of change
- [ ] Feature
- [ ] Bugfix
- [ ] Refactor / cleanup
- [ ] UI / design
- [ ] Config / CI / infra
- [ ] Docs only

## Dev tested?
<!-- Tag whether you (the developer) have tested this. Tick one. -->
- [ ] Yes — tested on a device/emulator (steps under "How to test")
- [ ] No — not tested yet / needs QA
- [ ] N/A — no runtime change (docs / config only)

## Checklist — always
- [ ] `flutter analyze` is clean for my changes (`make analyze`)
- [ ] Changed Dart files are formatted (`make format`)
- [ ] Re-ran codegen if I touched mocks/generated files (`dart run build_runner build --delete-conflicting-outputs`)
- [ ] Tests added/updated and `make test` passes
- [ ] Coverage checked for my changes (`make test-my-changes` / `make coverage-check`)
- [ ] Caught exceptions are logged via `MonitoringServiceHelper` / Crashlytics — no silent `catch {}`
- [ ] No secrets, keys, tokens, or PII added in the diff

## Checklist — Flutter conventions (delete rows that don't apply)
- [ ] Sizing uses ScreenUtil (`.w` / `.h` / `.sp`, `.r` for symmetric/radius) — no raw pixels in `EdgeInsets` / `SizedBox` / `BorderRadius`
- [ ] Dynamic/API numbers parsed with `anyValueToInt` / `anyValueToDouble` (not `int.parse` / `double.parse`); durations via `minsToHours`; money via `formatIndianCurrency`
- [ ] Colors come from `AppColors` — no inline `Color(0x…)` literals
- [ ] Controllers, timers, stream subscriptions & `AnimationController`s are disposed in `dispose()`
- [ ] `mounted` checked before `setState` / `notifyListeners` after an `await`
- [ ] `BuildContext` is not used across an `async` gap without a `mounted` guard
- [ ] New ChangeNotifier state lives in `lib/providers/` and notifies correctly (no rebuild leaks)

## Checklist — risky changes (or n/a)
- [ ] New Remote Config keys added to `RemoteConfigKeys` with safe defaults; behaviour degrades gracefully if RC is unavailable
- [ ] Shorebird / forced-patch / `exit(0)` paths tested — rollout is reversible (kill-switch or RC flag noted below)
- [ ] Backwards compatible — handles old/missing API fields without crashing
- [ ] Background-service / location / notification behaviour verified if touched

## How to test / verify
<!-- exact steps a reviewer can follow on a device: screen → action → expected result -->

## Rollout & rollback
<!-- For risky changes: deploy order, the RC key / kill-switch that disables it, and how to roll back (e.g. Shorebird patch rollout factor) -->

## Screenshots / screen recording
<!-- Required for any UI or observable behaviour change -->
