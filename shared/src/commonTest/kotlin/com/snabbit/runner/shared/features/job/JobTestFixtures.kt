package com.snabbit.runner.shared.features.job

import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject

/** Lenient parser matching the bridge's, for building test envelopes. */
internal val testJson = Json {
    ignoreUnknownKeys = true
    isLenient = true
}

/** Builds a [RunnerState] from a widget name + raw `widget_data` JSON. */
internal fun envelope(widgetName: String, widgetData: String): RunnerState =
    RunnerState(
        widgetName = widgetName,
        widgetData = testJson.parseToJsonElement(widgetData).jsonObject,
    )

/** A representative `RUNNER_NEW_JOB` envelope mirroring the Figma "New Job" sample. */
internal const val NEW_JOB_JSON = """
{
  "job_id": 739,
  "is_deniable": true,
  "is_last_hour_job": false,
  "show_deallocation_warning": false,
  "notified_at": "2026-06-27T10:00:00+05:30",
  "timer_duration": 120,
  "deny_rate": 30,
  "loss_amount": 50,
  "address": "102, tower 2, Regent Hill",
  "geo_address": "Purva Fountain Sq",
  "is_long_distance": false,
  "payout_info": {
    "total_earning": 150,
    "check_in_amount": 5,
    "check_in_time": "2026-06-27T19:45:00+05:30",
    "breakdown": [
      {"title": {"key": "work_earnings", "default_text": "Work (1 hour)"}, "amount": 120},
      {"title": {"key": "summer_bonus", "default_text": "Summer Bonus"}, "pill_text": "1 hour", "amount": 20},
      {"title": {"key": "ot_bonus", "default_text": "OT (15 min)"}, "amount": 40}
    ]
  }
}
"""

/** A representative `RUNNER_JOB_IN_PROGRESS` envelope mirroring the Figma "Job In Progress" sample. */
internal const val IN_PROGRESS_JSON = """
{
  "job_id": 739,
  "customer_name": "Radhika S",
  "customer_ph_no": "9876543210",
  "start_time": "2026-06-27T10:00:00+05:30",
  "end_time": "2026-06-27T11:00:00+05:30",
  "duration": 60,
  "checkout_before_mins": 5,
  "auto_checkout_seconds": 600,
  "next_job_ready": true,
  "show_checkout_otp": true,
  "cash_to_be_collected": false,
  "cooking_preference": {
    "spice_level": {"title": "Spice level", "value": "Low"},
    "oil_level": {"title": "Oil level", "value": "Medium"}
  }
}
"""

/** A representative `RUNNER_POST_CHECKOUT` envelope mirroring the Figma "Job Completed" sample. */
internal const val POST_CHECKOUT_JSON = """
{
  "job_id": 739,
  "customer_id": 42,
  "customer_name": "Radhika S",
  "address": "HAL Old Airport Rd, Marathahalli, Bengaluru",
  "payout_info": {
    "total_earning": 150,
    "check_in_amount": 5,
    "check_in_time": "2026-06-27T19:45:00+05:30",
    "breakdown": [
      {"title": {"key": "work", "default_text": "Work (1 hour)"}, "amount": 120},
      {"title": {"key": "ot", "default_text": "OT (15 min)"}, "amount": 40}
    ]
  }
}
"""
