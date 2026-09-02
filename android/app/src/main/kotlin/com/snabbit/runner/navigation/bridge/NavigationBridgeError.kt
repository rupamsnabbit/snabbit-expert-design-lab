package com.snabbit.runner.navigation.bridge

/**
 * Concise, log-searchable failure-reason codes for the navigation bridge. Kept as
 * UPPER_SNAKE tokens (not free-text sentences) so failures are easily greppable in
 * logs / Crashlytics. Passed to `NavigationController.reportFailure`; append the
 * dynamic context after the code, e.g. `"$NO_HOST_ACTIVITY_FOUND key=$key"`.
 */
object NavigationBridgeError {
    const val NO_HOST_ACTIVITY_FOUND = "NO_HOST_ACTIVITY_FOUND"
    const val NO_NATIVE_DEST_REGISTERED = "NO_NATIVE_DEST_REGISTERED"
    const val NO_HOST_FOR_RESOLVED_DEEPLINK = "NO_HOST_FOR_RESOLVED_DEEPLINK"
    const val FOR_RESULT_ALREADY_IN_FLIGHT = "FOR_RESULT_ALREADY_IN_FLIGHT"
    const val NO_HOST_TO_RETURN = "NO_HOST_TO_RETURN"
    const val RETURN_NO_STACK_OR_RECREATION = "RETURN_NO_STACK_OR_RECREATION"
}
