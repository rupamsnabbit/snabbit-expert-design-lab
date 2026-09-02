/// The UI states that can be shown within the verify check-in bottom sheet.
enum CheckInWithoutOtpBottomSheetView {
  /// Default view that prompts the user to enter the booking phone number.
  enterPhoneNumber,

  /// Transient view shown while the API verification is in-flight.
  loading,

  /// View shown when verification succeeds.
  success,

  /// View shown when verification fails.
  failure,
}
