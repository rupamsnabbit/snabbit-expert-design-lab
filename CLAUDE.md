# CLAUDE.md — snabbit-runner-app

Project rules for AI agents (Claude Code, the `/claude-review` & `/flutter-review` PR bots, Copilot)
and humans reviewing PRs. Rules are grouped by severity. Every rule reflects a convention that
actually exists in this codebase — if a rule and the code disagree, fix the code or update this file.

---

## KMP Migration (Active)

This app is undergoing a phased strangler-fig migration from Flutter to Kotlin Multiplatform + Compose Multiplatform.
KMP shared module: `shared/` · Package: `com.snabbit.runner.shared`
Stack: Kotlin 2.2.21 · CMP 1.10.x · Navigation 3 (2.9.2) · Koin 4.2.1 · Ktor 3.5.0 · Design System 0.19.0

**For every KMP task — these facts are always in context:**
@.claude/documents/core-facts.md

**Reference documents loaded by skills (do not load manually):**
- MVI structure + folder layout → `.claude/documents/feature-template.md`
- CmpHostActivity + storage + background work → `.claude/documents/platform-rules.md`
- Pinned versions + blocklist + iOS gate → `.claude/documents/library-guide.md`
- Branch model + dual-PR workflow → `.claude/documents/git-discipline.md`

**Skills:**
- `/build-feature` — scaffold or extend a KMP feature (full or screen-only mode)
- `/review-changes` — PR review across architecture, concurrency, and UI dimensions

---

## Project snapshot
- **Android-only Flutter app** for Snabbit *runners/experts*. Package `com.snabbit.runner`.
- **State management: `provider` (ChangeNotifier).** There is **no Riverpod and no Freezed** here.
  Do **not** introduce them or recommend an "MVVM + Riverpod" migration — that is the *customer*
  app's stack, not this one.
- Code-push via **Shorebird**; runtime flags via **Firebase Remote Config**.
- Analytics: **CleverTap + Mixpanel + Firebase Analytics**.
- Heavy **background-service, location, maps & notification** code — treat changes there as risky.

## Key files to consult first
- App bootstrap, route map & DI wiring: `lib/main.dart` (routes are an inline `routes: {}` map)
- Shared helpers (conversions, formatting): `lib/utils/common_methods.dart`
- Colors & theme: `lib/utils/colors.dart` (`AppColors`), `lib/utils/themes.dart` (`AppTheme`)
- Remote Config keys: `lib/services/remote_config/remote_config_keys.dart` (`RemoteConfigKeys`)
- Logging/monitoring: `lib/services/monitoring/monitoring_service_helper.dart`
- Analytics: `lib/services/clevertap.dart`, `lib/utils/tracking_events.dart`
- State: `lib/providers/` (35+ `ChangeNotifier`s)
- Product design rules: `docs/design/README.md`
- Testing philosophy & commands: `COVERAGE_STRATEGY.md`, `Makefile`

## Common commands
```bash
make install         # flutter pub get
make analyze         # flutter analyze
make format          # dart format lib/ test/
make format-check    # dart format --set-exit-if-changed lib/ test/
make test            # flutter test
make test-my-changes # coverage for your changed lines (recommended before a PR)
make coverage-check  # enforce line targets + branch coverage on changed code
```

---

# Code Review Checklist

When reviewing a PR (including via `/claude-review` or `/flutter-review`), enforce these. Flag **only
issues introduced by the diff** (added/changed lines) — do not flag pre-existing debt in untouched code.

## Critical (must fix before merge)

**Error handling & logging**
- No silent `catch {}` / `catch (e) {}` / `catch (_) {}`. Caught exceptions must be logged via
  `MonitoringServiceHelper` (`logError`/`logCriticalError`/`reportError`) or
  `FirebaseCrashlytics.instance.recordError(...)`. Re-throw or handle — never swallow.
- No `print()` for diagnostics in shipped code — use `MonitoringServiceHelper` logging.

**Lifecycle & async safety**
- Dispose every `TextEditingController`, `AnimationController`, `Timer`, `StreamSubscription`,
  `ScrollController`, etc. in `dispose()`.
