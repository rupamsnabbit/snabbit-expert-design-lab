package com.snabbit.runner.shared.features.gamification.domain.model

/**
 * Enum-like discriminators for the gamification system — the KMP port of Dart
 * `lib/models/gamification/gamification_constants.dart`.
 *
 * [NudgeKind] and [OutcomeStatus] are real enums (the UI switches on them and an
 * unrecognised value degrades to [NudgeKind.Unknown] / [OutcomeStatus.Unknown]).
 * [LifecycleActionTypes] and [CtaIds] stay **raw string constants**, mirroring
 * Dart: lifecycle types and cta ids are matched by value, and out-of-scope
 * values (AWOL, delayed check-in) plus any future BE additions must pass through
 * verbatim rather than collapse to an `Unknown` bucket.
 */

/** Values for `nudge_kind` on a pre-action nudge / sheet warning. */
enum class NudgeKind(val raw: String) {
    Opportunity("opportunity"),
    Risk("risk"),
    Bonus("bonus"),
    Unknown("");

    companion object {
        /** Case-sensitive to match the BE contract; blank / unrecognised → [Unknown]. */
        fun fromRaw(value: String?): NudgeKind =
            entries.firstOrNull { it.raw == value } ?: Unknown
    }
}

/** Values for `status` on a post-action outcome. Compared case-insensitively. */
enum class OutcomeStatus(val raw: String) {
    Reward("reward"),
    Penalty("penalty"),
    Waived("waived"),
    Unknown("");

    companion object {
        fun fromRaw(value: String?): OutcomeStatus =
            entries.firstOrNull { it.raw.equals(value?.trim(), ignoreCase = true) } ?: Unknown
    }
}

/**
 * All known `lifecycle_action_type` values across pre-action nudges, sheet
 * warnings, and post-action outcomes. Kept as raw strings (not an enum) so
 * unknown / out-of-scope values survive round-trips — see class doc.
 */
object LifecycleActionTypes {
    // Login / logout
    const val EARLY_LOGIN = "EARLY_LOGIN"
    const val LATE_LOGIN = "LATE_LOGIN"
    const val EARLY_LOGOUT = "EARLY_LOGOUT"

    // Job lifecycle
    const val LONG_DISTANCE = "LONG_DISTANCE"
    const val DEALLOCATION = "DEALLOCATION"
    const val EARLY_CHECKIN = "EARLY_CHECKIN"
    const val ACCEPT_JOB_PENALTY = "ACCEPT_JOB_PENALTY"

    // Emergency
    const val EMERGENCY_LOGOUT = "EMERGENCY_LOGOUT"

    // AWOL (out of scope for the KMP migration — parses, no KMP UI)
    const val AWOL_BREACH_PENALTY = "AWOL_BREACH_PENALTY"

    // Delayed check-in (out of scope for the KMP migration — parses, no KMP UI)
    const val DELAYED_CHECKIN_PENALTY = "DELAYED_CHECKIN_PENALTY"

    // Attendance sheet warnings
    const val FALSE_ATTENDANCE = "FALSE_ATTENDANCE"
    const val CONFIRM_MARK_PRESENT = "CONFIRM_MARK_PRESENT"
    const val PROVISIONAL_MARK_ABSENT = "PROVISIONAL_MARK_ABSENT"
}

/**
 * Known `cta_id` values in `cta_overrides`. Includes `check_in`, which is used
 * verbatim on the Dart job-accepted screen but is absent from Dart's `CtaId`
 * constants — folded in here so the KMP side has a single source of truth.
 */
object CtaIds {
    const val GO_BACK = "go_back"
    const val MARK_ABSENT = "mark_absent"
    const val MARK_PRESENT = "mark_present"
    const val LOGIN = "login"
    const val ACCEPT_JOB = "accept_job"
    const val CHECK_IN = "check_in"
    const val LOGOUT = "logout"
}
