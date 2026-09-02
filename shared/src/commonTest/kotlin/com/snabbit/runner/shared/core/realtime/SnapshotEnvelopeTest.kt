package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.FakeLogger
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SnapshotEnvelopeTest {
    private val logger = FakeLogger()

    @Test
    fun parses_full_envelope() {
        val env = SnapshotEnvelope.parse(message(seq = 42, epoch = 7).payload, logger)
        assertEquals(42, env?.stateSeq)
        assertEquals(7, env?.epoch)
        assertEquals(1, env?.schemaVersion)
    }

    @Test
    fun missing_epoch_and_schema_default() {
        val env = SnapshotEnvelope.parse("""{"event_type":"STATE_SNAPSHOT","state_seq":5}""", logger)
        assertEquals(0, env?.epoch)
        assertEquals(1, env?.schemaVersion)
    }

    @Test
    fun unknown_fields_are_ignored() {
        val env = SnapshotEnvelope.parse(
            """{"event_type":"STATE_SNAPSHOT","state_seq":5,"future_field":{"x":1}}""", logger,
        )
        assertEquals(5, env?.stateSeq)
    }

    @Test
    fun malformed_payload_returns_null_never_throws() {
        assertNull(SnapshotEnvelope.parse("not json at all", logger))
    }

    @Test
    fun toRunnerStateJson_maps_widget_into_store_contract() {
        val raw = envelope(seq = 9, name = "ON_THE_JOB").toRunnerStateJson()
        assertTrue(""""widget_name":"ON_THE_JOB"""" in raw, raw)
        assertTrue(""""widget_data"""" in raw, raw)
    }

    @Test
    fun toRunnerStateJson_lifts_show_lunch_selection_from_widget_object() {
        // MQTT STATE_SNAPSHOT shape: the full widget dump nests show_lunch_selection INSIDE
        // `widget` (no top-level lift) — toRunnerStateJson must surface it for the Dart
        // fold that drives the Flutter lunch banner.
        val env = SnapshotEnvelope.parse(
            """{"event_type":"STATE_SNAPSHOT","state_seq":5,""" +
                """"widget":{"widget_name":"SPIKE","widget_data":{},"show_lunch_selection":true}}""",
            logger,
        )
        assertTrue(""""show_lunch_selection":true""" in env!!.toRunnerStateJson(), env.toRunnerStateJson())
    }

    @Test
    fun toRunnerStateJson_topLevel_show_lunch_selection_wins_over_widget_field() {
        val env = SnapshotEnvelope.parse(
            """{"event_type":"STATE_SNAPSHOT","state_seq":5,"show_lunch_selection":true,""" +
                """"widget":{"widget_name":"SPIKE","widget_data":{},"show_lunch_selection":false}}""",
            logger,
        )
        assertTrue(""""show_lunch_selection":true""" in env!!.toRunnerStateJson(), env.toRunnerStateJson())
    }

    @Test
    fun toRunnerStateJson_absent_show_lunch_selection_serializes_null() {
        val raw = envelope(seq = 9).toRunnerStateJson()
        assertTrue(""""show_lunch_selection":null""" in raw, raw)
    }

    @Test
    fun tier_nudge_sibling_survives_parse_and_reconstruction() {
        // The backend sends `tier_nudge` as a top-level current_state sibling over MQTT.
        // It must survive parse → toRunnerStateJson so TieringDataSource (reading
        // RunnerStateStore.envelope) sees it on the MQTT cohort — not only on polling
        // (where Dart forwards the whole raw envelope). Regression guard for the drop.
        val raw = """{"event_type":"STATE_SNAPSHOT","state_seq":5,""" +
            """"widget":{"widget_name":"RUNNER_JOB_IN_PROGRESS","widget_data":{}},""" +
            """"tier_nudge":{"nudge_name":"PERFECT_JOB","nudge_details":{"coin_amount":2}}}"""
        val out = SnapshotEnvelope.parse(raw, logger)!!.toRunnerStateJson()
        assertTrue(""""tier_nudge"""" in out, out)
        assertTrue(""""nudge_name":"PERFECT_JOB"""" in out, out)
    }
}
