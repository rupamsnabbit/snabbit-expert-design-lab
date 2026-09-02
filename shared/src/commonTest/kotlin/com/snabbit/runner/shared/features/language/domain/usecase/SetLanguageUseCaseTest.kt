package com.snabbit.runner.shared.features.language.domain.usecase

import com.snabbit.runner.shared.features.language.FakeLanguageDataSource
import com.snabbit.runner.shared.features.language.FakeProfileGateway
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class SetLanguageUseCaseTest {

    @Test
    fun persists_thenApplies() = runTest {
        val dataSource = FakeLanguageDataSource()
        val profile = FakeProfileGateway()

        SetLanguageUseCase(dataSource, profile).invoke("hi")

        assertEquals(listOf("hi"), dataSource.setLanguageCalls)
        assertEquals(listOf("hi"), profile.applyLanguageCalls)
    }

    @Test
    fun persistFailure_propagates_andSkipsApply() = runTest {
        val dataSource = FakeLanguageDataSource(
            setLanguageError = RuntimeException("persist failed"),
        )
        val profile = FakeProfileGateway()

        assertFailsWith<RuntimeException> {
            SetLanguageUseCase(dataSource, profile).invoke("hi")
        }
        assertTrue(profile.applyLanguageCalls.isEmpty())
    }

    @Test
    fun applyFailure_isSwallowed_afterPersist() = runTest {
        // The server-side persist already succeeded; a best-effort apply/bridge
        // failure must not propagate (would surface as a spurious save error).
        val dataSource = FakeLanguageDataSource()
        val profile = FakeProfileGateway(applyLanguageError = RuntimeException("bridge"))

        SetLanguageUseCase(dataSource, profile).invoke("hi") // must not throw

        assertEquals(listOf("hi"), dataSource.setLanguageCalls)
    }
}
