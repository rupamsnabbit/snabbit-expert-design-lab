import 'package:snabbit_runner/utils/common_methods.dart';

/// Item from GET `runners/me/active_services` (registration service picker).
/// Not the same as `Service` on `UserProfile` (the runner's stored chosen service).
class AvailableService {
  final int id;
  final String name;
  final String? imageUrl;
  final String? tag;

  AvailableService({
    required this.id,
    required this.name,
    this.imageUrl,
    this.tag,
  });

  factory AvailableService.fromMap(Map<String, dynamic> map) {
    return AvailableService(
      id: anyValueToInt(map['id']) ?? 0,
      name: map['name'] ?? '',
      imageUrl: map['image_url'] as String?,
      tag: map['tag'] as String?,
    );
  }

  static List<AvailableService> fromList(List<dynamic> list) {
    return list.map((e) => AvailableService.fromMap(e as Map<String, dynamic>)).toList();
  }
}
