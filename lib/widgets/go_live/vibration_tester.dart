import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/main.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:vibration/vibration.dart';

class VibrationTester extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onFailure;

  const VibrationTester(
      {super.key, required this.onSuccess, required this.onFailure});

  @override
  State<VibrationTester> createState() => _VibrationTesterState();
}

class _VibrationTesterState extends State<VibrationTester> {
  bool _hasPlayed = false;
  bool _isPlaying = false;
  int? _vibrationCount;
  int? _selectedAnswer;

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

  Future<void> _playVibration() async {
    try {
      setState(() {
        _hasPlayed = false;
        _isPlaying = true;
        _selectedAnswer = null;
      });
      final random = Random();
      final count = random.nextInt(4) + 1;
      _vibrationCount = count;
      for (int i = 0; i < count; i++) {
        await Vibration.vibrate();
        if (i < count - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      setState(() {
        _hasPlayed = true;
        _isPlaying = false;
      });
    } catch (e) {
      showSnackbar(
          context,
          languageProvider.getMessage(
              'vibration_playback_error', 'Error playing vibration'));
      setState(() {
        _isPlaying = false;
      });
      widget.onFailure();
    }
  }

  Widget _buildVibrationCircle() {
    return Container(
      width: 139.h,
      height: 139.w,
      decoration: const BoxDecoration(
        color: AppColors.n40,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.vibration,
          size: 70,
          color: Colors.black.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildBeforePlaying() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVibrationCircle(),
        const SizedBox(height: 16),
        Text(
          'Please note number of vibrations',
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 16.sp,
            letterSpacing: -1,
            color: Color(0xFF4E5969),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isPlaying ? null : _playVibration,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            elevation: 0,
          ),
          child: FittedBox(
            child: Text(
              languageProvider.getMessage('click_to_play', 'Click to play'),
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 16.sp,
                letterSpacing: -1,
                color: AppColors.n0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerButton(int value) {
    final bool isSelected = _selectedAnswer == value;
    return GestureDetector(
      onTap: _isPlaying || !_hasPlayed
          ? null
          : () {
              setState(() {
                _selectedAnswer = value;
              });
              if (value == _vibrationCount) {
                widget.onSuccess();
              } else {
                widget.onFailure();
              }
            },
      child: Container(
        // width: 43,
        // height: 32,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : Colors.transparent,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          value.toString(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 16.sp,
                letterSpacing: -1,
                color: isSelected ? AppColors.n0 : const Color(0xFF4E5969),
              ),
        ),
      ),
    );
  }

  Widget _buildAfterPlaying() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVibrationCircle(),
        SizedBox(height: 16.h),
        Flexible(
          child: FittedBox(
            child: Text(
              languageProvider.getMessage('vibration_test_confirmation_message',
                  'How many times did it vibrate?'),
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 16.sp,
                letterSpacing: -1,
                color: Color(0xFF4E5969),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAnswerButton(1),
            const SizedBox(width: 12),
            _buildAnswerButton(2),
            const SizedBox(width: 12),
            _buildAnswerButton(3),
            const SizedBox(width: 12),
            _buildAnswerButton(4),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _isPlaying ? null : _playVibration,
          child: FittedBox(
            child: Text(
              languageProvider.getMessage('replay', 'Replay'),
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                letterSpacing: -1,
                color: const Color(0xFFFC4B9C),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        SizedBox(height: 4.h,),
        InkWell(
          onTap: widget.onSuccess,
          child: Text(
            languageProvider.getMessage('vibration_not_working','Vibration is not working',),
            style: textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.normal,
              fontWeight: FontWeight.w500,
              fontSize: 16.sp,
              height: 1.1875, // line-height: 19px / font-size: 16px
              letterSpacing: -1.0,
              decoration: TextDecoration.underline,
              color: AppColors.n70,
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _hasPlayed ? _buildAfterPlaying() : _buildBeforePlaying();
  }
}
