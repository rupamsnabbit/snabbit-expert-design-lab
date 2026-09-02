package com.snabbit.runner.shared.features.home.banners.domain.model

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.home.domain.model.Banner

/**
 * What the last `/me/home_banners` fetch produced.
 *
 * @property banners outcome of the last fetch, or `null` before one resolves.
 *   The failure is kept rather than flattened: Home settles `Err` and
 *   `Ok(empty)` to the same Refer fallback, but only logs the former.
 * @property unreadCount unread notifications, or `null` when unknown — no fetch
 *   yet, the request failed, or the server could not resolve the section.
 */
data class HomeBannersState(
    val banners: Result<List<Banner>, NetworkError>? = null,
    val unreadCount: Int? = null,
) {
    /**
     * Whether the Updates tab shows its dot. `null` is not zero: an unresolved
     * count keeps whatever the badge last showed, so a transient outage never
     * hides unread posts. Only a resolved `0` clears it.
     */
    val hasUnreadNotifications: Boolean get() = (unreadCount ?: 0) > 0
}
