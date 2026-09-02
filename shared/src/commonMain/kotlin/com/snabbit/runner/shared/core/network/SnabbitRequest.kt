package com.snabbit.runner.shared.core.network

import io.ktor.http.HttpMethod

/** Which pushed base a relative [SnabbitRequest.url] resolves against. */
enum class SnabbitBaseUrl {
    /** `NetworkConfig.baseUrl` — the runner API. Almost everything. */
    Api,

    /** `NetworkConfig.onboardingUrl` — the onboarding service (PAN, KYC). */
    Onboarding,
}

/**
 * Fully describes one outgoing HTTP call (§2.1). Repositories build a
 * `SnabbitRequest` and hand it to `SnabbitHttpClient.execute()` — the
 * client adds auth + tracing headers from the interceptor chain.
 *
 * **[url] should be a RELATIVE path** (`"/api/v1/runners/me"`); `execute()`
 * resolves it against [base] using the config it already awaits behind its
 * bounded cold-start gate.
 *
 * Callers must NOT resolve the base themselves. `awaitNetworkConfig()` is
 * `NetworkConfigStore.awaitReady()` — a `first { … }` that suspends **forever**
 * until Dart pushes a non-blank baseUrl. `execute()` wraps its own call in
 * `withTimeoutOrNull` precisely for that reason, but a caller resolving the base
 * *before* calling `execute()` runs outside that guard and can hang unbounded
 * (a submit on a cold/force-killed process would sit behind a non-dismissible
 * spinner forever). Making the client own resolution removes the bypass.
 *
 * An absolute `http(s)://` [url] is still honoured verbatim, for genuinely
 * external hosts.
 */
data class SnabbitRequest(
    val method: HttpMethod,
    val url: String,
    val query: Map<String, String> = emptyMap(),
    val headers: Map<String, String> = emptyMap(),
    /** JSON string for POST/PUT. Mutually exclusive with [formParts]. */
    val body: String? = null,
    /** Injected as Session-Id header when non-null. */
    val sessionId: String? = null,
    /**
     * Per-request timeout overrides, in milliseconds. **Leave null** unless this
     * one call genuinely needs a budget different from the rest of the app —
     * null means "use the Remote-Config-driven app-wide budget"
     * ([NetworkTuning]), which is what every caller in the module currently
     * wants. A non-null value opts the request out of that lever, so it can no
     * longer be tuned without a release.
     */
    val connectTimeoutMs: Long? = null,
    val receiveTimeoutMs: Long? = null,
    /**
     * Multipart parts. When non-null, the client materializes each part —
     * [FormPart.File] bytes are read from disk via `readFileBytes(path)` —
     * and sets a `multipart/form-data` body. Mutually exclusive with [body].
     */
    val formParts: List<FormPart>? = null,
    /** Which pushed base a relative [url] resolves against. Ignored when [url] is absolute. */
    val base: SnabbitBaseUrl = SnabbitBaseUrl.Api,
)

/**
 * Absolute URL for this request: [url] verbatim when it already names a host,
 * else [base] (from the client's already-awaited [NetworkConfig]) joined to it.
 * Joining normalises the slash on both sides so `".../v1"` + `"/runners"` and
 * `".../v1/"` + `"runners"` both produce one separator.
 */
internal fun SnabbitRequest.resolveUrl(config: NetworkConfig): String {
    if (url.startsWith("http://", ignoreCase = true) || url.startsWith("https://", ignoreCase = true)) {
        return url
    }
    val root = when (base) {
        SnabbitBaseUrl.Api -> config.baseUrl
        SnabbitBaseUrl.Onboarding -> config.onboardingUrl
    }.trimEnd('/')
    return "$root/${url.removePrefix("/")}"
}

/**
 * Multipart form-data part. File parts carry an absolute path the engine
 * reads from disk — file contents are NOT serialized across MethodChannel.
 */
sealed class FormPart {
    data class Field(val name: String, val value: String) : FormPart()
    data class File(
        val name: String,
        val filePath: String,
        val filename: String,
        val mimeType: String = "application/octet-stream",
    ) : FormPart()
}
