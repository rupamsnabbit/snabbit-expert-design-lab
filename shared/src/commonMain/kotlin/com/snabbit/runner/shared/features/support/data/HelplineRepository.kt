package com.snabbit.runner.shared.features.support.data

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.result.Result
import io.ktor.http.HttpMethod
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The runner support helpline number — the "Call us" target of the Need-help sheet
 * ([com.snabbit.runner.shared.features.support.ui.NeedHelpSheet]).
 *
 * Mirrors the Flutter `SupportPopup` exactly: fetch `runners/me/helpline` (`ph_no`) and,
 * when it's missing, fall back to the SOS Remote-Config number (Flutter's `launchDialer`
 * default). Never throws — the caller can always place a call.
 */
interface HelplineRepository {
    /**
     * Resolves the helpline number to call. [type] mirrors the Flutter query param — `PRIMARY`
     * for general support (what `SupportPopup()` sends). A fetch/parse failure or blank `ph_no`
     * degrades to the RC SOS number, so the returned string is always dialable.
     */
    suspend fun helplineNumber(type: String = DEFAULT_TYPE): String

    companion object {
        /** Flutter `SupportPopup` default `SupportType.PRIMARY.name`. */
        const val DEFAULT_TYPE = "PRIMARY"

        /** RC key for the SOS fallback number (mirrors Flutter `expert_sos_contact_number`). */
        const val RC_SOS_FALLBACK = "expert_sos_contact_number"

        /** Baked-in SOS fallback (mirrors Flutter `launchDialer`'s default). */
        const val DEFAULT_SOS_NUMBER = "+919004108043"
    }
}

/** [HelplineRepository] that always returns the RC SOS fallback — previews / tests / iOS. */
object NoOpHelplineRepository : HelplineRepository {
    override suspend fun helplineNumber(type: String): String = HelplineRepository.DEFAULT_SOS_NUMBER
}

@Serializable
private data class HelplineDto(@SerialName("ph_no") val phNo: String? = null)

/**
 * Production [HelplineRepository] — `GET api/v1/runners/me/helpline?type=$type` via the shared
 * [SnabbitHttpClient] (auth + tracing come from the client's interceptor chain; mirrors
 * [com.snabbit.runner.shared.features.profile.data.remote.ProfileRemoteDataSourceImpl]).
 * Any transport/parse failure or blank `ph_no` degrades to the RC SOS number, matching Flutter
 * `SupportPopup.initProcess` + `launchDialer`.
 */
class HelplineRepositoryImpl(
    private val httpClient: SnabbitHttpClient,
    private val remoteConfig: RemoteConfigGateway,
    private val crashReporter: CrashReporter,
) : HelplineRepository {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun helplineNumber(type: String): String {
        val fetched = try {
            fetch(type)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // 2xx body our schema can't parse (or config lookup failure) — report as a
            // non-fatal (schema drift is worth knowing) then fall back to the SOS number.
            crashReporter.report(e, mapOf("op" to "helplineNumber", "type" to type))
            null
        }
        return fetched?.takeIf { it.isNotBlank() }
            ?: remoteConfig.getString(HelplineRepository.RC_SOS_FALLBACK, HelplineRepository.DEFAULT_SOS_NUMBER)
    }

    /** Returns the fetched `ph_no` (may be null/blank), or null on an HTTP error (→ fallback). */
    private suspend fun fetch(type: String): String? {
        val url = "/api/v1/runners/me/helpline?type=$type"
        return when (val result = httpClient.execute(SnabbitRequest(method = HttpMethod.Get, url = url))) {
            // Network transport/HTTP errors are already reported by NetworkExceptionPlugin →
            // just fall back (matches CallingDataSourceImpl / SupportPopup's silent catch).
            is Result.Err -> null
            is Result.Ok -> json.decodeFromString<HelplineDto>(result.value.body).phNo
        }
    }
}
