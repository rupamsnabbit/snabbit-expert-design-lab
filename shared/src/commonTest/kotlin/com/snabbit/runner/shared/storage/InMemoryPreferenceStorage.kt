package com.snabbit.runner.shared.storage

/**
 * HashMap-backed [PreferenceStorage] for commonTest. All types are stored
 * as strings (matching the serialize-through-string contract) so
 * cross-type reads behave identically in tests and production. Writes always
 * succeed (return true).
 */
class InMemoryPreferenceStorage : PreferenceStorage {

    private val map = mutableMapOf<String, String>()

    override suspend fun getString(key: String): String? = map[key]
    override suspend fun putString(key: String, value: String): Boolean { map[key] = value; return true }

    override suspend fun getInt(key: String): Int? = map[key]?.toIntOrNull()
    override suspend fun putInt(key: String, value: Int): Boolean { map[key] = value.toString(); return true }

    override suspend fun getLong(key: String): Long? = map[key]?.toLongOrNull()
    override suspend fun putLong(key: String, value: Long): Boolean { map[key] = value.toString(); return true }

    override suspend fun getBool(key: String): Boolean? = map[key]?.toBooleanStrictOrNull()
    override suspend fun putBool(key: String, value: Boolean): Boolean { map[key] = value.toString(); return true }

    override suspend fun getDouble(key: String): Double? = map[key]?.toDoubleOrNull()
    override suspend fun putDouble(key: String, value: Double): Boolean { map[key] = value.toString(); return true }

    override suspend fun remove(key: String): Boolean { map.remove(key); return true }
    override suspend fun clear(): Boolean { map.clear(); return true }
}
