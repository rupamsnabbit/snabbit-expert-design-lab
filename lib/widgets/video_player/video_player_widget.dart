import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:video_player/video_player.dart';

import 'full_screen_video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (widget.thumbnailUrl != null) {
      _initializePlayer();
    }
  }

  Widget getActionButton() {
    return CircleAvatar(
      backgroundColor: AppColors.brand,
      radius: 39.r,
      child: IconButton(
        alignment: Alignment.center,
        padding: EdgeInsets.zero,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenVideoPlayer(
                videoUrl: widget.videoUrl,
              ),
            ),
          );
        },
        icon: Icon(
          Icons.play_arrow_rounded,
          color: const Color(0xFFDFDFDD),
          size: 72.r,
        ),
      ),
    );
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController =
        VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoPlayerController.initialize();
    setState(() {
      _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: false,
          looping: false,
          aspectRatio: _videoPlayerController.value.aspectRatio,
          showControls: false,
          showOptions: false,
          // Turn off options
          allowFullScreen: true,
          // Turn off full screen button
          showControlsOnInitialize: false,
          allowedScreenSleep: false,
          overlay: Center(
            child: getActionButton(),
          ));
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Widget chewiePlayer() {
    return _chewieController != null
        ? Chewie(controller: _chewieController!)
        : const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    return widget.thumbnailUrl != null
        ? Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return chewiePlayer();
                  },
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: getActionButton(),
              )
            ],
          )
        : chewiePlayer();
  }
}
