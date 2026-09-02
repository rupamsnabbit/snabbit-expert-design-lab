package com.snabbit.runner.shared.features.blocklist.domain.model

/**
 * A customer the runner has blocked, as shown on the block list. Migrated from the Flutter
 * `BlockedCustomer` (`lib/widgets/job_in_progress/rating_block_handler.dart`) — flattened from a
 * nested `api/v1/runners/me/preferences` entry.
 *
 * @param customerId the customer's id (`customer.id`) — the key used to unblock.
 * @param name the display name (`customer.user.name`); null when the API omits it.
 * @param address the booking address under the name (`job.booking.address_str`); null when absent.
 * @param jobId the associated job (`job.id`), echoed back on unblock to match the Flutter payload;
 *   null when absent.
 */
data class BlockedCustomer(
    val customerId: Int,
    val name: String? = null,
    val address: String? = null,
    val jobId: Int? = null,
)
