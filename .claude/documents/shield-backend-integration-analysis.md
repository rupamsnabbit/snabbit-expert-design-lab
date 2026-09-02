---
title: Snabbit Shield — SOS / Recording-Sync / Encryption / Local-DB Ground Analysis
scope: /Users/Prabhu/Development/Projects/2-snabbit-runner-app ONLY (Flutter/Dart side). Native `safety_shield` plugin is a git dependency (v1.0.0) and OUT of scope.
method: 4 parallel deep-read agents, evidence = file:line. Read-only. Branch feat/kavach-kmp-with-ai-skills.
produced: 2026-07-10
status: as-implemented snapshot (facts, not recommendations)
---

# Shield Backend Integration — Ground Analysis

Records the entire ground of: **SOS APIs**, **recording upload/sync API**, **encryption**, **local DB + sequencing + persistence** — endpoints, request/response, and every call site. All Dart lives under `lib/`; all paths below are repo-relative.

## 0. Fast facts

| Item | Value | Evidence |
|---|---|---|
| Base URL (active env) | `https://runner-apis.snabbit.com/` (prodEnv; dev/staging/kavach-test commented out) | `globals.dart:72,135,144-146`; `serverPath` = `remoteUrl + p` `globals.dart:228-230` |
| Auth (all app-server calls) | central `HttpService`: `Authorization: Bearer <token>` + `x-version-code` + `X-Request-ID` (fresh UUID). Token from `SecureStorageUtils.getAccessToken` (cached) | `http_service.dart:47-49,67-76,159-168` |
| Audio → S3 PUT auth | raw `Dio()`, **no** auth headers (presigned URL self-signs; app headers break S3 sig) | `shield_http.dart:91,98` |
| 401 handling | `handle403()` → also `clearAll()` on shield queue (anti cross-user leak) | `http_service.dart:107-109,443-445` |
| Recording crypto | AES-256-GCM in native plugin; RSA-OAEP-256 key-wrap in-repo (envelope) | `snabbit_shield_encryptor.dart:21-27`; `snabbit_shield_config.dart:107-109` |
| Local store | `sqflite 2.4.3` (queue) + `shared_preferences 2.5.5` (one pending SOS push). No SQLCipher | `snabbit_shield_database.dart:1,16`; `shield_sos_push_store.dart:13` |
| Module home | Whole recording pipeline lives in `lib/modules/snabbit_shield/`. SOS trigger/resolve endpoints live in `lib/services/runner_http.dart` (NOT in shield module) | see §1, §2 |

## 1. End-to-end pipeline (recording path)

```
native safety_shield plugin (records + AES-256-GCM encrypts)
  → onEncryptedAudioReady { filePath, aesSecretKey(b64), iv, authTag }   shield_event_handler.dart:76,137
  → read encrypted bytes                                                  shield_event_handler.dart:169
  → RSA-OAEP-256 wrap the AES key                                         shield_event_handler.dart:178 → encryptor:21
  → build ShieldEncryptionMetadata                                        shield_event_handler.dart:181-186
  → uploadQueue.enqueue(...)  [INSERT into SQLite snabbit_shield_uploads] shield_event_handler.dart:192 → upload_queue.dart:58
  → discardAESKey() + delete source file                                  shield_event_handler.dart:202,205
  → processQueue() [oldest-first, sequential]                             upload_queue.dart:82
       GET  presigned-url    → PUT bytes→S3 (raw Dio) → POST upload-complete(envelope)
       upload_queue.dart:152        :172                    :187
  → on success: DELETE row                                                upload_queue.dart:196-197
```

SOS path is separate (no S3), see §2A.

---

## 2A. SOS APIs

Endpoint strings defined in **`lib/services/runner_http.dart`** (`RunnerHttp` static class). `ShieldHttp` has **no** SOS endpoints (only audio + consent).

