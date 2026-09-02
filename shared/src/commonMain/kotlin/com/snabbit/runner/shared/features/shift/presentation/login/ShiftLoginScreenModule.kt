package com.snabbit.runner.shared.features.shift.presentation.login

import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics
import com.snabbit.runner.shared.core.location.LocationProvider
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.navigation.di.nativeScreen
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.gamification.presentation.postaction.PostActionCoordinator
import com.snabbit.runner.shared.features.shift.core.domain.repository.ShiftRepository
import org.koin.core.module.Module
import org.koin.dsl.module
import org.koin.mp.KoinPlatform.getKoin

/**
 * Registration of the shift-login screen as a full-screen native [ShiftLogin]
 * destination — pushed on the [NavigationController] when Home fires `TapLogin`,
 * popped on Finish. Registered once at bootstrap (see `KmpBootstrap`).
 *
 * Lives in `commonMain`: the screen, its VM, and the `nativeScreen` DSL (Nav3 is
 * multiplatform) are all common, and this registration uses no platform APIs — so
 * the whole shift-login feature is iOS-registrable end-to-end.
 *
 * The camera is wired by `cameraKoinModule` (registered in `KmpBootstrap`): its
 * [ShiftLoginScreen] embeds `CameraFlow`, which resolves its own `CameraViewModel`
 * — analytics + the `PermissionManager`-backed permission controller — from Koin.
 * The per-entry VM uses a [rememberCoroutineScope] tied to this nav entry, so it
 * dies when the entry pops.
 */
val shiftLoginScreenModule: Module = module {
    single { ShiftLoginAnalytics(tracker = get()) }
    nativeScreen<ShiftLogin> {
        val scope = rememberCoroutineScope()
        val koin = getKoin()
        val controller = koin.get<NavigationController>()
        val postActionCoordinator = koin.get<PostActionCoordinator>()
        val runnerStateStore = koin.get<RunnerStateStore>()
        val vm = remember {
            ShiftLoginViewModel(
                location = koin.get<LocationProvider>(),
                shiftRepository = koin.get<ShiftRepository>(),
                analytics = koin.get<ShiftLoginAnalytics>(),
                errorAnalytics = koin.get<ErrorAnalytics>(),
                scope = scope,
                // WS5: post-login state (WAIT_HOTSPOT / Map archetype) arrives via the
                // MQTT snapshot. Feature #4: arm the timed current_state fallback so a
                // missed login transition self-heals. (Distinct from onPostAction below,
                // which presents the gamification reward popup.)
                onShiftLoggedIn = { runnerStateStore.onPostAction("shift_login") },
                // Fire-and-forget: the login screen pops on Finish, so present the
                // reward on the coordinator; home's overlay host renders it.
                onPostAction = { outcome -> postActionCoordinator.present(outcome) },
            )
        }
        ShiftLoginScreen(
            viewModel = vm,
            onFinish = { controller.back() },
        )
    }
}
