package com.snabbit.runner.shared.features.kavach.shield.data.upload

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.kavach.shared.data.ApiPreflight
import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Production [ShieldUploadApi]. Presigned (U1) + confirm (U3) go through [SnabbitHttpClient]
 * (auth/tracing via interceptors); the S3 PUT (U2) uses a bare [s3Client] — raw bytes, NO auth
 * headers (the presigned URL carries its own signature). Best-effort + HTTP 409 → [UploadOutcome.Conflict]
 * (already uploaded), 1:1 with the Flutter upload queue.
 */
class ShieldUploadApiImpl(
    private val httpClient: SnabbitHttpClient,
    private val s3Client: HttpClient,
    private val crashReporter: CrashReporter,
    private val preflight: ApiPreflight,
) : ShieldUploadApi {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true   // envelope wants algorithm/key_wrap_algorithm on the wire
    }

    override suspend fun getPresignedUrl(jobId: Int, timestamp: Long, isSos: Boolean): UploadOutcome<PresignedUrl> {
        // Skipped (not Error) → the row keeps its retry budget; nothing was sent.
        if (!preflight.allows("shield_presigned")) return UploadOutcome.Skipped
        val req = SnabbitRequest(
            method = HttpMethod.Get,
            url = "/$PRESIGNED_PATH",
            query = mapOf("job_id" to jobId.toString(), "timestamp" to timestamp.toString(), "is_sos" to isSos.toString()),
        )
        return when (val r = httpClient.execute(req)) {
            is Result.Ok -> runCatching {
                val dto = json.decodeFromString<PresignedResponse>(r.value.body)
                UploadOutcome.Ok(
                    PresignedUrl(
                        url = dto.presignedUrl,
                        s3Key = dto.s3Key,
                        maxFileSizeBytes = dto.maxFileSizeBytes,
                        contentType = dto.allowedContentTypes.firstOrNull() ?: DEFAULT_CONTENT_TYPE,
                    ),
                )
            }.getOrElse { e ->
                // Report the decode failure — a contract-broken presigned payload was otherwise invisible
                // until the row exhausted retries and surfaced as generic max_retries_exceeded.
                crashReporter.report(ShieldUploadException(e), mapOf("op" to "presigned_parse"))
                UploadOutcome.Error
            }
            is Result.Err -> outcome("presigned", r.error)
        }
    }

    override suspend fun uploadToS3(url: String, bytes: ByteArray, contentType: String): Boolean =
        runCatching {
            s3Client.put(url) {
                header(HttpHeaders.ContentType, contentType)
                setBody(bytes)
            }.status.value == 200
        }.getOrElse { e ->
            if (e is CancellationException) throw e
            crashReporter.report(ShieldUploadException(e), mapOf("op" to "s3Put"))
            false
        }

    override suspend fun confirmUpload(
        jobId: Int,
        timestamp: Long,
        s3Key: String,
        isSos: Boolean,
        encryption: ShieldEncryptionMetadata,
        durationSeconds: Int,
        isCompressed: Boolean,
    ): UploadOutcome<Unit> {
        if (!preflight.allows("shield_upload_confirm")) return UploadOutcome.Skipped
        val body = json.encodeToString(
            UploadCompleteBody(
                jobId = jobId,
                timestamp = timestamp,
                s3Key = s3Key,
                isSos = isSos,
                encryption = EncryptionDto(encryption.encryptedKey, encryption.iv, encryption.authTag, keyVersion = encryption.keyVersion),
                durationSeconds = durationSeconds,
                isCompressed = isCompressed,
            ),
        )
        val req = SnabbitRequest(method = HttpMethod.Post, url = "/$UPLOAD_COMPLETE_PATH", body = body)
        return when (val r = httpClient.execute(req)) {
            is Result.Ok -> UploadOutcome.Ok(Unit)
            is Result.Err -> outcome("confirm", r.error)
        }
    }

    /** 409 → already uploaded (done); any other transport/HTTP failure → retryable Error. */
    private fun <T> outcome(op: String, error: NetworkError): UploadOutcome<T> {
        if (error is NetworkError.HttpError) {
            if (error.statusCode == HTTP_CONFLICT) return UploadOutcome.Conflict
            crashReporter.report(ShieldUploadException(error), mapOf("op" to op, "status" to error.statusCode.toString()))
        }
        return UploadOutcome.Error
    }

    private companion object {
        const val PRESIGNED_PATH = "api/v1/audio/presigned-url"
        const val UPLOAD_COMPLETE_PATH = "api/v1/audio/upload-complete"
        const val DEFAULT_CONTENT_TYPE = "audio/mp4"
        const val HTTP_CONFLICT = 409
    }
}

@Serializable
private data class PresignedResponse(
    @SerialName("presigned_url") val presignedUrl: String,
    @SerialName("s3_key") val s3Key: String,
    @SerialName("max_file_size_bytes") val maxFileSizeBytes: Long = 0,
    @SerialName("allowed_content_types") val allowedContentTypes: List<String> = emptyList(),
)

@Serializable
private data class UploadCompleteBody(
    @SerialName("job_id") val jobId: Int,
    val timestamp: Long,
    @SerialName("s3_key") val s3Key: String,
    @SerialName("is_sos") val isSos: Boolean,
    val encryption: EncryptionDto,
    @SerialName("duration_seconds") val durationSeconds: Int,
    @SerialName("file_extension") val fileExtension: String = "m4a",
    @SerialName("is_compressed") val isCompressed: Boolean,
)

@Serializable
private data class EncryptionDto(
    @SerialName("encrypted_key") val encryptedKey: String,
    val iv: String,
    @SerialName("auth_tag") val authTag: String,
    val algorithm: String = "AES-256-GCM",
    @SerialName("key_wrap_algorithm") val keyWrapAlgorithm: String = "RSA-OAEP-256",
    @SerialName("key_version") val keyVersion: String = "v1",
)

/** Typed wrapper for a failed upload step — cause preserved for logging. */
class ShieldUploadException(cause: Throwable) : Exception("Shield upload step failed", cause) {
    constructor(error: NetworkError) : this(RuntimeException(error.toString()))
}