| # | Method | Path (rel. to base) | Defined | Called from | Request | Response read |
|---|--------|--------------------|---------|-------------|---------|---------------|
| E1 | POST | `api/v1/runners/me/sos/initiate` | `runner_http.dart:568-586` | `sos_flow_coordinator.dart:169` | `{source, trigger_type, job_id?}` (built `:162-166`) | `sos_id:int` (`:172`) |
| E2 | POST | `api/v1/runners/me/sos` | `runner_http.dart:548-566` | coord `:382,419,758,809`; legacy `sos.dart:76` | `{sos_id?, user_action}`; `user_action ∈ confirm/deny/dismiss`; legacy sends `{}` | `ph_no:String` (`:791`); legacy reads `allowed:bool`+`ph_no` (`sos.dart:81,96`) |
| E3 | GET | `api/v1/runners/me/sos/active` | `runner_http.dart:588-604` | `sos_flow_coordinator.dart:519` | none | `{has_active_sos:bool, sos:{status, sos_id, ph_no}}` (`:523-563`) |
| E4 | POST | `api/v1/runners/phone_call/{phoneNumber}` | `calling_service.dart:18` | `sos_active_screen.dart:216→58`; coord `:1036`; legacy `sos.dart:241` | phone in **path**, no body | `statusCode==200` only (`calling_service.dart:69`) |

- **No SOS heartbeat / no SOS-specific push registration.** SOS status is polled on demand via E3; push is generic FCM.
- **E2 is overloaded** — confirm / deny / dismiss / false-alarm / legacy-trigger all hit the same endpoint, disambiguated only by `user_action` (or its absence).

**Request payloads (quoted):**
```dart
// E1 initiate — sos_flow_coordinator.dart:162-166
{ 'source': apiSource,        // ml | accelerometer | volume_button | notification_button | manual
  'trigger_type': triggerType, // 'ml' | 'non_ml'
  if (_currentJobId() != null) 'job_id': _currentJobId() }
// E2 resolve — confirm:758 / deny:809 / dismiss(deescalate):419 / false-alarm:382
{ if (sosId != null) 'sos_id': sosId, 'user_action': 'confirm'|'deny'|'dismiss' }
// E3 active response switch — :565-572
initiated→_handleSyncInitiated · pending→_handleSyncConfirmed · denied→_handleSyncDenied
```

**Call chains (trigger → coordinator → HTTP):**

| Path | Trigger | Chain | API |
|---|---|---|---|
| A. Auto SOS | plugin `onSoSTriggered` | `shield_event_handler.dart:223` → coord `:123 initiateSosAndShowSheet` → `:169` → show alert sheet `:637` | E1 |
| B. Confirm danger | sheet primary tap | sheet `:644` → coord `:340 onSosConfirmed` → `:747 _executeSosConfirm` → `:758` → push `SOSActiveScreen` `:872` | E2 confirm |
| C. Deny / timeout | sheet secondary / RC timeout `:624` / auto-deny `:684` | coord `:357 onSosDenied` → `:800 _executeSosDeny` → `:809` | E2 deny |
| D. Call SOS team | active-screen button `:199` | `:216 _launchDialer` → `:58` → `calling_service.dart:59`; non-200 → `tel:` fallback `:77` | E4 |
| E. "I am safe" / end | active-screen `:259` | `:268 deescalateSos` → adapter `:776` → coord `:412` → `:419` | E2 dismiss |
| F. Backend push (FCM) | fg `notification_service.dart:210` / bg `main.dart:408` | → adapter `handleSOSNotification` → coord `:291 handleSosNotification` (**callApi:false**, `:326,335` — no E2; local UI sync only). Unmounted → `ShieldSosPushStore.persist` (`main.dart:422`), drained `safety_shield_adapter.dart:661` | none |
| G. Cold-start / resume reconcile | `shield_start_stop_controller.dart:111` + app-resume | coord `:511 syncActiveSosState` → `:519` | E3 |
| H. FGS notif buttons | `onNotificationAction` | `shield_event_handler.dart:433` → coord `:266`: confirm→E2, deny→E2, end_sos→E2 dismiss, escalate→E4 | E2/E4 |
| I. Legacy manual SOS | slider `sos.dart:150` / auto `:233` | `:73 SOSProvider.triggerSOS` → `:76` (empty body) — **separate older flow, bypasses coordinator+plugin** | E2 |

