#!/usr/bin/env bash
# Sanity-checks the 6 secrets required by .github/workflows/play-console-release.yml
# BEFORE you paste them into GitHub repo secrets.
#
# Usage:
#   1. Drop the values into the env vars below (DO NOT commit this file with values filled in).
#   2. Run: bash scripts/verify-play-secrets.sh
#
# Exits non-zero if anything looks wrong. Nothing is uploaded; this is local-only.

set -uo pipefail

# ────────────────────────────────────────────────────────────────────
# Fill these in locally. NEVER commit values.
# Easiest: `export KEYSTORE_BASE64=...` etc. in your shell, then run.
# ────────────────────────────────────────────────────────────────────
: "${KEYSTORE_BASE64:?Set KEYSTORE_BASE64 in your env before running}"
: "${KEYSTORE_PASSWORD:?Set KEYSTORE_PASSWORD}"
: "${KEY_PASSWORD:?Set KEY_PASSWORD}"
: "${KEY_ALIAS:?Set KEY_ALIAS}"
: "${PLAY_SERVICE_ACCOUNT_JSON:?Set PLAY_SERVICE_ACCOUNT_JSON (raw JSON content, not a path)}"
: "${SHOREBIRD_TOKEN:?Set SHOREBIRD_TOKEN}"

EXPECTED_ALIAS="snabbit_runner_upload"
EXPECTED_PACKAGE="com.snabbit.runner"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { echo "  ✅ $*"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $*"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $*"; }
hdr()  { echo ""; echo "─── $* ───"; }

# 1. KEYSTORE_BASE64 ─────────────────────────────────────────────────
hdr "1/6  KEYSTORE_BASE64"
if [[ "$KEYSTORE_BASE64" == *$'\n'* ]]; then
  bad "Contains newlines. Re-encode with: base64 -i ks.jks | tr -d '\\n'"
else
  ok "Single line (no newlines)"
fi

KS="$TMP/ks.jks"
if echo "$KEYSTORE_BASE64" | base64 --decode > "$KS" 2>/dev/null; then
  if [[ -s "$KS" ]]; then
    ok "Decoded to non-empty file ($(wc -c < "$KS") bytes)"
  else
    bad "Decoded file is empty"
  fi
else
  bad "base64 decode failed"
fi

# 2 + 3 + 4. Passwords + Alias ───────────────────────────────────────
hdr "2-4/6  KEYSTORE_PASSWORD / KEY_PASSWORD / KEY_ALIAS"

# List aliases using store password
LIST_OUT=$(keytool -list -keystore "$KS" -storepass "$KEYSTORE_PASSWORD" 2>&1 || true)
if echo "$LIST_OUT" | grep -qi "keystore was tampered\|password was incorrect"; then
  bad "KEYSTORE_PASSWORD rejected by keytool"
elif echo "$LIST_OUT" | grep -q "Your keystore contains"; then
  ok "KEYSTORE_PASSWORD accepted"
  if echo "$LIST_OUT" | grep -qi "^${EXPECTED_ALIAS}," ; then
    ok "Alias '$EXPECTED_ALIAS' found in keystore"
  else
    bad "Alias '$EXPECTED_ALIAS' NOT found. Aliases present:"
    echo "$LIST_OUT" | grep -E "^[a-zA-Z0-9_-]+," | sed 's/^/      /'
  fi

  if [[ "$KEY_ALIAS" != "$EXPECTED_ALIAS" ]]; then
    bad "KEY_ALIAS is '$KEY_ALIAS', expected '$EXPECTED_ALIAS' (per workflow)"
  else
    ok "KEY_ALIAS matches expected '$EXPECTED_ALIAS'"
  fi
else
  bad "keytool -list failed unexpectedly:"
  echo "$LIST_OUT" | sed 's/^/      /'
fi

# Verify key password by trying to export the private key entry
KEY_CHECK=$(keytool -keypasswd \
  -keystore "$KS" \
  -storepass "$KEYSTORE_PASSWORD" \
  -alias "$KEY_ALIAS" \
  -keypass "$KEY_PASSWORD" \
  -new "$KEY_PASSWORD" 2>&1 || true)
if echo "$KEY_CHECK" | grep -qi "password was incorrect\|cannot recover key"; then
  bad "KEY_PASSWORD rejected for alias '$KEY_ALIAS'"
elif [[ -z "$KEY_CHECK" ]] || echo "$KEY_CHECK" | grep -qi "warning"; then
  ok "KEY_PASSWORD accepted for alias '$KEY_ALIAS'"
else
  warn "KEY_PASSWORD check inconclusive:"
  echo "$KEY_CHECK" | sed 's/^/      /'
fi

# 5. PLAY_SERVICE_ACCOUNT_JSON ───────────────────────────────────────
hdr "5/6  PLAY_SERVICE_ACCOUNT_JSON"
SA_FILE="$TMP/sa.json"
echo "$PLAY_SERVICE_ACCOUNT_JSON" > "$SA_FILE"

if ! python3 -c "import json,sys; json.load(open('$SA_FILE'))" 2>/dev/null; then
  bad "Not valid JSON. (Did you base64-encode it by mistake? Should be raw JSON.)"
else
  ok "Valid JSON"
  TYPE=$(python3 -c "import json; print(json.load(open('$SA_FILE')).get('type',''))")
  EMAIL=$(python3 -c "import json; print(json.load(open('$SA_FILE')).get('client_email',''))")
  if [[ "$TYPE" == "service_account" ]]; then
    ok "type = service_account"
  else
    bad "type field is '$TYPE', expected 'service_account'"
  fi
  if [[ "$EMAIL" == *@*.iam.gserviceaccount.com ]]; then
    ok "client_email looks valid: $EMAIL"
    warn "Make sure this email has 'Release manager' on Play Console for $EXPECTED_PACKAGE"
  else
    bad "client_email missing or malformed: '$EMAIL'"
  fi
fi

# 6. SHOREBIRD_TOKEN ─────────────────────────────────────────────────
hdr "6/6  SHOREBIRD_TOKEN"
if [[ ${#SHOREBIRD_TOKEN} -lt 20 ]]; then
  bad "Token suspiciously short (${#SHOREBIRD_TOKEN} chars). Did you copy fully?"
else
  ok "Token length looks reasonable (${#SHOREBIRD_TOKEN} chars)"
fi
if command -v shorebird >/dev/null 2>&1; then
  # Try a benign command with the token to validate
  SHOREBIRD_OUT=$(SHOREBIRD_TOKEN="$SHOREBIRD_TOKEN" shorebird account 2>&1 || true)
  if echo "$SHOREBIRD_OUT" | grep -qi "logged in\|email:"; then
    ok "Shorebird CLI accepts token"
  elif echo "$SHOREBIRD_OUT" | grep -qi "not logged in\|unauthorized\|401"; then
    bad "Shorebird CLI rejected token"
    echo "$SHOREBIRD_OUT" | sed 's/^/      /'
  else
    warn "Shorebird CLI output unclear — eyeball it:"
    echo "$SHOREBIRD_OUT" | sed 's/^/      /'
  fi
else
  warn "shorebird CLI not on PATH — can't validate token locally. Install via:"
  warn "  curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash"
fi

# ────────────────────────────────────────────────────────────────────
hdr "Summary"
echo "  ✅ Passed: $PASS"
echo "  ❌ Failed: $FAIL"
echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "All checks passed. Safe to paste these values into GitHub repo secrets."
  exit 0
else
  echo "Fix failures before uploading."
  exit 1
fi
