import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/runner_video_data.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/main.dart';
import 'package:snabbit_runner/models/runner_video_data.dart';
import 'package:snabbit_runner/models/runner_video_tile_data.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/http_service.dart';
import 'package:snabbit_runner/widgets/video_player/full_screen_video_player.dart';
import 'package:video_player/video_player.dart';

import '../utils/colors.dart';

class VideoService {

  Future<RunnerVideoData?> fetchVideos() async {
    try {
      final res = await getVideos();
      if(res?.statusCode==200 && res?.data!=null){
        return RunnerVideoData.fromJson(res?.data);
      }else{
        return null;
      }
    } catch (e) {
      // print("Error fetching videos: $e");
      return null;
    }
  }

  static Future<Response?> getVideos({
    Map<String, dynamic>? headers,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await HttpService().get(
        GlobalState().serverPath(
            "api/v1/runner_onboarding/video_configuration"),
        headers: headers ?? {},
      );
      return response;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }
}