**SOS guards / sequencing / idempotency:**
- Reentrancy: `_sosInProgress` (`sos_flow_coordinator.dart:63,127`), `_isSyncingActiveSos` (`:76,516`), `_sosScreenPushed` (`:66,870`).
- Stale-push reject: incoming `sosId` must match `_pendingSosId` (`:302-306`).
- External-resolution race: `_sosResolvedExternally` skips stale sheet (`:244-247`).
- **No HTTP retry/backoff on E1/E2/E3** — on error: log to Coralogix, return null (`runner_http.dart:559-565`). No idempotency key (`X-Request-ID` is a fresh UUID, not idempotency).

---

## 2B. Recording upload / sync API

One pipeline only. **3-step S3-presigned flow** — NOT backend multipart. `server_requests/` layer has no audio endpoints (its multipart is Aadhaar/PAN docs, unrelated).

| # | Method | Path / URL | Defined | Called | Request | Response |
|---|--------|-----------|---------|--------|---------|----------|
| U1 | GET | `{base}api/v1/audio/presigned-url` | `shield_http.dart:45` | `upload_queue.dart:152` | query `job_id:int, timestamp:int, is_sos:bool`; auth via HttpService | `PresignedUrlResponse` (`config.dart:36-46`): `presigned_url, s3_key, expires_in_seconds, max_file_size_bytes, allowed_content_types[]` |
| U2 | PUT | `{presigned_url}` (S3 host) | `shield_http.dart:99` | `upload_queue.dart:172` | **raw encrypted bytes** `Stream.fromIterable([bytes])`; `Content-Type` (from `allowed_content_types.first` else `audio/mp4`), `Content-Length`; raw Dio, no auth; 2-min timeouts | `{success, statusCode?}`, `success = 200` (`:111`) |
| U3 | POST | `{base}api/v1/audio/upload-complete` | `shield_http.dart:133` | `upload_queue.dart:187` | JSON (`:138-147`): `job_id, timestamp, s3_key, is_sos, encryption{...}, duration_seconds, file_extension:"m4a"(hardcoded), is_compressed` | `UploadConfirmResponse` (`config.dart:68-78`): `recording_id, booking_id, timestamp, status, expires_at?, is_sos, is_encrypted` |
| U4 | POST | `{base}api/v1/runners/me/safety-shield/consent` | `shield_http.dart:186` | consent flow (not upload) | `{consent:true, consent_version:"1.0"}` | raw `Response?` (unmodeled) |

`encryption` object in U3 = `ShieldEncryptionMetadata.toApiJson()` (`config.dart:103-110`): `encrypted_key, iv, auth_tag` (b64) + hardcoded `algorithm:"AES-256-GCM", key_wrap_algorithm:"RSA-OAEP-256", key_version:"v1"`.

- **No chunked/multipart, no separate sync/flush/ack** — U3 (confirm) IS the ack.
- **Duplicate = HTTP 409** treated as success on U1 (`upload_queue.dart:158-161`) and U3 (`:196`) → row deleted.

**Upload trigger:** `EncryptedAudioEvent` → `_handleEncryptedAudio` (`shield_event_handler.dart:137`) snapshots `jobId` pre-await (`:144`), reads bytes (`:169`), wraps key (`:178`), builds metadata (`:181`), duration RC-driven (SOS 10s / manual 5s / default 5s, `:439-450`), `enqueue()` (`:192`). If `uploadQueue==null` or `jobId==null` → drop with `shield_clip_dropped_no_job` + analytics (`:145-160`).

**Queue mechanics** (`snabbit_shield_upload_queue.dart`):

| Aspect | Behavior | Evidence |
|---|---|---|
| Enqueue | INSERT bytes+metadata → enforce cap → `unawaited(processQueue)` | `:58-70` |
| Ordering | `WHERE next_attempt_at <= now ORDER BY created_at ASC` (oldest-first, no LIMIT) | `:96-101` |
| Concurrency | single-flight `_processing` bool; mid-run call sets `_pendingRetrigger`, `finally` re-triggers once; rows processed sequentially | `:17,83-91,104,227-230` |
| Retry/backoff | `_maxRetries=5`; exp backoff `5000·2^(n-1)` → 5/10/20/40s… capped 30 min | `:80,272-292` |
| Done (DELETE) | U1 409 `:160`; U3 success or 409 `:196-197`; corrupt row `:133`; max-retry `:266` | — |
| Failure | every step → `_retryOrDrop`; corrupt row parsed in separate try (no head-of-line block) | `:116-147,165,181,207,219,242-270` |
| Network-aware | flush on `start()`; trigger only on none→connected transition | `:30-44` |
| Cap (FR-22) | purge `created_at` older than 7d, then cap 20 pending; evict `is_sos DESC, created_at DESC` (SOS survives, oldest normal dropped); id-only fetch avoids BLOB load | `:24-25,299-329` |
| Logout (FR-23) | `clearAll()` truncates table; from `handle403()` + `getting_started.dart:150` | `:332-334`; `http_service.dart:443-445` |

