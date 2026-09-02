package com.snabbit.runner.shared.features.pan.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result

/**
 * Data-layer seam for the PAN update (`POST api/v1/verification/pan/update` on the
 * **onboarding host**). On a 2xx it returns the **raw response body** — the backend
 * can reject an invalid PAN with `200` + a non-empty `errors[]` (see
 * `upload_pan_modal_sheet_v2.dart`), so the repository must inspect the body to
 * decide success vs. failure and extract the message. On a transport/HTTP failure it
 * returns the [NetworkError].
 */
internal interface PanRemoteDataSource {
    suspend fun updatePan(panNumber: String): Result<String, NetworkError>
}
