package com.snabbit.runner.shared.features.awol

import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject

/** Lenient parser matching the bridge's, for building test envelopes. */
internal val awolTestJson = Json {
    ignoreUnknownKeys = true
    isLenient = true
}

/**
 * Wraps a raw `awol` object JSON into a `current_state` envelope
 * (`widget_data.awol`) — the awol key rides beside whatever widget is current.
 */
internal fun awolEnvelope(awolJson: String, widgetName: String = "RUNNER_MARK_ATTENDANCE"): RunnerState =
    RunnerState(
        widgetName = widgetName,
        widgetData = awolTestJson.parseToJsonElement("""{"awol": $awolJson}""").jsonObject,
    )

/** A representative full breach payload — the live wire shape pinned by `AwolData.fromJson`. */
internal const val AWOL_BREACH_JSON = """
{
  "event_id": "evt-42",
  "state": "BREACH",
  "breach_count": 2,
  "detected_at": "2026-07-09T10:00:00+05:30",
  "countdown": {
    "remaining_seconds": 240,
    "total_seconds": 900,
    "trigger_at": "2026-07-09T10:15:00+05:30"
  },
  "hotspot": {"name": "HSR Layout", "latitude": 12.91, "longitude": 77.64},
  "title": {"key": "awol_breach_title", "default": "Return to {{hotspot}} within", "params": {"hotspot": "HSR Layout"}},
  "warning_text": {"key": "awol_breach_warning", "default": "Penalty if you don't return."},
  "badge_text": {"key": "awol_hotspot_breach_badge", "default": "HOTSPOT BREACH"},
  "consequences": [
    {"icon_url": "https://img/c1.png", "text": {"key": "c1", "default": "Red card"}},
    {"icon_url": "https://img/c2.png", "text": {"key": "c2", "default": "Blocked for {{hours}} hours", "params": {"hours": 4}}}
  ],
  "image_url": "https://img/map.png",
  "red_cards_total": 1
}
"""