---

## 2C. Encryption

**Envelope / hybrid scheme.** This repo does the **client half only**; no decrypt path exists in-app.

| Layer | Where | Algorithm | Evidence |
|---|---|---|---|
| Payload (audio bytes) | native plugin (out of scope) | AES-256-GCM | declared `config.dart:107`; bytes arrive pre-encrypted `shield_event_handler.dart:169` |
| Key wrap (AES key) | THIS repo (Dart) | RSA-2048 OAEP / SHA-256 | `snabbit_shield_encryptor.dart:21-27`; declared `config.dart:108` |

The single crypto op:
```dart
// snabbit_shield_encryptor.dart:21-27
String wrapAesKey(String aesSecretKeyBase64) {
  final aesKeyBytes = base64.decode(aesSecretKeyBase64);
  final oaep = OAEPEncoding.withSHA256(RSAEngine())
    ..init(true, PublicKeyParameter<RSAPublicKey>(_publicKey));
  return base64.encode(oaep.process(Uint8List.fromList(aesKeyBytes)));
}
```
- Libs: `pointycastle 4.0.0` (RSA+OAEP), `asn1lib 1.6.5` (SPKI PEM parse). Verified in `pubspec.lock`.
- **RSA public key = bundled asset** `assets/keys/shield_public_key.pem` (2048-bit SPKI), loaded via `rootBundle.loadString` (`safety_shield_adapter.dart:195-197`). NOT fetched from backend, NOT device-generated, NOT in Keystore. **No key-exchange endpoint exists.**
- AES key disposal: `discardAESKey()` after wrap+enqueue (`shield_event_handler.dart:202`).
- IV / authTag: passthrough from plugin (`:183-185`) — not generated here; GCM IV-uniqueness unverifiable in-scope.

**What's encrypted where:**

| Data | Encrypted | By / where |
|---|---|---|
| audio bytes | AES-256-GCM | plugin, before Dart sees file |
| AES data key | RSA-OAEP wrapped | this repo, before persist (`shield_event_handler.dart:178`) |
| IV, authTag | no (nonce/integrity) | passthrough |
| DB BLOB `encrypted_audio_bytes` | already-encrypted bytes stored as-is; **SQLite itself plaintext** (no SQLCipher). Wrapped key+IV+authTag in cleartext `encryption_metadata_json` | `snabbit_shield_upload_queue.dart:62` |
| S3 object | encrypted bytes over HTTPS presigned PUT | `shield_http.dart:99-110` |

**Server contract (envelope sent on U3):**
```json
{ "encrypted_key": "<b64 RSA-OAEP-wrapped AES key>",
  "iv": "<b64>", "auth_tag": "<b64>",
  "algorithm": "AES-256-GCM", "key_wrap_algorithm": "RSA-OAEP-256", "key_version": "v1" }
```
Backend holds RSA private key → unwraps `encrypted_key` → AES-256-GCM-decrypts the S3 object with `iv`+`auth_tag`.

---

## 2D. Local DB, sequencing, persistence

Two stores (+ an unrelated IoT `iot_data.db`, out of scope).

| Store | Tech | Holds | Evidence |
|---|---|---|---|
| Upload queue | `sqflite 2.4.3`, DB `snabbit_shield.db` v5, table `snabbit_shield_uploads` | encrypted clip + envelope metadata + retry state | `snabbit_shield_database.dart:15,52-66` |
| SOS push buffer | `shared_preferences`, key `pending_shield_sos_action` | ONE pending push `{action:String, sos_id:int}` | `shield_sos_push_store.dart:13,18` |

