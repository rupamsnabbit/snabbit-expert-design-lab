package com.snabbit.runner.shared.features.job.data.contact

/**
 * Masked-call seam — asks the backend to place a proxy call connecting the runner and customer,
 * mirroring the Flutter `CallingService`. `suspend` + main-safe; in tests use FakeCallingDataSource.
 */
interface CallingDataSource {
    /**
     * `POST api/v1/runners/phone_call/{phoneNumber}` — requests the masked call. Returns `true` when
     * the backend accepted it (2xx), `false` otherwise. Never throws — a transport/HTTP failure reads
     * as `false` so the caller can fall back to the dialer.
     */
    suspend fun initiateCall(phoneNumber: String): Boolean
}
