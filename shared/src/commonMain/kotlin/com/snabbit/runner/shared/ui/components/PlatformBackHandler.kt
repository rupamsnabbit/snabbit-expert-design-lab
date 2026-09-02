package com.snabbit.runner.shared.ui.components

import androidx.compose.runtime.Composable

/**
 * Multiplatform back-gesture handler. While [enabled], the platform back action (Android
 * hardware / gesture back) is intercepted and routed to [onBack]; when disabled it falls through
 * to the next handler. iOS has no hardware back button, so the iOS actual is a no-op.
 *
 * Exists because the multiplatform `androidx.compose.ui.backhandler.BackHandler` is only a
 * transitive (`implementation`) dependency of Material3 here, so it isn't on `:shared`'s own
 * compile classpath. [SnabbitBottomSheet] uses this to swallow back on a non-dismissible (forced)
 * sheet — composed inside the sheet body so it outranks Material3's internal back handler.
 */
@Composable
internal expect fun PlatformBackHandler(enabled: Boolean, onBack: () -> Unit)
