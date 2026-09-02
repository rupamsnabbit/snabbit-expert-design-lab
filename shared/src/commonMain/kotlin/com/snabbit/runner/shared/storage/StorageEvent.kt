package com.snabbit.runner.shared.storage

/**
 * Structured log-event names emitted on every storage failure path.
 * Grep for these in Crashlytics / Coralogix to monitor storage health.
 */
object StorageEvent {
    const val STORAGE_READ_FAILED = "STORAGE_READ_FAILED"
    const val STORAGE_WRITE_FAILED = "STORAGE_WRITE_FAILED"
    const val STORAGE_KEYSTORE_ERROR = "STORAGE_KEYSTORE_ERROR"
    const val STORAGE_CORRUPTED_PAYLOAD = "STORAGE_CORRUPTED_PAYLOAD"
    const val STORAGE_TYPE_MISMATCH = "STORAGE_TYPE_MISMATCH"
}
