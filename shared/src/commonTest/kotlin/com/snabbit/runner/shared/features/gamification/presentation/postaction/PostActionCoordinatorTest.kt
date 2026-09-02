package com.snabbit.runner.shared.features.gamification.presentation.postaction

import com.snabbit.runner.shared.features.gamification.domain.model.NudgeLabel
import com.snabbit.runner.shared.features.gamification.domain.model.OutcomeStatus
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class PostActionCoordinatorTest {

    private fun outcome(status: OutcomeStatus = OutcomeStatus.Reward) = PostActionOutcome(
        status = status,
        label = NudgeLabel.literal("Nice"),
        goldCoins = 10,
    )

    @Test
    fun show_publishesOutcome_andSuspendsUntilDismiss() = runTest {
        val coordinator = PostActionCoordinator()
        var completed = false

        val job = launch { coordinator.show(outcome()); completed = true }
        runCurrent()

        // Presented, and the caller is still suspended.
        assertEquals(10, coordinator.current.value?.goldCoins)
        assertTrue(!completed)

        coordinator.dismiss()
        runCurrent()

        assertNull(coordinator.current.value)
        assertTrue(completed)
        assertTrue(job.isCompleted)
    }

    @Test
    fun secondShow_waitsForFirstToDismiss() = runTest {
        val coordinator = PostActionCoordinator()
        launch { coordinator.show(outcome(OutcomeStatus.Reward)) }
        runCurrent()
        // Second outcome queued behind the mutex — not presented yet.
        launch { coordinator.show(outcome(OutcomeStatus.Penalty).copy(redCards = 1)) }
        runCurrent()
        assertEquals(OutcomeStatus.Reward, coordinator.current.value?.status)

        coordinator.dismiss()
        runCurrent()
        // Now the second one is presented.
        assertEquals(OutcomeStatus.Penalty, coordinator.current.value?.status)

        // Dismiss the second one too — resumes the suspended show() so the test
        // leaves no coroutine behind (runTest fails on leaks) and proves the
        // queue drains back to idle.
        coordinator.dismiss()
        runCurrent()
        assertEquals(null, coordinator.current.value)
    }
}
