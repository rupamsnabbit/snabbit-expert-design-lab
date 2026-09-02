package com.snabbit.runner.shared.features.home.suspended.data.remote.dto

import kotlinx.serialization.Serializable

/**
 * Body shape of a `400` from `POST api/v1/runners/me/unsuspend` — the backend
 * refused reactivation. Dart reads `data['status']` and `data['message']`
 * (`runner_suspended.dart` — the `status_code == 400` branch). Both fields are
 * optional on the wire; the repository substitutes `"unknown"` when absent.
 */
@Serializable
internal data class UnsuspendDeniedDto(
    val status: String? = null,
    val message: String? = null,
)

/**
 * Body shape of a non-400 failure from `POST api/v1/runners/me/unsuspend`. Dart
 * surfaces `data['message'] ?? data['detail']` when present (`runner_suspended.dart`
 * — the `else` branch), falling back to the generic string. Both optional.
 */
@Serializable
internal data class UnsuspendFailedDto(
    val message: String? = null,
    val detail: String? = null,
)
