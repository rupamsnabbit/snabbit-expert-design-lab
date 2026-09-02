import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

/// Request model for the "verify check-in by phone number" API.
///
/// All fields are nullable by convention.
class CheckInWithoutOtpRequestModel {
  /// Phone number used for booking.
  final String? phoneNumber;
  final double? lat;
  final double? long;

  /// Creates a request payload for verifying check-in.
  const CheckInWithoutOtpRequestModel({
    this.phoneNumber,
    this.lat,
    this.long,
  });

  /// Converts the model to JSON (snake_case keys).
  static Map<String, dynamic> toJson(CheckInWithoutOtpRequestModel model) {
    return {
      "customer_phone_no": model.phoneNumber,
      "location": {"lat": model.lat, "lng": model.long},
      "accuracy_meters": RemoteConfigService.instance.getNonZeroInt(
        RemoteConfigKeys.expertCheckinWithoutOtpLocationAccuracyBuffer,
        defaultValue: 25,
      )
    };
  }
}
