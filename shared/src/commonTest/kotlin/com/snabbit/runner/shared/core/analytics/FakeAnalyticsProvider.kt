package com.snabbit.runner.shared.core.analytics

/**
 * Test fake for [AnalyticsProvider]. Records every call into [calls] for
 * assertions. Optional [throwOn] / [throwOnStart] flags simulate vendor
 * failures so tests can verify the tracker's failure isolation.
 */
class FakeAnalyticsProvider(
    override val tag: String,
    private val throwOn: Set<String> = emptySet(),
    private val throwOnStart: Boolean = false,
) : AnalyticsProvider {

    sealed class Call {
        data object Start : Call()
        data class Track(val name: String, val props: Map<String, Any>) : Call()
        data class Identify(val userId: String?) : Call()
        data object Reset : Call()
        data class SetUserProperty(val key: String, val value: Any?) : Call()
        data class OnUserLogin(val profile: Map<String, Any?>) : Call()
        data class SetUserProperties(val props: Map<String, Any>) : Call()
    }

    private val _calls = mutableListOf<Call>()
    val calls: List<Call> get() = _calls.toList()

    override suspend fun start() {
        if (throwOnStart) throw RuntimeException("simulated start failure")
        _calls.add(Call.Start)
    }

    override fun track(name: String, props: Map<String, Any>) {
        if (name in throwOn) throw RuntimeException("simulated track failure for '$name'")
        _calls.add(Call.Track(name, props))
    }

    override fun identify(userId: String?) {
        _calls.add(Call.Identify(userId))
    }

    override fun reset() {
        _calls.add(Call.Reset)
    }

    override fun setUserProperty(key: String, value: Any?) {
        if (key in throwOn) throw RuntimeException("simulated setUserProperty failure for '$key'")
        _calls.add(Call.SetUserProperty(key, value))
    }

    override fun onUserLogin(profile: Map<String, Any?>) {
        _calls.add(Call.OnUserLogin(profile))
    }

    override fun setUserProperties(props: Map<String, Any>) {
        if (props.keys.any { it in throwOn }) {
            throw RuntimeException("simulated setUserProperties failure for keys=${props.keys}")
        }
        _calls.add(Call.SetUserProperties(props))
    }
}

/** Records every CrashReporter.report() call. */
class RecordingCrashReporter : com.snabbit.runner.shared.core.CrashReporter {
    data class Report(val throwable: Throwable, val meta: Map<String, String>)
    private val _reports = mutableListOf<Report>()
    val reports: List<Report> get() = _reports.toList()

    override fun report(throwable: Throwable, meta: Map<String, String>) {
        _reports.add(Report(throwable, meta))
    }
}
