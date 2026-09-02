class TrainingCenter {
  final int id;
  final String? name;
  final String? address;
  final double? lat;
  final double? lng;

  TrainingCenter({
    required this.id,
    this.name,
    this.address,
    this.lat,
    this.lng,
  });

  factory TrainingCenter.fromJson(Map<String, dynamic> json) {
    return TrainingCenter(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      lat:
      json['location'] != null ? json['location']['lat']?.toDouble() : null,
      lng:
      json['location'] != null ? json['location']['lng']?.toDouble() : null,
    );
  }


  @override
  String toString() {
    return '$name';
  }

}