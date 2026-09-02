class ShiftInsight {
  final String imageUrl;
  final String statusImageUrl;
  final Map<String, dynamic>? label;
  final Map<String, dynamic>? subTitle;

  ShiftInsight({
    required this.imageUrl,
    required this.statusImageUrl,
    required this.label,
    this.subTitle,
  });

  factory ShiftInsight.fromJson(Map<String, dynamic> json) {
    return ShiftInsight(
      imageUrl: json['image_url'] ?? '',
      statusImageUrl: json['status_image_url'] ?? '',
      label: json['label'],
      subTitle: json['sub_title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image_url': imageUrl,
      'status_image_url': statusImageUrl,
      'label': label,
      'sub_title': subTitle,
    };
  }
}
