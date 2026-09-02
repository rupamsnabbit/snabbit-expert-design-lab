class RunnerVideoTileData {
  int? crossAxisCellCount;
  int? mainAxisCellCount;
  String? thumbnailUrl;
  String? videoUrl;

  RunnerVideoTileData({
    this.crossAxisCellCount,
    this.mainAxisCellCount,
    this.thumbnailUrl,
    this.videoUrl,
  });

  // Constructor from JSON (factory)
  factory RunnerVideoTileData.fromJson(Map<String, dynamic> json) {
    return RunnerVideoTileData(
      crossAxisCellCount: json['cross_axis_cell_count'] as int?,
      mainAxisCellCount: json['main_axis_cell_count'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      videoUrl: json['video_url'] as String?,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'cross_axis_cell_count': crossAxisCellCount,
      'main_axis_cell_count': mainAxisCellCount,
      'thumbnail_url': thumbnailUrl,
      'video_url': videoUrl,
    };
  }
}