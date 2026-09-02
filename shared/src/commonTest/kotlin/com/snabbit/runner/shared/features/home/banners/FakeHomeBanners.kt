package com.snabbit.runner.shared.features.home.banners

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.home.banners.data.HomeBannersStore
import com.snabbit.runner.shared.features.home.banners.data.remote.BannerRemoteDataSource
import com.snabbit.runner.shared.features.home.banners.data.remote.dto.BannerDto
import com.snabbit.runner.shared.features.home.banners.data.remote.dto.HomeBannersResponseDto
import com.snabbit.runner.shared.features.home.banners.data.remote.dto.HomeNotificationsDto

/**
 * Test double for the one `/me/home_banners` fetch. [result] is returned by
 * every call and [calls] counts them, so refetch assertions survive the move off
 * the retired banner repository. Defaults to `Ok(empty)` — the "no campaigns"
 * case that keeps Home's Refer fallback.
 */
internal class FakeHomeBannersRemote(
    var result: Result<HomeBannersResponseDto, NetworkError> = Result.Ok(HomeBannersResponseDto()),
) : BannerRemoteDataSource {
    var calls = 0
        private set

    override suspend fun fetchHomeBanners(): Result<HomeBannersResponseDto, NetworkError> {
        calls++
        return result
    }

    companion object {
        /** A representative transport failure for Err-path tests. */
        fun transportError(): NetworkError = NetworkError.TransportError(
            errorType = AppErrorType.NO_INTERNET,
            requestId = "test-request",
            durationMs = 0,
        )

        fun ok(
            banners: List<BannerDto> = emptyList(),
            unreadCount: Int? = null,
        ): Result<HomeBannersResponseDto, NetworkError> = Result.Ok(
            HomeBannersResponseDto(
                banners = banners,
                notifications = unreadCount?.let { HomeNotificationsDto(it) },
            ),
        )

        /** Wire-shaped banner row, mirroring the domain helper the Home tests use. */
        fun bannerDto(
            id: String = "promo_1",
            clickPath: String = "/referral-home",
            clickArgs: Map<String, String> = emptyMap(),
        ) = BannerDto(
            id = id,
            title = "Title",
            subtitle = "Sub",
            buttonText = "Go",
            bannerBgImage = "https://cdn.example.com/bg.png",
            buttonClickPath = clickPath,
            clickArgs = clickArgs,
        )
    }
}

/** A real store over [remote] — it holds no platform state, so faking the seam is enough. */
internal fun fakeHomeBannersStore(
    remote: FakeHomeBannersRemote = FakeHomeBannersRemote(),
) = HomeBannersStore(remote = remote, logger = FakeLogger())