`ShieldDatabase` is a **hand-rolled singleton**, NOT via the app's `IDatabaseInterface`/`DatabaseFactory`; the `SqliteDatabase._boolColumns` auto-convert does NOT apply — `is_sos` is raw INTEGER 0/1 (`snabbit_shield_database.dart:4-10`; `upload_queue.dart:64,126`).

**Schema** (`snabbit_shield_database.dart:53-66`):
```sql
CREATE TABLE snabbit_shield_uploads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id INTEGER NOT NULL, timestamp INTEGER NOT NULL,
  encrypted_audio_bytes BLOB NOT NULL, encryption_metadata_json TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL, is_sos INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, retry_count INTEGER NOT NULL DEFAULT 0,
  next_attempt_at INTEGER NOT NULL DEFAULT 0 )
-- idx_shield_created(created_at); idx_shield_next_attempt(next_attempt_at)  :67-74
```
**Migrations** (`:28-50`): `<3` DROP+recreate (v1/v2 incompatible, explicit data loss); `<4` ADD `retry_count`,`next_attempt_at` in-place (preserve pending); `<5` ADD `idx_shield_next_attempt` (fix dequeue full-scan).

**Sequencing / dequeue:**
- Order key = `created_at` epoch-ms at enqueue (oldest-first). `id` AUTOINCREMENT exists but not used for ordering.
- Dequeue: `WHERE next_attempt_at <= now ORDER BY created_at ASC` (all eligible, sequential `for` loop) `:96-104`.
- **No explicit status column** — implicit state machine: `pending` = eligible row exists; `in-flight` = in-loop (in-memory only, not persisted → crash re-uploads = at-least-once); `backing-off` = `next_attempt_at > now`; `done` = row DELETED.
- Concurrency: in-process `_processing` guard only; **no DB transactions, no WAL/busyTimeout, not isolate-safe**.

**Write/read call-site map:**

| Op | SQL | Site |
|---|---|---|
| INSERT | insert | `upload_queue.enqueue :58` ← `shield_event_handler.dart:192` |
| SELECT eligible | query | `processQueue :96` |
| UPDATE retry/backoff | update | `_rescheduleRow :274` |
| DELETE success/409 | delete id | `:160,196-197` |
| DELETE max-retry/corrupt | delete id | `_retryOrDrop :266`; corrupt `:133` |
| DELETE age purge / cap | delete | `_enforceQueueCap :303,322` |
| DELETE all (logout) | delete no-where | `clearAll :333` |

`processQueue` triggers: connectivity regained `:38`, `start()` `:43`, post-enqueue `:69`, self-retrigger `:229`.

**Restart recovery:** boot `main.dart:604-611` reopens DB, builds queue, `start()` → immediate `processQueue("upload_queue_start")` to flush pre-restart rows. Lazy fallback re-init in `shield_start_stop_controller.dart:296-301`. Delivery = **at-least-once** (backend 409 absorbs dup).

**SOS push buffer:** persist `main.dart:422`, `notification_service.dart:221`; drain (read-and-clear, parse-before-remove) `safety_shield_adapter.dart:662`. Single key → a 2nd push before drain **silently overwrites** the first (acceptable per "backend is source of truth", `shield_sos_push_store.dart:9-11`).

---

## 3. Consolidated gaps / risks (evidence-backed, observations only — not fixes)

