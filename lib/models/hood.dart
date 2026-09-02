class HotSpot {
  int id;
  String? name;
  bool? isActive;
  bool? isServiceable;
  double? lat;
  double? lng;
  Hood? hood;

  HotSpot({
    required this.id,
    this.name,
    this.isActive,
    this.isServiceable,
    this.lat,
    this.lng,
    this.hood,
  });

  factory HotSpot.fromMap(Map<String, dynamic> map) {
    return HotSpot(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'],
      isServiceable: map['is_serviceable'],
      lat: map['location'] != null ? map['location']['lat'] : null,
      lng: map['location'] != null ? map['location']['lng'] : null,
      hood: map['hood'] != null ? Hood.fromJson(map['hood']) : null,
    );
  }
}

class Hood {
  int id;
  String? name;
  bool? isActive;
  bool? isServiceable;
  Cluster? cluster;

  Hood({
    required this.id,
    this.name,
    this.isActive,
    this.isServiceable,
    this.cluster,
  });

  factory Hood.fromJson(Map<String, dynamic> json) {
    return Hood(
      id: json['id'],
      name: json['name'],
      isActive: json['is_active'],
      isServiceable: json['is_serviceable'],
      cluster:
          json['cluster'] != null ? Cluster.fromMap(json['cluster']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
      'is_serviceable': isServiceable,
    };
  }
}

class Cluster {
  int id;
  String? name;
  bool? isActive;
  bool? isServiceable;

  Cluster({
    required this.id,
    this.name,
    this.isActive,
    this.isServiceable,
  });

  factory Cluster.fromMap(Map<String, dynamic> map) {
    return Cluster(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'],
      isServiceable: map['is_serviceable'],
    );
  }
}
