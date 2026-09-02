package com.snabbit.runner.shared.features.shift

import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode.BikeNotDetected
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode.FaceMismatch
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode.FaceNotDetected
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode.HelmetNotDetected
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode.UniformNotDetected
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode.Unknown
import kotlin.test.Test
import kotlin.test.assertEquals

class SelfieValidationCodeTest {

    @Test fun fromWire_mapsKnownCodes() {
        assertEquals(UniformNotDetected, SelfieValidationCode.fromWire("uniform_not_detected"))
        assertEquals(FaceMismatch, SelfieValidationCode.fromWire("face_mismatch"))
        assertEquals(FaceNotDetected, SelfieValidationCode.fromWire("face_not_detected"))
        assertEquals(BikeNotDetected, SelfieValidationCode.fromWire("bike_not_detected"))
        assertEquals(HelmetNotDetected, SelfieValidationCode.fromWire("helmet_not_detected"))
    }

    @Test fun fromWire_unknownCollapsesToUnknown() {
        assertEquals(Unknown, SelfieValidationCode.fromWire("totally_made_up"))
        assertEquals(Unknown, SelfieValidationCode.fromWire(""))
    }
}
