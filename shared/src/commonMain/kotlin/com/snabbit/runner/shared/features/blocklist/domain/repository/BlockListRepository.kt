package com.snabbit.runner.shared.features.blocklist.domain.repository
import com.snabbit.runner.shared.features.blocklist.domain.model.BlockedCustomer

/**
 * Network seam for the Block list — KMP-native via `SnabbitHttpClient` (same pattern as
 * [com.snabbit.runner.shared.features.language.domain.LanguageDataSource]):
 *  - [getBlockedCustomers] → `GET api/v1/runners/me/preferences`
 *  - [unblock]             → `PUT api/v1/runners/me/preferences` (clears `pref_type`)
 *
 * `suspend` + main-safe; implementations throw on HTTP/transport failure and the caller surfaces it.
 * In tests, use FakeBlockListRepository.
 */
interface BlockListRepository {
    /** The runner's currently-blocked customers. Throws on failure. */
    suspend fun getBlockedCustomers(): List<BlockedCustomer>

    /**
     * Unblocks [customerId] by clearing its preference (`pref_type: null`), mirroring the Flutter
     * `unblockCustomer`. [jobId] is echoed back when known (from the blocked entry). Throws on failure.
     */
    suspend fun unblock(customerId: Int, jobId: Int?)

    /**
     * Blocks [customerId] (`pref_type: "BLACKLISTED"`), mirroring the Flutter `blockCustomer`. Throws
     * [MaxCustomersBlockedException] when the runner is already at the block cap (server
     * `MAX_CUSTOMERS_BLOCKED`), or [BlockListNetworkException] on any other HTTP/transport failure.
     * [jobId] is echoed when known.
     */
    suspend fun block(customerId: Int, jobId: Int?)
}
