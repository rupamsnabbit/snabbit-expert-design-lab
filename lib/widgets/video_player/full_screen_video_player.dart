import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:video_player/video_player.dart';

import 'custom_chewie_controls.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const FullScreenVideoPlayer({super.key, required this.videoUrl});

  @override
  FullScreenVideoPlayerState createState() => FullScreenVideoPlayerState();
}

class FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _checkVideoCompletion() {
    if (_videoPlayerController.value.position >= _videoPlayerController.value.duration) {
      Navigator.pop(context); // Close the player when video completes
    }
  }


  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
      ),
    );
    await _videoPlayerController.initialize();
    // Listen for video completion and close the player
    _videoPlayerController.addListener(_checkVideoCompletion);

    setState(() {
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        zoomAndPan: true,
        // Autoplay in fullscreen
        looping: false,
        allowFullScreen: false,
        customControls: CustomChewieControls()
      );
    });
    _chewieController?.videoPlayerController.addListener(() {
      if (!_chewieController!.videoPlayerController.value.isPlaying &&
          _chewieController!.videoPlayerController.value.hasError) {
        _chewieController?.videoPlayerController.initialize();
      }
    });
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_checkVideoCompletion);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

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
      backgroundColor: AppColors.n0, // Optional: Set background color
      body: Container(
        alignment: Alignment.center,
        margin: EdgeInsets.fromLTRB(14.w, 0, 14.w, 20.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _videoPlayerController.value.isInitialized &&
                  _chewieController != null
              ? AspectRatio(
                  aspectRatio: 9 / 16,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoPlayerController.value.size.width,
                      height: _videoPlayerController.value.size.height,
                      child: Chewie(controller: _chewieController!),
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
