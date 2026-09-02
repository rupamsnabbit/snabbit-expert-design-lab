/// Centralised enum-like constants for the gamification system.
///
/// All string values that the BE sends as discriminators live here so they're
/// defined once and referenced everywhere — no hardcoded strings scattered
/// across widgets and services.

// ─── NudgeKind ──────────────────────────────────────────────────────────────

/// Values for `nudge_kind` on [PreActionNudge] / [SheetWarning].
class NudgeKind {
  NudgeKind._();

  static const String opportunity = 'opportunity';
  static const String risk = 'risk';
  static const String bonus = 'bonus';
}

// ─── OutcomeStatus ──────────────────────────────────────────────────────────

/// Values for `status` on [PostActionOutcome].
class OutcomeStatus {
  OutcomeStatus._();

  static const String reward = 'reward';
  static const String penalty = 'penalty';
  static const String waived = 'waived'; // compare case-insensitively
}

// ─── LifecycleActionType ────────────────────────────────────────────────────

/// All known `lifecycle_action_type` values across pre-action nudges,
/// sheet warnings, and post-action outcomes.
class LifecycleActionType {
  LifecycleActionType._();

  // Login / logout
  static const String earlyLogin = 'EARLY_LOGIN';
  static const String lateLogin = 'LATE_LOGIN';
  static const String earlyLogout = 'EARLY_LOGOUT';

  // Job lifecycle
  static const String longDistance = 'LONG_DISTANCE';
  static const String deallocation = 'DEALLOCATION';
  static const String earlyCheckin = 'EARLY_CHECKIN';
  static const String acceptJobPenalty = 'ACCEPT_JOB_PENALTY';

  // Emergency
  static const String emergencyLogout = 'EMERGENCY_LOGOUT';

  // AWOL
  static const String awolBreachPenalty = 'AWOL_BREACH_PENALTY';

  // Delayed check-in
  static const String delayedCheckinPenalty = 'DELAYED_CHECKIN_PENALTY';

  // Attendance sheet warnings
  static const String falseAttendance = 'FALSE_ATTENDANCE';
  static const String confirmMarkPresent = 'CONFIRM_MARK_PRESENT';
  static const String provisionalMarkAbsent = 'PROVISIONAL_MARK_ABSENT';
}

// ─── CtaId ──────────────────────────────────────────────────────────────────

/// Known `cta_id` values in `cta_overrides`.
class CtaId {
  CtaId._();

  static const String goBack = 'go_back';
  static const String markAbsent = 'mark_absent';
  static const String markPresent = 'mark_present';
  static const String login = 'login';
  static const String acceptJob = 'accept_job';
  static const String logout = 'logout';
}
