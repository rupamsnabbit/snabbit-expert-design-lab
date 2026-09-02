package com.snabbit.runner.shared.core.analytics.providers

/** Records every [MixpanelApi] call (in order) for contract assertions. */
class FakeMixpanelApi : MixpanelApi {
    sealed class Call {
        data object Initialize : Call()
        data class Track(val name: String, val props: Map<String, Any>) : Call()
        data class Identify(val distinctId: String) : Call()
        data object Reset : Call()
        data class SetUserProperty(val key: String, val value: Any?) : Call()
        data class SetUserProperties(val props: Map<String, Any>) : Call()
    }

    private val _calls = mutableListOf<Call>()
    val calls: List<Call> get() = _calls.toList()

    override fun initialize() {
        _calls.add(Call.Initialize)
    }

    override fun track(name: String, props: Map<String, Any>) {
        _calls.add(Call.Track(name, props))
    }

    override fun identify(distinctId: String) {
        _calls.add(Call.Identify(distinctId))
    }

    override fun reset() {
        _calls.add(Call.Reset)
    }

    override fun setUserProperty(key: String, value: Any?) {
        _calls.add(Call.SetUserProperty(key, value))
    }

    override fun setUserProperties(props: Map<String, Any>) {
        _calls.add(Call.SetUserProperties(props))
    }
}
