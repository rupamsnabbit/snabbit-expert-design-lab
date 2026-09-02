package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.features.kavach.shield.data.gateway.CurrentStateGateway
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.CurrentStateSnapshot

/** Settable job-context for enablement-gate tests. [snapshotFails] simulates a fetch failure. */
class FakeCurrentStateGateway(
    var jobId: Int? = null,
    var customerConsent: Boolean = false,
    var auto: Boolean = false,
    var widget: String? = null,
    var snapshotFails: Boolean = false,
) : CurrentStateGateway {
    override suspend fun currentJobId(): Int? = jobId
    override suspend fun customerConsentEnabled(): Boolean = customerConsent
    override suspend fun autoEnabled(): Boolean = auto
    override suspend fun widgetName(): String? = widget
    override suspend fun snapshot(): CurrentStateSnapshot? =
        if (snapshotFails) null else CurrentStateSnapshot(jobId, customerConsent, auto, widget)
}
