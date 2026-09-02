package com.snabbit.runner.shared.features.profile

import com.snabbit.runner.shared.core.FakeLogger
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertSame
import kotlin.test.assertTrue

class RunnerProfileStoreTest {

    private fun store() = RunnerProfileStore(FakeLogger())

    @Test
    fun patchLanguagePreference_updatesCachedProfile_whenContentAndDifferent() {
        val store = store()
        store.setProfile(
            sampleRunnerProfile(name = "Reema", languagePreference = "ENGLISH"),
        )

        store.patchLanguagePreference("HINDI")

        val state = store.state.value
        assertTrue(state is ProfileBridgeState.Content)
        assertEquals("HINDI", state.profile.languagePreference)
        // Only the language is patched; other fields are preserved.
        assertEquals("Reema", state.profile.name)
    }

    @Test
    fun patchLanguagePreference_isNoOp_whenNoContentYet() {
        val store = store() // starts Loading (no push yet)

        store.patchLanguagePreference("HINDI")

        assertTrue(store.state.value is ProfileBridgeState.Loading)
        assertNull(store.snapshot())
    }

    @Test
    fun patchLanguagePreference_isNoOp_whenCodeUnchanged() {
        val store = store()
        store.setProfile(sampleRunnerProfile(languagePreference = "HINDI"))
        val before = store.state.value

        store.patchLanguagePreference("HINDI")

        // Same Content instance → no needless state emission to collectors.
        assertSame(before, store.state.value)
    }
}
