package com.snabbit.runner.shared.core

/**
 * Test [Logger] that records every log call into [entries] so tests can
 * assert on what was logged.
 */
class FakeLogger : Logger {
    data class Entry(
        val level: Level,
        val tag: String,
        val message: String,
        val throwable: Throwable?,
    )

    enum class Level { DEBUG, WARN, ERROR }

    private val _entries = mutableListOf<Entry>()
    val entries: List<Entry> get() = _entries.toList()

    override fun d(tag: String, message: String) {
        _entries.add(Entry(Level.DEBUG, tag, message, null))
    }

    override fun w(tag: String, message: String, throwable: Throwable?) {
        _entries.add(Entry(Level.WARN, tag, message, throwable))
    }

    override fun e(tag: String, message: String, throwable: Throwable?) {
        _entries.add(Entry(Level.ERROR, tag, message, throwable))
    }
}
