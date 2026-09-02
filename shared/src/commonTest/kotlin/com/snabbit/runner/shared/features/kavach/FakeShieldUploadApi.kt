package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.features.kavach.shield.data.upload.PresignedUrl
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldEncryptionMetadata
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldUploadApi
import com.snabbit.runner.shared.features.kavach.shield.data.upload.UploadOutcome

/** Deterministic [ShieldUploadApi] fake — configurable per-step outcomes + call recorders. */
class FakeShieldUploadApi : ShieldUploadApi {
    var presignedResult: UploadOutcome<PresignedUrl> =
        UploadOutcome.Ok(PresignedUrl(url = "https://s3/put", s3Key = "s3key", maxFileSizeBytes = 1_000_000, contentType = "audio/mp4"))
    var s3Result: Boolean = true
    var confirmResult: UploadOutcome<Unit> = UploadOutcome.Ok(Unit)

    var presignedCalls = 0
    var s3Calls = 0
    var confirmCalls = 0
    var lastConfirmS3Key: String? = null
    var lastConfirmIsSos: Boolean? = null
    var lastConfirmDurationSeconds: Int? = null
    var lastPutBytes: ByteArray? = null
    /** The job the clip was attributed to — the ECPO-986 assertion point. */
    var lastPresignedJobId: Int? = null

    override suspend fun getPresignedUrl(jobId: Int, timestamp: Long, isSos: Boolean): UploadOutcome<PresignedUrl> {
        presignedCalls++
        lastPresignedJobId = jobId
        return presignedResult
    }

    override suspend fun uploadToS3(url: String, bytes: ByteArray, contentType: String): Boolean {
        s3Calls++
        lastPutBytes = bytes
        return s3Result
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
        confirmCalls++
        lastConfirmS3Key = s3Key
        lastConfirmIsSos = isSos
        lastConfirmDurationSeconds = durationSeconds
        return confirmResult
    }
}