| # | Concern | Detail | Evidence |
|---|---|---|---|
| G1 | SOS | **Legacy `SOSProvider.triggerSOS` is a live parallel SOS path** bypassing coordinator+plugin; posts E2 with empty body, depends on server `allowed` flag unused elsewhere. Two divergent contracts on one endpoint | `sos.dart:73-117` |
| G2 | SOS | **No retry/backoff on E1/E2/E3.** Transient failure on E1 initiate → SOS never registered backend-side (`sos_id==null`); only E3 reconcile recovers, and only on job-start/resume | `runner_http.dart:559-565`; coord `:511` |
| G3 | SOS | `sos_id` sent only `if != null` on every E2 — if initiate failed, confirm/deny/dismiss go up with no id; backend must infer by runner identity | coord `:759,810,420,383` |
| G4 | SOS | No server idempotency key; dedup relies solely on local guards | `http_service.dart:76` |
| G5 | Enc | **RSA public key is a static bundled asset, no rotation**; `key_version` hardcoded `v1`; rotating key = app release | `safety_shield_adapter.dart:195`; `config.dart:109` |
| G6 | Enc | **Stale doc comment** — `snabbit_shield_encryptor.dart:12` claims PEM "fetched from backend"; actually loaded from assets | encryptor:12 vs adapter:196 |
| G7 | Enc | Encryptor-load failure is **non-fatal → clip silently dropped** (fail-closed, but data-loss: safety clip lost, not uploaded plaintext) | adapter `:199-208`; handler `:172-177` |
| G8 | Enc/DB | Local SQLite **not encrypted at rest** (no SQLCipher); wrapped key+IV+authTag stored plaintext. Safe only because bytes are pre-encrypted + private key stays server-side | `snabbit_shield_database.dart:16-21`; `upload_queue.dart:62` |
| G9 | Upload | Hardcoded `file_extension:'m4a'`, `algorithm/key_wrap/key_version`, content-type fallback `audio/mp4` — silent mismatch if plugin codec changes | `shield_http.dart:145`; `config.dart:107-109`; `upload_queue.dart:237` |
| G10 | Upload | **`isPermanentFailure` (400/409) helper defined but unused** — a 400 gets 5 wasted retries+backoff (only 409 short-circuits) | `config.dart:14-15` |
| G11 | Upload | `max_file_size_bytes` and `expires_in_seconds` parsed but never enforced client-side — oversize/expiry discovered only via S3 error | `config.dart:24-25,40-41` |
| G12 | DB | **Unbounded per-pass memory** — dequeue has no LIMIT, loads all eligible rows incl. full BLOBs at once (up to 20 multi-MB clips) | `upload_queue.dart:96-101` |
| G13 | DB | **Cross-isolate unsafe** — `_processing` guard in-memory per instance; `ShieldDatabase` per-isolate singleton; no shared lock / WAL / busyTimeout → possible double-process or `database is locked` in background isolate | `upload_queue.dart:17`; `database.dart:5-10,16-21` |
| G14 | DB | No transactions/atomicity; no persisted in-flight status → crash mid-upload re-uploads (mitigated by 409, wastes bandwidth) | `database.dart:77-103`; §2D |
| G15 | DB | 7-day age purge + cap run **only on enqueue** — if enqueues stop, stale rows can outlive 7 days | `upload_queue.dart:67,299-303` |
| G16 | Shared | `postDocs` passes method tear-off `currentVersionCode` instead of `await currentVersionCode()` — **not on shield path** (shield uses get/post, correct), flagged as in-scope shared-layer bug | `http_service.dart:339` vs `:71,163` |

**No `TODO`/`FIXME`/`UnimplementedError`/hardcoded-symmetric-key markers** found in the shield or security dirs — pipeline is fully wired end to end. All gaps above are design/wiring observations.

## 4. Key file index

| Concern | Files |
|---|---|
| SOS | `services/runner_http.dart` (E1-E3), `services/calling_service.dart` (E4), `modules/snabbit_shield/sos_flow_coordinator.dart`, `shield_event_handler.dart`, `shield_start_stop_controller.dart`, `shield_sos_push_store.dart`, `ui/sos_active_screen.dart`, `widgets/sos.dart` (legacy) |
| Upload | `modules/snabbit_shield/snabbit_shield_upload_queue.dart`, `shield_http.dart`, `snabbit_shield_config.dart`, `safety_shield_adapter.dart` |
| Encryption | `modules/snabbit_shield/snabbit_shield_encryptor.dart`, `snabbit_shield_config.dart`, `assets/keys/shield_public_key.pem` |
| Local DB | `modules/snabbit_shield/snabbit_shield_database.dart`, `snabbit_shield_upload_queue.dart`, `shield_sos_push_store.dart` |
| Shared infra | `globals.dart` (base URL, `serverPath`, `shieldUploadQueue` handle), `services/http_service.dart` (auth), `main.dart:604-622` (boot init), `services/secure_storage_service.dart` (token) |
