package com.snabbit.runner.shared.features.shift.attendance.di

import com.snabbit.runner.shared.features.shift.attendance.data.remote.AttendanceRemoteDataSource
import com.snabbit.runner.shared.features.shift.attendance.data.remote.AttendanceRemoteDataSourceImpl
import com.snabbit.runner.shared.features.shift.attendance.data.repository.AttendanceRepositoryImpl
import com.snabbit.runner.shared.features.shift.attendance.domain.repository.AttendanceRepository
import org.koin.dsl.module

/**
 * Koin wiring for the Attendance feature. One module covers all three layers
 * because the bindings are interface→impl and have no per-launch state — the
 * Language module follows the same convention.
 *
 * Registered in `KmpBootstrap.initialize`.
 */
val attendanceModule = module {
    single<AttendanceRemoteDataSource> {
        AttendanceRemoteDataSourceImpl(httpClient = get())
    }
    single<AttendanceRepository> {
        AttendanceRepositoryImpl(remote = get())
    }
}
