package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.storage.EncryptedStore
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

private class FakeEncryptedStore : EncryptedStore {
    val map = mutableMapOf<String, String>()
    override suspend fun getString(key: String): String? = map[key]
    override suspend fun putString(key: String, value: String) { map[key] = value }
    override suspend fun delete(key: String) { map.remove(key) }
    override suspend fun getAll(keys: Set<String>): Map<String, String> =
        map.filterKeys { it in keys }
}

private const val FULL = """{"broker_host":"b.example","broker_port":8883,"broker_url":"mqtts://b.example:8883",
"use_tls":true,"keepalive":45,"username":"82508","client_id_prefix":"runner_82508_",
"state_topic":"maestro/user/82508/state","subscriptions":["maestro/user/82508/state"],"future_field":1}"""

class RealtimeConfigStoreTest {

    @Test
    fun push_parses_persists_and_maps() = runTest {
        val disk = FakeEncryptedStore()
        val store = RealtimeConfigStore(disk, FakeLogger())
        assertEquals(true, store.push(FULL))

        val cfg = store.snapshot()
        assertEquals("b.example", cfg?.host)
        assertEquals(8883, cfg?.port)
        assertEquals(true, cfg?.useTls)
        assertEquals(true, cfg?.kmpEnabled, "absent mqtt_kmp_enabled defaults to enabled")
        assertTrue(disk.map.containsKey("realtime.mqtt_config"), "last-known-good persisted (§4.1)")

        val rc = store.toRealtimeConfig(jwt = "tok", installSuffix = "abc123")
        assertEquals("runner_82508_abc123", rc?.clientId)
        assertEquals("tok", rc?.password)
        assertEquals(45, rc?.keepAliveSeconds)
    }

    @Test
    fun kill_switch_disables_without_losing_parse() = runTest {
        val store = RealtimeConfigStore(FakeEncryptedStore(), FakeLogger())
        assertEquals(false, store.push(FULL.replace("\"future_field\":1", "\"mqtt_kmp_enabled\":false")))
        assertNull(store.toRealtimeConfig("tok", "s"), "kill-switch ⇒ engine never starts (§3.2)")
    }

    @Test
    fun null_push_clears_config_and_disk() = runTest {
        val disk = FakeEncryptedStore()
        val store = RealtimeConfigStore(disk, FakeLogger())
        store.push(FULL)
        assertEquals(false, store.push(null))
        assertNull(store.snapshot())
        assertEquals(false, disk.map.containsKey("realtime.mqtt_config"))
    }

    @Test
    fun hydrate_restores_cold_boot_config() = runTest {
        val disk = FakeEncryptedStore()
        RealtimeConfigStore(disk, FakeLogger()).push(FULL)   // previous process
        val fresh = RealtimeConfigStore(disk, FakeLogger())  // cold boot (§6.2)
        fresh.hydrate()
        assertEquals("b.example", fresh.snapshot()?.host)
    }

    @Test
    fun install_suffix_is_minted_once_and_stable() = runTest {
        val disk = FakeEncryptedStore()
        val store = RealtimeConfigStore(disk, FakeLogger())
        val first = store.installSuffix()
        assertEquals(first, store.installSuffix())
        assertEquals(first, RealtimeConfigStore(disk, FakeLogger()).installSuffix(), "survives restart")
    }

    @Test
    fun malformed_push_keeps_previous_config() = runTest {
        val store = RealtimeConfigStore(FakeEncryptedStore(), FakeLogger())
        store.push(FULL)
        store.push("{not json")
        assertEquals("b.example", store.snapshot()?.host)
    }

    @Test
    fun health_analytics_flag_round_trips_through_push_and_hydrate() = runTest {
        val disk = FakeEncryptedStore()
        val store = RealtimeConfigStore(disk, FakeLogger())
        assertEquals(true, store.healthAnalyticsEnabled.value, "defaults on (fail-open)")

        store.pushAppConfig(
            mqttEnabled = true, pollIntervalSeconds = 60,
            connectTimeoutSeconds = 25, postActionTimeoutSeconds = 5,
            healthAnalyticsEnabled = false,
        )
        assertEquals(false, store.healthAnalyticsEnabled.value)

        val fresh = RealtimeConfigStore(disk, FakeLogger()) // cold boot
        fresh.hydrate()
        assertEquals(false, fresh.healthAnalyticsEnabled.value, "restored from storage")
    }
}
