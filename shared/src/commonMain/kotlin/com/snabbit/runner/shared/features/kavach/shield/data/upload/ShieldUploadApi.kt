package com.snabbit.runner.shared.features.kavach.shield.data.upload

/**
 * The 3-step recording upload transport (Step 7). Best-effort like the rest of the flow;
 * HTTP 409 means the clip is already on the server (treat as done).
 *
 *  - [getPresignedUrl] `GET  api/v1/audio/presigned-url`
 *  - [uploadToS3]      `PUT  {presigned}` — raw encrypted bytes, NO auth headers
 *  - [confirmUpload]   `POST api/v1/audio/upload-complete` (the RSA-wrap envelope)
 */
interface ShieldUploadApi {
    suspend fun getPresignedUrl(jobId: Int, timestamp: Long, isSos: Boolean): UploadOutcome<PresignedUrl>
    suspend fun uploadToS3(url: String, bytes: ByteArray, contentType: String): Boolean
    suspend fun confirmUpload(
        jobId: Int,
        timestamp: Long,
        s3Key: String,
        isSos: Boolean,
        encryption: ShieldEncryptionMetadata,
        durationSeconds: Int,
        isCompressed: Boolean,
    ): UploadOutcome<Unit>
}

/** Outcome of a backend step: success, 409-conflict (already uploaded → done), or a retryable error. */
sealed interface UploadOutcome<out T> {
    data class Ok<T>(val value: T) : UploadOutcome<T>
    data object Conflict : UploadOutcome<Nothing>
    data object Error : UploadOutcome<Nothing>

    /**
     * Preflight declined — nothing left the device. Separate from [Error] so it can't burn the retry
     * budget; five offline drains used to delete a clip that was never sent.
     */
    data object Skipped : UploadOutcome<Nothing>
}

/** Parsed `presigned-url` response (content type = the first allowed type, else audio/mp4). */
data class PresignedUrl(
    val url: String,
    val s3Key: String,
    val maxFileSizeBytes: Long,
    val contentType: String,
)

/**
 * `encryption` sub-object of `upload-complete`: the RSA-OAEP-wrapped AES key + GCM iv/tag (all
 * base64). `algorithm` / `key_wrap_algorithm` are fixed by the scheme; the plaintext bytes were
 * AES-256-GCM encrypted by the plugin and the key RSA-wrapped app-side (Step 7.2).
 */
data class ShieldEncryptionMetadata(
    val encryptedKey: String,
    val iv: String,
    val authTag: String,
    val keyVersion: String = "v1",
)
