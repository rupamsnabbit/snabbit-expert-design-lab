import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:snabbit_runner/models/runner_video_tile_data.dart';
import 'package:snabbit_runner/pages/video_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/widgets/video_player/video_player_widget.dart';

class LearnMore extends StatefulWidget {
  static const String routeName = "/learn_more";

  const LearnMore({super.key});

  @override
  LearnMoreState createState() => LearnMoreState();
}

class LearnMoreState extends State<LearnMore> {
  final VideoService _videoService = VideoService();
  List<RunnerVideoTileData> _videoTiles = [];
  int? crossAxisCount;
  double? mainAxisSpacing;
  double? crossAxisSpacing;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
    });
    final videos = await _videoService.fetchVideos();
    if (videos != null) {
      setState(() {
        _videoTiles = videos.videoTiles ?? [];
        crossAxisCount = videos.crossAxisCount;
        mainAxisSpacing = videos.mainAxisSpacing;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

/*
  ///[getLoadingView] provides a shimmer effect while the videos are loading
  ///may change as required
  Widget getLoadingView() {
    return Padding(
        padding: EdgeInsets.all(12.r),
        child: StaggeredGrid.count(
            crossAxisCount: crossAxisCount ?? 4,
            mainAxisSpacing: mainAxisSpacing?.toDouble() ?? 4,
            crossAxisSpacing: 4,
            children: [
              StaggeredGridTile.count(
                crossAxisCellCount: 2,
                mainAxisCellCount: 2,
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.n10,
                      borderRadius: BorderRadius.circular(
                        12.r,
                      )),
                ).animate(
                  onPlay: (controller) => controller.loop(),
                  effects: [
                    const ShimmerEffect(
                        duration: Duration(milliseconds: 750),
                        colors: [AppColors.n10, AppColors.n50]),
                  ],
                ),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 2,
                mainAxisCellCount: 4,
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.n10,
                      borderRadius: BorderRadius.circular(
                        12.r,
                      )),
                ).animate(
                  onPlay: (controller) => controller.loop(),
                  effects: [
                    const ShimmerEffect(
                        duration: Duration(milliseconds: 750),
                        colors: [AppColors.n10, AppColors.n50]),
                  ],
                ),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 2,
                mainAxisCellCount: 2,
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.n10,
                      borderRadius: BorderRadius.circular(
                        12.r,
                      )),
                ).animate(
                  onPlay: (controller) => controller.loop(),
                  effects: [
                    const ShimmerEffect(
                        duration: Duration(milliseconds: 1200),
                        colors: [AppColors.n10, AppColors.n50]),
                  ],
                ),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 4,
                mainAxisCellCount: 2,
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.n10,
                      borderRadius: BorderRadius.circular(
                        12.r,
                      )),
                ).animate(
                  onPlay: (controller) => controller.loop(),
                  effects: [
                    const ShimmerEffect(
                        duration: Duration(milliseconds: 1200),
                        colors: [AppColors.n10, AppColors.n50]),
                  ],
                ),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 2,
                mainAxisCellCount: 2,
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.n10,
                      borderRadius: BorderRadius.circular(
                        12.r,
                      )),
                ).animate(
                  onPlay: (controller) => controller.loop(),
                  effects: [
                    const ShimmerEffect(
                        duration: Duration(milliseconds: 1200),
                        colors: [AppColors.n10, AppColors.n50]),
                  ],
                ),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 2,
                mainAxisCellCount: 2,
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.n10,
                      borderRadius: BorderRadius.circular(
                        12.r,
                      )),
                ).animate(onPlay: (controller) => controller.loop(), effects: [
                  const ShimmerEffect(
                      duration: Duration(milliseconds: 1200),
                      colors: [AppColors.n10, AppColors.n50]),
                ]),
              ),
            ]));
  }
*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.close,
              color: AppColors.n90,
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : _videoTiles.isEmpty == true
              ? const Center(child: Text("No videos found"))
              : Padding(
                  padding: EdgeInsets.all(12.r),
                  child: SingleChildScrollView(
                    child: StaggeredGrid.count(
                        crossAxisCount: crossAxisCount ?? 4,
                        mainAxisSpacing: mainAxisSpacing ?? 4,
                        crossAxisSpacing: 4,
                        children: _videoTiles
                            .map(
                              (videoTile) => StaggeredGridTile.count(
                                crossAxisCellCount:
                                    videoTile.crossAxisCellCount ?? 2,
                                mainAxisCellCount:
                                    videoTile.mainAxisCellCount ?? 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Color(0xFFDFDFDFDD),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: EdgeInsets.all(8.r),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: VideoPlayerWidget(
                                      videoUrl: videoTile.videoUrl ?? '',
                                      thumbnailUrl: videoTile.thumbnailUrl ?? '',
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList()),
                  ),
                ),
    );
  }
}
