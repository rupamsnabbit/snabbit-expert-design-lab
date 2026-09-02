package com.snabbit.runner.shared.core.analytics.providers

class FakeCleverTapApi : CleverTapApi {
    sealed class Call {
        data class Record(val name: String, val props: Map<String, Any>) : Call()
        data class Login(val profile: Map<String, Any?>) : Call()
    }

    private val _calls = mutableListOf<Call>()
    val calls: List<Call> get() = _calls.toList()

    override fun recordEvent(name: String, props: Map<String, Any>) {
        _calls.add(Call.Record(name, props))
    }

    override fun onUserLogin(profile: Map<String, Any?>) {
        _calls.add(Call.Login(profile))
    }
}