- Guard `mounted` before `setState(...)` / `Provider`/`notifyListeners` consumers after an `await`.
- Never use a `BuildContext` across an `async` gap without a `mounted` check
  (`use_build_context_synchronously`).

**Type conversions for dynamic/API data**
- Parse with the project helpers in `common_methods.dart` — `anyValueToInt(...)`,
  `anyValueToDouble(...)` — **never** `int.parse` / `double.parse` / manual casts on API/JSON values.
- Durations: `minsToHours(...)`. Money: `formatIndianCurrency(...)` / `formatIndianCurrency2(...)`.
  (Note: there is **no** `formatMinutesAsHour` or `formatPhoneNumber` helper here.)

**Secrets & state**
- No secrets, API keys, tokens, signing material, or PII in the diff (code, logs, or fixtures).
- New `ChangeNotifier` state belongs in `lib/providers/`; call `notifyListeners()` on mutation and
  avoid notifying inside `build`.

## Important (should fix)

**Sizing — ScreenUtil**
- Pixel values use ScreenUtil extensions: `.w` (width), `.h` (height), `.sp` (font), `.r`
  (radius/symmetric). Symmetric squares/circles use `.r` on both axes (e.g. `93.r`, not `93.w`+`93.h`).
- No raw numeric literals in `EdgeInsets`, `SizedBox`, `BorderRadius`, or `fontSize`.

**Colors & theme**
- Colors come from `AppColors` (`lib/utils/colors.dart`) — no inline `Color(0x…)` literals.
- New screens build on `AppTheme.lightTheme` / `darkTheme`; type styles via the theme's text theme.

**Remote Config & rollout safety**
- New runtime flags/values go through `RemoteConfigKeys` with a **safe default**; behaviour must
  degrade gracefully when Remote Config is unavailable or returns the default.
- Shorebird forced-patch / `exit(0)` / restart paths must be reversible and gated behind an RC flag
  or kill-switch. Call out the kill-switch in the PR.

**Navigation**
- Screens expose `static const String routeName`; register routes in the `routes` map in `main.dart`;
  navigate with `Navigator.of(context).pushNamed(...)`.

## Suggestions (nice to have)
- Prefer centralising new user-facing copy rather than scattering string literals (copy is currently
  inconsistent — some hardcoded, some via Remote Config; don't make it worse).
- Three-state UI: handle loading / error / empty, not just the happy path.
- Use `cached_network_image` / the project image handling for remote images.
- Long lists should be lazy (`ListView.builder`), with empty states.

---

# Testing rules
- Follow `COVERAGE_STRATEGY.md`: pragmatic line targets (50–80% by criticality) and 100% branch
  coverage on **new/changed** code. Run `make test-my-changes` before opening a PR.
- Mocks use `mockito` + `build_runner` (`@GenerateMocks([...])`) — re-run codegen after changing them.
- Test layout mirrors `lib/` under `test/unit/` (+ `test/widget/`, `test/integration/`). Name files
  `*_test.dart`; use the Arrange-Act-Assert + builder patterns shown in `COVERAGE_STRATEGY.md`.
- Don't test generated code (`*.g.dart`, `*.freezed.dart`), pure constants, or `main.dart`.

---

# AI behavioural rules
- **No blind edits.** Before modifying a file, read it fully and confirm the change is correct
  against the surrounding code and the rules above.
- Match the file you're editing — its naming, comment density, and idioms.
- When you produce a rule, skill, or instruction, make it deterministic and self-contained; verify
  it's AI-executable before presenting it.
- Don't claim something is verified unless you ran it. If tests/analyze weren't run, say so.

---

# Opening a pull request
GitHub does **not** auto-apply the PR template to PRs created via `gh`, the API, or any Claude
surface — only the web "Compare & pull request" form does. So whenever **you** open a PR for this
repo, write the description **from `.github/PULL_REQUEST_TEMPLATE.md`**: fill every section — Summary,
Jira, Type of change, **Dev tested?**, the checklists (tick honestly, delete rows that don't apply),
How to test, Rollout & rollback, and Screenshots. Don't substitute your own PR format.
