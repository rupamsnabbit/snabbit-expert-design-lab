package com.snabbit.runner.shared.features.kavach.sos

import com.snabbit.runner.shared.core.navigation.Destination
import kotlinx.serialization.Serializable

/** Full-screen "Help is on the way" state, pushed when the runner raises SOS. */
@Serializable
data object SosActive : Destination
