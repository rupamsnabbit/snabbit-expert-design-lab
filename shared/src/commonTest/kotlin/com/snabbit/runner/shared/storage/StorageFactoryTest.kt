package com.snabbit.runner.shared.storage

import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertSame

class StorageFactoryTest {

    private val secure = InMemorySecureStorage()
    private val preference = InMemoryPreferenceStorage()

    private val factory = object : StorageFactory {
        override fun secureStorage(): SecureStorage = secure
        override fun preferenceStorage(): PreferenceStorage = preference
    }

    @Test
    fun secureStorage_returnsSameInstance() {
        assertSame(secure, factory.secureStorage())
    }

    @Test
    fun preferenceStorage_returnsSameInstance() {
        assertSame(preference, factory.preferenceStorage())
    }

    @Test
    fun factory_secureStorage_delegates() = runTest {
        factory.secureStorage().putString("k", "v")
        assertEquals("v", secure.getString("k"))
    }

    @Test
    fun factory_preferenceStorage_delegates() = runTest {
        factory.preferenceStorage().putString("k", "v")
        assertEquals("v", preference.getString("k"))
    }
}
