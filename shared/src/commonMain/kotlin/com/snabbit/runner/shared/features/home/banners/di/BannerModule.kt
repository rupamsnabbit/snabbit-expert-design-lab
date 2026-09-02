package com.snabbit.runner.shared.features.home.banners.di

import com.snabbit.runner.shared.features.home.banners.data.HomeBannersStore
import com.snabbit.runner.shared.features.home.banners.data.remote.BannerRemoteDataSource
import com.snabbit.runner.shared.features.home.banners.data.remote.BannerRemoteDataSourceImpl
import org.koin.dsl.module

/**
 * Koin wiring for `/me/home_banners`. The store is a `single` because the
 * Updates badge outlives every tab and must not be re-fetched per screen.
 * Registered in `KmpBootstrap.initialize`.
 */
val bannerModule = module {
    single<BannerRemoteDataSource> { BannerRemoteDataSourceImpl(httpClient = get()) }
    single { HomeBannersStore(remote = get(), logger = get()) }
}
