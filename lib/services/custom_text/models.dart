class CustomTextStyle {
  final String? name;
  final double? fontSize;
  final String? color;
  final int? weight;
  final String? style; // e.g., 'italic', 'normal', etc.

  CustomTextStyle({
    this.name,
    this.fontSize,
    this.color,
    this.weight,
    this.style,
  });

  factory CustomTextStyle.fromMap(Map<String, dynamic> map) {
    return CustomTextStyle(
      name: map['name'],
      fontSize: map['font_size']?.toDouble(),
      color: map['color'],
      weight: map['weight'],
      style: map['style'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'font_size': fontSize,
      'color': color,
      'weight': weight,
      'style': style,
    };
  }
}

class CustomTextData {
  final String key;
  final String? text;
  final CustomTextStyle? style;

  CustomTextData({
    required this.key,
    this.text,
    this.style,
  });

  factory CustomTextData.fromMap(Map<String, dynamic> map) {
    return CustomTextData(
      key: map['key'] ?? '',
      text: map['text'],
      style:
          map['style'] != null ? CustomTextStyle.fromMap(map['style']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'text': text,
      'style': style?.toMap(),
    };
  }
}

class CustomTextConfig {
  final String? key;
  final String? text;
  final CustomTextStyle? style;
  final List<CustomTextData> data;
  final String? alignment;

  CustomTextConfig({
    this.key,
    this.text,
    this.style,
    required this.data,
    this.alignment,
  });

  factory CustomTextConfig.fromMap(Map<String, dynamic> map) {
    return CustomTextConfig(
      key: map['key'],
      text: map['text'],
      style:
          map['style'] != null ? CustomTextStyle.fromMap(map['style']) : null,
      data: map['data'] != null
          ? List<CustomTextData>.from(
              map['data'].map((x) => CustomTextData.fromMap(x)))
          : [],
      alignment: map['alignment'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'text': text,
      'style': style?.toMap(),
      'data': data.map((x) => x.toMap()).toList(),
      'alignment': alignment,
    };
  }
}
