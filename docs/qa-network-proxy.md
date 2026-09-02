# QA network debugging with Charles / Proxyman / mitmproxy

Debug (QA) builds of the runner app can be inspected end-to-end with an HTTPS
proxy — you can see, decrypt, and edit every API call. **This works on debug
builds only; release builds are completely unaffected** (no user-certificate
trust, no proxy override).

## What's covered

| Traffic | How it's routed | Enabled by |
|---|---|---|
| **Dart / Dio** (`runners/me`, login, `current_state` poll, most APIs) | via the device Wi-Fi proxy | `QaProxyHttpOverrides` (debug-only, reads the Wi-Fi proxy natively) |
| **KMP / Ktor** (`CurrentStateReconciler`, KMP `current_state`) | OkHttp uses the Wi-Fi proxy automatically | user-CA trust in the debug `network_security_config` |
| **WebViews / native** | Wi-Fi proxy | same debug `network_security_config` |
| **MQTT realtime** (port 1883, non-TLS) | *not* HTTPS — see note below | — |

You only ever set the proxy in **one place** (the device Wi-Fi proxy); both the
Dart and KMP sides pick it up.

## Setup — Charles (most common)

1. **Charles → Proxy → SSL Proxying Settings** → enable *SSL Proxying* → add
   locations: `*.snabbit.net:443`, `*.snabbit.com:443` (or just `*:*`).
2. Find your machine's **LAN IP** (Charles → Help → Local IP Address) and the
   proxy **port** (Charles → Proxy → Proxy Settings, default **8888**). Phone and
   machine must be on the **same network**.
3. On the phone: **Settings → Wi-Fi → (your network) → Advanced/Modify → Proxy →
   Manual** → Host = your IP, Port = 8888. Save.
4. **Install the Charles root certificate** on the phone: open the phone browser
   to **`chls.pro/ssl`** → it downloads a cert → install it as a **CA certificate**
   (Settings → Security → *Encryption & credentials* → *Install a certificate* →
   *CA certificate* → pick the downloaded file). On Samsung: Settings → Security
   and privacy → More security settings → Encryption & credentials.
   *(Alt: Charles → Help → SSL Proxying → Install Charles Root Certificate on a
   Mobile Device.)*
5. **Relaunch the app.** The Dart proxy is read at startup, so set the Wi-Fi proxy
   **before** launching (and relaunch after any proxy change).

All API traffic — Dart and KMP — now appears in Charles, decrypted.

## Proxyman / mitmproxy

Same idea: set the device Wi-Fi proxy to the tool's host:port, install its root
CA on the device as a *CA certificate*, then relaunch.
- **Proxyman**: Certificate → Install Certificate on iOS/Android device → follow
  the on-device steps.
- **mitmproxy**: browse to **`mitm.it`** on the device → install the Android CA.

## Notes & gotchas

- **Set the Wi-Fi proxy before launching.** The Dart side reads it once at startup;
  changing the proxy needs an app relaunch. (KMP/OkHttp picks up changes live.)
- **MQTT is not HTTPS.** The realtime channel is a raw MQTT/TCP connection on port
  1883 (TLS off in staging), so Charles won't show it as HTTP. To debug realtime,
  use **Profile → footer → `Realtime - …`** status (debug builds) and the
  `RealtimeStateEngine` logcat (`recv MQTT` / `applied … source=MQTT`).
- **Quick, no-proxy option:** debug builds also ship **Chucker**, an in-app network
  inspector — shake / tap the Chucker notification to see recent calls without a
  proxy. Charles is for editing / breakpoints / rewrite rules.
- **No production risk:** the user-CA trust lives in `android/app/src/debug/res/xml/`
  (never in release), and `QaProxyHttpOverrides` is `kDebugMode`-gated **and** a
  no-op unless a proxy is set — so an un-proxied debug build still validates certs
  normally.

## Troubleshooting

- **No Dart traffic in Charles** → you changed the proxy without relaunching, or the
  proxy wasn't set at launch. Set Wi-Fi proxy → force-stop → relaunch.
- **SSL handshake / "unknown CA" errors** → the Charles root cert isn't installed as
  a *CA certificate* on the device (a *VPN & app* user cert is not enough for the
  system store; use the CA-certificate path above).
- **Only KMP calls show, not Dart** (or vice-versa) → KMP needs the CA installed
  (network_security_config); Dart needs the Wi-Fi proxy set at launch. Do both.
- **Nothing at all** → phone and proxy machine aren't on the same network, or a
  firewall blocks the proxy port.
