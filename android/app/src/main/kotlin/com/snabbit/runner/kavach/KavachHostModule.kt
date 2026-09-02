package com.snabbit.runner.kavach

import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.snabbit.runner.shared.core.navigation.di.nativeScreen
import com.snabbit.runner.shared.features.kavach.shared.SafetyHome
import com.snabbit.runner.shared.features.kavach.sos.SosActive
import com.snabbit.runner.shared.features.kavach.shared.ui.screens.SafetyHomeScreen
import com.snabbit.runner.shared.features.kavach.sos.ui.screens.SosActiveScreen
import com.snabbit.runner.shared.features.kavach.shared.ui.viewmodel.SafetyHomeViewModel
import com.snabbit.runner.shared.features.kavach.sos.ui.viewmodel.SosActiveViewModel
import org.koin.dsl.module
import org.koin.mp.KoinPlatform.getKoin

/**
 * `:app` screen mapping for the Kavach feature. Each `nativeScreen` scopes its
 * ViewModel to the NavEntry via `viewModel { }` (host ViewModelStore decorator),
 * collects state, and renders the stateless screen. Loaded via `loadKoinModules`
 * after `KmpBootstrap.initialize`.
 */
val kavachHostModule = module {
    nativeScreen<SafetyHome> {
        val vm = viewModel { SafetyHomeViewModel(nav = getKoin().get(), dataSource = getKoin().get(), sosCoordinator = getKoin().get(), permissionGate = getKoin().get(), lifecycle = getKoin().get(), analytics = getKoin().get()) }
        val state by vm.uiState.collectAsStateWithLifecycle()
        SafetyHomeScreen(uiState = state, onIntent = vm::onIntent)
    }
    nativeScreen<SosActive> {
        val vm = viewModel { SosActiveViewModel(nav = getKoin().get(), sosCoordinator = getKoin().get(), analytics = getKoin().get()) }
        val state by vm.uiState.collectAsStateWithLifecycle()
        SosActiveScreen(uiState = state, onIntent = vm::onIntent)
    }
}
