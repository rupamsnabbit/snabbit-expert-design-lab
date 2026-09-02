package com.snabbit.runner.shared.features.home.suspended

import com.snabbit.runner.shared.features.home.suspended.domain.model.UnsuspendResult
import com.snabbit.runner.shared.features.home.suspended.domain.repository.SuspendedRepository

/**
 * Test double for [SuspendedRepository]. [result] is returned by every
 * [unsuspend] call; [calls] counts invocations for single-flight assertions.
 * Defaults to [UnsuspendResult.Reactivated] (the happy path).
 */
class FakeSuspendedRepository(
    var result: UnsuspendResult = UnsuspendResult.Reactivated(statusCode = 200),
) : SuspendedRepository {
    var calls = 0
        private set

    override suspend fun unsuspend(): UnsuspendResult {
        calls++
        return result
    }
}
