/// Enum representing the reason for SOS visibility state
enum SOSVisibilityReason {
  loggedIn("LOGGED_IN"),
  preLoginWindow("PRE_LOGIN_WINDOW"),
  postLogoutBuffer("POST_LOGOUT_BUFFER"),
  onLeave("ON_LEAVE"),
  noShiftToday("NO_SHIFT_TODAY"),
  outsideWindow("OUTSIDE_WINDOW"),
  postLogoutBufferExpired("POST_LOGOUT_BUFFER_EXPIRED"),
  shiftStartMissing("SHIFT_START_MISSING"),
  configDisabled("CONFIG_DISABLED");

  final String value;

  const SOSVisibilityReason(this.value);

  /// Factory method to create enum from string value
  /// Returns null if the string doesn't match any enum value
  static SOSVisibilityReason? fromString(String? reason) {
    if (reason == null) return null;
    for (SOSVisibilityReason enumValue in SOSVisibilityReason.values) {
      if (enumValue.value == reason) {
        return enumValue;
      }
    }
    return null;
  }
}

/// Model class representing SOS visibility configuration from current_state API
class SOSVisibility {
  /// Whether SOS button should be visible
  final bool? visible;

  /// Reason for the visibility state
  final SOSVisibilityReason? reason;

  /// Window end timestamp in ISO format
  final DateTime? windowEndTs;

  SOSVisibility({
    this.visible,
    this.reason,
    this.windowEndTs,
  });

  /// Factory constructor to create an [SOSVisibility] instance from a JSON map
  factory SOSVisibility.fromJson(Map<String, dynamic> json) {
    return SOSVisibility(
      visible: json['visible'],
      reason: SOSVisibilityReason.fromString(json['reason']),
      windowEndTs: DateTime.tryParse(json['window_end_ts'] ?? ''),
    );
  }
}
