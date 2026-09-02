import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class InfoBannerModel {
  RemoteImage? bgImage;
  RemoteImage? icon;
  String? title;
  String? subtitle;

  InfoBannerModel({
    this.bgImage,
    this.icon,
    this.title,
    this.subtitle,
  });

  factory InfoBannerModel.fromJson(Map<String, dynamic> json) {
    return InfoBannerModel(
      bgImage: json['bg'] != null ? RemoteImage.fromJson(json['bg']) : null,
      icon: json['icon'] != null ? RemoteImage.fromJson(json['icon']) : null,
      title: json['title'],
      subtitle: json['subtitle'],
    );
  }
}
