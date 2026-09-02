package com.snabbit.runner.shared.features.job.data.contact

/** Test [CustomerContactLauncher] — records what was launched. */
class FakeCustomerContactLauncher : CustomerContactLauncher {

    val dialed = mutableListOf<String>()
    val mapsOpened = mutableListOf<Pair<Double, Double>>()
    var chatOpenedCount = 0
        private set

    override fun dial(phoneNumber: String) {
        dialed += phoneNumber
    }

    override fun openMapsNavigation(latitude: Double, longitude: Double) {
        mapsOpened += latitude to longitude
    }

    override fun openChat() {
        chatOpenedCount++
    }
}
