import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:video_player/video_player.dart';

class CustomChewieControls extends StatefulWidget {
  @override
  _CustomChewieControlsState createState() => _CustomChewieControlsState();
}

class _CustomChewieControlsState extends State<CustomChewieControls> {


  @override
  Widget build(BuildContext context) {
    final chewieController = ChewieController.of(context);
    final videoController = chewieController.videoPlayerController;

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: videoController,
      builder: (context, value, child) {
        IconData icon;

        if (value.isPlaying) {
          icon = Icons.pause_rounded; // Show Pause button while playing
        } else if (value.position >= value.duration) {
          icon = Icons.play_arrow_rounded; // Reset to Play when video ends
        } else {
          icon = Icons.play_arrow_rounded; // Show Play button when paused
        }

        return Align(
          alignment: Alignment.center,
          child: IconButton(
            alignment: Alignment.center,
            padding: EdgeInsets.zero,
            onPressed: () {
              if (value.isPlaying) {
                videoController.pause();
              } else {
                videoController.play();
              }
            },
            icon: Icon(
              icon,
              color: AppColors.n0.withOpacity(0.5),
              size: 72,
            ),
          ),
        );
      },
    );
  }
}