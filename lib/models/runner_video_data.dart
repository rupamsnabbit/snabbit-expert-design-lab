import 'package:snabbit_runner/models/runner_video_tile_data.dart';

class RunnerVideoData {
  int? crossAxisCount;
  double? mainAxisSpacing;
  double? crossAxisSpacing;
  List<RunnerVideoTileData>? videoTiles;

  RunnerVideoData({
    this.crossAxisCount,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.videoTiles,
  });

  // Constructor from JSON (factory)
  factory RunnerVideoData.fromJson(Map<String, dynamic> json) {
    var videoTilesList = json['video_tiles'] as List?;
    List<RunnerVideoTileData>? videoTiles;

    if (videoTilesList != null) {
      videoTiles = videoTilesList
          .map((tileJson) => RunnerVideoTileData.fromJson(tileJson))
          .toList();
    }

    return RunnerVideoData(
      crossAxisCount: json['cross_axis_count'] as int?,
      mainAxisSpacing: json['main_axis_spacing'] as double?,
      crossAxisSpacing: json['cross_axis_spacing'] as double?,
      videoTiles: videoTiles,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'cross_axis_count': crossAxisCount,
      'main_axis_spacing': mainAxisSpacing,
      'cross_axis_spacing': crossAxisSpacing,
      'video_tiles': videoTiles?.map((tile) => tile.toJson()).toList(),
    };
  }
}