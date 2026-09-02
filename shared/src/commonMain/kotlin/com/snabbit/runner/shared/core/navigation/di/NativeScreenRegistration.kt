package com.snabbit.runner.shared.core.navigation.di

import androidx.compose.runtime.Composable
import androidx.navigation3.runtime.NavEntry
import androidx.navigation3.scene.DialogSceneStrategy
import com.snabbit.runner.shared.core.navigation.Destination
import com.snabbit.runner.shared.core.navigation.NativeScreen
import com.snabbit.runner.shared.core.navigation.scene.BottomSheetSceneStrategy
import org.koin.core.module.Module
import org.koin.core.qualifier.qualifier
import org.koin.dsl.bind

/** How the host presents a native destination. */
enum class Presentation { FullScreen, Dialog, BottomSheet }

/** The Nav3 entry metadata that drives each presentation (consumed by the scene strategies). */
fun Presentation.metadata(): Map<String, Any> = when (this) {
    Presentation.FullScreen -> emptyMap()
    Presentation.Dialog -> DialogSceneStrategy.dialog()
    Presentation.BottomSheet -> BottomSheetSceneStrategy.bottomSheet()
}

/**
 * One-call registration of a native screen: binds a [NativeScreen] for [D] that
 * renders [content], tagging its `NavEntry` with the metadata for [presentation]
 * (full-screen / dialog / bottom-sheet). Decentralised — collected via Koin `getAll`.
 * Pair with the commonMain `nativeDestination<D>(…)`.
 *
 * Each binding is given a **per-type [qualifier]** (`TypeQualifier(D::class)`). Without it
 * every `single { NativeScreen { … } }` shares the same primary type (`NativeScreen`) and
 * root qualifier, so a second `nativeScreen` would *override* the first and
 * `getAll<NativeScreen>()` would return only the last — only one screen could render.
 * (Koin has no set-multibinding; `getAll` collects across qualifiers, so a distinct
 * qualifier per registration is what makes them all resolvable.)
 *
 * ```kotlin
 * nativeScreen<JobDetail> { JobDetailScreen(it.jobId) }
 * nativeScreen<ConfirmDialog>(Presentation.Dialog) { ConfirmDialogScreen(it) }
 * ```
 */
inline fun <reified D : Destination> Module.nativeScreen(
    presentation: Presentation = Presentation.FullScreen,
    noinline content: @Composable (D) -> Unit,
) {
    val metadata = presentation.metadata()
    single(qualifier<D>()) {
        NativeScreen { dest ->
            if (dest !is D) return@NativeScreen null
            NavEntry(dest, metadata = metadata) { content(dest) }
        }
    } bind NativeScreen::class
}
