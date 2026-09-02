package com.snabbit.runner.shared.features.kavach.sos.data.store

import com.snabbit.runner.shared.core.storage.EncryptedStore
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Persists a pending SOS push action (an FCM notification-button tap received while the app was
 * backgrounded/killed) so it can be applied on the next foreground. The FCM receipt is host-owned
 * (forwarded via `SosPushEntry`); this is the pure-KMP store. [peek] reads+decodes without deleting;
 * the caller [clear]s only AFTER applyPush succeeds (ack-then-delete) so a crash/hang between read and
 * apply can't silently lose the action (parity: Flutter `shield_sos_push_store.dart`).
 */
class SosPushStore(
    private val store: EncryptedStore,
    private val json: Json = Json { ignoreUnknownKeys = true },
) {
    suspend fun persist(action: String, sosId: Int) {
        store.putString(KEY, json.encodeToString(PendingSosPush(action, sosId)))
    }

    /** Read + decode the pending push WITHOUT removing it. The caller [clear]s only after applyPush
     *  succeeds (ack-then-delete) — deleting here would lose the action on a crash/hang between the delete
     *  and the (network-fronted) apply. Decode failures return null and leave the raw for retry. */
    suspend fun peek(): PendingSosPush? {
        val raw = store.getString(KEY) ?: return null
        return runCatching { json.decodeFromString(PendingSosPush.serializer(), raw) }.getOrNull()
    }

    /** Ack: remove the pending push once its action has been applied. */
    suspend fun clear() = store.delete(KEY)

    /** Conditional ack: delete only if the currently-stored push still equals [expected] — so a newer
     *  push that arrived (persist) between the caller's peek() and this clear() isn't silently dropped. */
    suspend fun clear(expected: PendingSosPush) {
        if (peek() == expected) store.delete(KEY)
    }

    private companion object {
        const val KEY = "pending_shield_sos_action"
    }
}

@Serializable
data class PendingSosPush(
    val action: String,
    @SerialName("sos_id") val sosId: Int,
)
