package com.snabbit.runner.shared.core.camera.di

import com.snabbit.runner.shared.core.camera.CameraModule
import com.snabbit.runner.shared.core.camera.CameraPermissionController
import com.snabbit.runner.shared.core.camera.MediaPersister
import com.snabbit.runner.shared.core.camera.NoOpMediaPersister
import com.snabbit.runner.shared.core.camera.PermissionManagerCameraController
import com.snabbit.runner.shared.core.camera.internal.PlatformFileOps
import com.snabbit.runner.shared.core.camera.internal.platformFileOps
import com.snabbit.runner.shared.core.camera.ui.CameraViewModel
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

/**
 * Koin wiring for the camera module. Registered in `KmpBootstrap.initialize`.
 *
 * Binds the headless [CameraModule] (via the platform [cameraModule] factory),
 * the [CameraPermissionController] (the shared `PermissionManager`-backed
 * controller — `PermissionManager` itself is bound by `permissionsModule`), the
 * [com.snabbit.runner.shared.core.camera.internal.PlatformFileOps] file-ops seam
 * (built from the core `CrashReporter` + `AppDispatchers`), and the default no-op
 * [MediaPersister] (production Android hosts can override with a
 * `GalleryMediaPersister`). The [CameraViewModel] is a `koin-compose-viewmodel`
 * `viewModel` definition: `PlatformFileOps` / `CrashReporter` / `AnalyticsTracker`
 * (plus `Logger` / `AppDispatchers`, used by the factory) resolve from Koin, while
 * the per-launch analytics `source` and
 * [com.snabbit.runner.shared.core.camera.ui.PreviewMode] arrive as runtime
 * parameters (`parametersOf(source, previewMode)` at the `koinViewModel` call site
 * in `CameraFlow`).
 */
val cameraKoinModule = module {
    single<CameraModule> { cameraModule(logger = get(), dispatchers = get(), fileOps = get()) }
    single<CameraPermissionController> { PermissionManagerCameraController(get()) }
    single<MediaPersister> { NoOpMediaPersister }
    single<PlatformFileOps> { platformFileOps(crashReporter = get(), dispatchers = get()) }
    viewModel { params ->
        CameraViewModel(
            cameraModule = get(),
            analyticsTracker = get(),
            analyticsSource = params.get(),
            permissions = get(),
            crashReporter = get(),
            platformFileOps = get(),
            mediaPersister = get(),
            previewMode = params.get(),
        )
    }
}
