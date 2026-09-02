package com.snabbit.runner.shared.core.location.internal

import com.google.android.gms.location.Priority
import com.snabbit.runner.shared.core.location.LocationPriority

/** Maps our platform-agnostic [LocationPriority] to a Google Play services `Priority` constant. */
internal fun LocationPriority.toGmsPriority(): Int = when (this) {
    LocationPriority.HIGH_ACCURACY -> Priority.PRIORITY_HIGH_ACCURACY
    LocationPriority.BALANCED -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
    LocationPriority.LOW_POWER -> Priority.PRIORITY_LOW_POWER
    LocationPriority.PASSIVE -> Priority.PRIORITY_PASSIVE
}
