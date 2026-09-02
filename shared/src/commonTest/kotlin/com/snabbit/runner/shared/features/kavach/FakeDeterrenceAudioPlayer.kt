package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.features.kavach.sos.domain.deterrence.DeterrenceAudioPlayer

/** Counts play/stop calls for deterrence-scheduling assertions. */
class FakeDeterrenceAudioPlayer : DeterrenceAudioPlayer {
    var playCount = 0
    var stopCount = 0
    override suspend fun playDeterrence() { playCount++ }
    override fun stop() { stopCount++ }
}
