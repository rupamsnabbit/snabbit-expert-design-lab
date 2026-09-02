package com.snabbit.runner.shared.features.blocklist.data.remote
import com.snabbit.runner.shared.features.blocklist.domain.model.BlockedCustomer
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository

/**
 * Test [BlockListRepository]. Set [error] to make [getBlockedCustomers] throw, or [unblockError] to
 * make [unblock] throw. Records unblock calls (customerId + jobId) for assertions.
 */
class FakeBlockListRepository(
    var customers: List<BlockedCustomer> = sampleBlockedCustomers,
    var error: Throwable? = null,
    var unblockError: Throwable? = null,
    var blockError: Throwable? = null,
) : BlockListRepository {

    var getBlockedCustomersCallCount = 0
        private set

    /** (customerId, jobId) passed to [unblock], in order. */
    val unblockCalls = mutableListOf<Pair<Int, Int?>>()

    override suspend fun getBlockedCustomers(): List<BlockedCustomer> {
        getBlockedCustomersCallCount++
        error?.let { throw it }
        return customers
    }

    override suspend fun unblock(customerId: Int, jobId: Int?) {
        unblockError?.let { throw it }
        unblockCalls.add(customerId to jobId)
    }

    /** (customerId, jobId) passed to [block], in order. */
    val blockCalls = mutableListOf<Pair<Int, Int?>>()

    override suspend fun block(customerId: Int, jobId: Int?) {
        blockError?.let { throw it }
        blockCalls.add(customerId to jobId)
    }

    companion object {
        val sampleBlockedCustomers = listOf(
            BlockedCustomer(customerId = 1, name = "Sreelakshmi Raj", address = "HAL Old Airport Rd", jobId = 101),
            BlockedCustomer(customerId = 2, name = "Prashant K", address = "HAL Old Airport Rd", jobId = 102),
            BlockedCustomer(customerId = 3, name = "Neha Yadav", address = "HAL Old Airport Rd", jobId = 103),
        )
    }
}
