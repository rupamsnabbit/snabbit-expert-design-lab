import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class AudioTester extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onFailure;
  const AudioTester({super.key,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<AudioTester> createState() => _AudioTesterState();
}

class _AudioTesterState extends State<AudioTester> {
  bool _hasPlayed = false;
  bool _isPlaying = false;

  late LanguageProvider languageProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  Future<void> _playAudio() async {
    try {
      setState(() {
        _hasPlayed=false;
        _isPlaying = true;
      });
      FlutterVolumeController.setVolume(1.0,);
      AudioContextAndroid androidContext = const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType:
        AndroidContentType.sonification, // Use sonification for notifications
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gain,
      );
      await GlobalState().audioPlayer.play(AssetSource('custom_sound.wav'),
          volume: 1.0, ctx: AudioContext(android: androidContext));

       Future.delayed(const Duration(seconds: 2),() {
         setState(() {
           _hasPlayed = true;
           _isPlaying = false;
         });
       },);
    } catch (_){
      showSnackbar(context, languageProvider.getMessage('audio_playback_error', 'Error playing audio'));
      setState(() {
        _isPlaying = false;
      });
      widget.onFailure();
    }
  }

  Widget _buildCircle() {
    return Container(
      width: 139.r,
      height: 139.r,
      decoration: const BoxDecoration(
        color: AppColors.n40,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: SvgPicture.asset(AssetConstants.fluentSpeakerOutlined,
             color: Colors.black.withOpacity(0.2)),
      ),
    );
  }

  Widget _buildBeforePlaying() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCircle(),
        SizedBox(height: 16.h),
        Text(
          languageProvider.getMessage('click_play_to_start', 'Click play to start'),
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 16.sp,
            letterSpacing: -1,
            color: Color(0xFF4E5969),
          ),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: 111.w,
          child: ElevatedButton(
            onPressed: _isPlaying ? null : _playAudio,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 16.w),
              elevation: 0,
            ),
            child: FittedBox(
              child: Text(
                languageProvider.getMessage('play','Play'),
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 16.sp,
                  letterSpacing: -1,
                  color: AppColors.n0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAfterPlaying() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCircle(),
        SizedBox(height: 16.h),
        Text(
          languageProvider.getMessage('can_you_hear_the_audio','Can you hear the audio?'),
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 16.sp,
            letterSpacing: -1,
            color: const Color(0xFF4E5969),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _hasPlayed? widget.onFailure:null,
                child: Container(
                  width: 111,
                  height: 32,
                  // padding:
                  //     const EdgeInsets.symmetric(vertical: 6, horizontal: 45),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Text(
                      languageProvider.getMessage('no','No'),
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 16.sp,
                        letterSpacing: -1,
                        color: Color(0xFF4E5969),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 18.w),
              GestureDetector(
                onTap:_hasPlayed? widget.onSuccess:null,
                child: Container(
                  width: 111.w,
                  height: 32.h,
                  // padding:
                  //     const EdgeInsets.symmetric(vertical: 6, horizontal: 42),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Text(
                      languageProvider.getMessage('yes','Yes'),
                      style: textTheme.displayMedium?.copyWith(
                        fontSize: 16.sp,
                        letterSpacing: -1,
                        color: AppColors.n0, // White color for the text
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        GestureDetector(
          onTap: _isPlaying ? null : _playAudio,
          child: Text(
            languageProvider.getMessage('replay','Replay'),
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 16.sp,
              letterSpacing: -1,
              color: const Color(0xFFFC4B9C),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _hasPlayed ? _buildAfterPlaying() : _buildBeforePlaying();
  }
}
