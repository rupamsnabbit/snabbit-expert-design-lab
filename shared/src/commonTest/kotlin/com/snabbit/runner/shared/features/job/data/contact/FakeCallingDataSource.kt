package com.snabbit.runner.shared.features.job.data.contact

/**
 * Test [CallingDataSource]. Records numbers passed to [initiateCall]; [result] is the returned value
 * and [error] (when set) makes it throw (to exercise the handler's dialer fallback).
 */
class FakeCallingDataSource(
    var result: Boolean = true,
    var error: Throwable? = null,
) : CallingDataSource {

    val calls = mutableListOf<String>()

    override suspend fun initiateCall(phoneNumber: String): Boolean {
        calls += phoneNumber
        error?.let { throw it }
        return result
    }
}
