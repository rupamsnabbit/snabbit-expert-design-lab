package com.snabbit.runner.overlayhost

import com.snabbit.runner.awol.AwolOverlaySpec
import com.snabbit.runner.job.overlay.NewJobOverlaySpec
import org.koin.core.qualifier.named
import org.koin.dsl.module

/**
 * App-side Koin wiring for the [OverlaySpec]s the host can present. Loaded by
 * [com.snabbit.runner.SnabbitRunnerApplication] right after `KmpBootstrap`
 * starts Koin (the specs live in `:app` — they bridge shared feature UIs into
 * the Android window host, so they can't ride a `:shared` module).
 *
 * Qualified singles of the same interface: [ComposeOverlayHost] and the
 * generic launcher resolve them with `getAll<OverlaySpec>()` and match on
 * [OverlaySpec.key] / [OverlaySpec.shouldTrigger].
 */
val overlaySpecsModule = module {
    single<OverlaySpec>(named(AwolOverlaySpec.KEY)) { AwolOverlaySpec() }
    single<OverlaySpec>(named(NewJobOverlaySpec.KEY)) { NewJobOverlaySpec() }
}
