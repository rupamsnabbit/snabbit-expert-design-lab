# Bridge Contract Fixtures

Shared source of truth for the Flutter ↔ web bridge wire format.
See `docs/webview-bridge-implementation-plan.md` §1.1.

One folder per action. Each folder holds `request.*.json` and (for RPC actions
in later slices) `response.*.json`. The JSON must be valid for both the Dart
envelope parser and the TypeScript bridge.

The web repo (`app-webview`) symlinks its own fixtures directory at
`test/fixtures/` back to this folder so both sides test the exact same bytes.
Distribution set up in slice 0.3.
