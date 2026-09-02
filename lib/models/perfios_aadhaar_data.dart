/// Display-only view of the Perfios `onShutdown` success payload, used to show
/// the runner their Aadhaar details on the re-KYC review screen before submit.
///
/// Parsing is defensive — any field may be absent. This model is **never**
/// re-serialized for the API; the raw Perfios JSON is posted as-is.
class PerfiosAadhaarData {
  final String? name;
  final String? dob;
  final String? gender;
  final String? address;
  final String? maskedAadhaarNumber;

  PerfiosAadhaarData({
    this.name,
    this.dob,
    this.gender,
    this.address,
    this.maskedAadhaarNumber,
  });

  factory PerfiosAadhaarData.fromJson(Map<String, dynamic> json) {
    return PerfiosAadhaarData(
      name: json['name']?.toString(),
      dob: json['dob']?.toString(),
      gender: json['gender']?.toString(),
      address: json['address']?.toString(),
      maskedAadhaarNumber: json['maskedAadhaarNumber']?.toString(),
    );
  }

  /// Whether any displayable field was parsed — drives whether the review
  /// screen shows the details block or a neutral fallback.
  bool get hasAnyData =>
      name != null ||
      dob != null ||
      gender != null ||
      address != null ||
      maskedAadhaarNumber != null;
}
