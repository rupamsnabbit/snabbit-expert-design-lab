package com.snabbit.runner.shared.core.location

/**
 * The outcome of any location request. A closed set so callers can `when` exhaustively.
 *
 * The five terminal reasons are deliberately distinct because callers react differently:
 * [PermissionDenied] → request permission; [ServiceDisabled] → prompt to enable GPS;
 * [PlayServicesUnavailable] → device/Play-services problem; [Failure] → transient/retryable.
 */
sealed class LocationResult {
    /** A fix was obtained. */
    data class Success(val location: SnabbitLocation) : LocationResult()

    /**
     * A recoverable/transient failure (timeout, null fix, FLP error). [reason] is a short
     * diagnostic string; [cause] carries the original throwable when there was one.
     */
    data class Failure(val reason: String, val cause: Throwable? = null) : LocationResult()

    /** Location services (the OS GPS toggle) are off and could not be turned on. */
    data object ServiceDisabled : LocationResult()

    /** Location permission is not GRANTED. */
    data object PermissionDenied : LocationResult()

    /** Google Play services is missing/disabled — FusedLocationProviderClient cannot be used. */
    data object PlayServicesUnavailable : LocationResult()
}
