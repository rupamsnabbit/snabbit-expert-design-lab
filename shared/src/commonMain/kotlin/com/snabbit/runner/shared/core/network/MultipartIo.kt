package com.snabbit.runner.shared.core.network

/**
 * Reads the file at [path] into a byte array. Used by [SnabbitHttpClientImpl]
 * to materialize the bytes referenced by [FormPart.File] before handing them
 * to Ktor's multipart engine.
 *
 * `suspend`, and each actual hops to an IO-capable dispatcher itself: the
 * shift-login caller chain runs on Main (`rememberCoroutineScope`), and Ktor
 * builds the request body on the *caller's* dispatcher — so without the hop a
 * multi-MB selfie read blocks the UI thread. `Dispatchers.IO` doesn't exist in
 * commonMain, hence the choice lives per-platform.
 *
 * Throws if the file is missing or unreadable — the caller wraps the
 * exception into [NetworkError.TransportError] via the normal catch path.
 */
internal expect suspend fun readFileBytes(path: String): ByteArray
