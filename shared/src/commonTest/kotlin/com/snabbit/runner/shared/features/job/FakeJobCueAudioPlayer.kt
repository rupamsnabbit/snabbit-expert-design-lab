package com.snabbit.runner.shared.features.job

import com.snabbit.runner.shared.features.job.domain.audio.JobCueAudioPlayer

/** Captures the asset paths played (and stop calls) for cue-scheduling assertions. */
class FakeJobCueAudioPlayer : JobCueAudioPlayer {
    val played = mutableListOf<String>()
    var stopCount = 0
    /** Simulate a missing/failed clip: when false, [play] records nothing and returns false. */
    var playSucceeds = true
    override suspend fun play(assetPath: String): Boolean {
        if (!playSucceeds) return false
        played.add(assetPath)
        return true
    }
    override fun stop() { stopCount++ }
}
