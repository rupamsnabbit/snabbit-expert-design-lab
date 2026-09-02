package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.features.kavach.shield.data.remote.ShieldConsentApi

/** Set [result] to drive the consent gate; [calls] counts submissions. */
class FakeShieldConsentApi(var result: Boolean = true) : ShieldConsentApi {
    var calls = 0
    override suspend fun submitConsent(): Boolean {
        calls++
        return result
    }
}
