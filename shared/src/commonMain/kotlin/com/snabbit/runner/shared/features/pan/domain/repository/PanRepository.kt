package com.snabbit.runner.shared.features.pan.domain.repository

import com.snabbit.runner.shared.core.result.Result

/**
 * Domain contract for submitting the runner's PAN. On failure returns a
 * **user-facing message** (the server's `{message}`, or a safe fallback) — the
 * sheet shows it inline under the field.
 */
interface PanRepository {
    suspend fun updatePan(panNumber: String): Result<Unit, String>
}
