class TrainingDetailsData {
  final int? id;
  final String? name;
  final String? trainer;
  final DateTime? joiningDate;
  final List<DateTime>? availableDates;

  TrainingDetailsData({
    this.joiningDate,
    this.availableDates,
    this.id,
    this.name,
    this.trainer,
  });

  factory TrainingDetailsData.fromJson(Map<String, dynamic> json) {
    return TrainingDetailsData(
        id: json['id'],
        name: json['name'],
        trainer: json['trainer'],
        joiningDate: json['joining_date'] != null
            ? DateTime.tryParse(json['joining_date'])
            : null,
        availableDates: json['consecutive_days'] != null
            ? (json['consecutive_days'] as List<dynamic>?)
            ?.map((e) => DateTime.tryParse(e as String))
            .where((e) => e != null)
            .map((e) => e!)
            .toList() ??
            []
            : []);
  }
}