package com.snabbit.runner.shared.features.blocklist.data.repository

import com.snabbit.runner.shared.features.blocklist.domain.model.BlockedCustomer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/* ── Wire DTOs (mirror lib/services/job_http.dart + Flutter BlockedCustomer.fromJson) ────── */

@Serializable
internal data class BlockedPreferenceDto(
    @SerialName("customer") val customer: CustomerDto? = null,
    @SerialName("job") val job: JobDto? = null,
)

@Serializable
internal data class CustomerDto(
    @SerialName("id") val id: Int? = null,
    @SerialName("user") val user: UserDto? = null,
)

@Serializable
internal data class UserDto(
    @SerialName("name") val name: String? = null,
)

@Serializable
internal data class JobDto(
    @SerialName("id") val id: Int? = null,
    @SerialName("booking") val booking: BookingDto? = null,
)

@Serializable
internal data class BookingDto(
    @SerialName("address_str") val addressStr: String? = null,
)

/* ── Error envelope (mirror lib/models/errors: `{ errors: [{ code, ... }] }`) ──────────── */

@Serializable
internal data class ErrorEnvelopeDto(
    @SerialName("errors") val errors: List<ErrorItemDto>? = null,
)

@Serializable
internal data class ErrorItemDto(
    @SerialName("code") val code: String? = null,
)

/**
 * Flattens a preference entry to the domain model. Drops entries without a customer id (the unblock
 * key), matching the Flutter `fromJson` which requires `customer.id`.
 */
internal fun BlockedPreferenceDto.toDomain(): BlockedCustomer? {
    val id = customer?.id ?: return null
    return BlockedCustomer(
        customerId = id,
        name = customer.user?.name,
        address = job?.booking?.addressStr,
        jobId = job?.id,
    )
}
