import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/modules/snabbit_shield/snabbit_shield_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/pulse_dot.dart';

class SnabbitShieldCard extends StatefulWidget {
  const SnabbitShieldCard({
    super.key,
    this.onStartMonitoring,
  });

  final VoidCallback? onStartMonitoring;

  @override
  State<SnabbitShieldCard> createState() => _SnabbitShieldCardState();
}

class _SnabbitShieldCardState extends State<SnabbitShieldCard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final shield = context.watch<SnabbitShieldProvider>();
    final lang = context.read<LanguageProvider>();
    final isActive = shield.isShieldRecording && shield.monitoringAcknowledged;
    final isLowStorage = shield.isLowStorage;
    final showBanner = !isActive && isLowStorage;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        if (showBanner)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const _StorageWarningBanner(),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: showBanner ? 56.h : 0),
          child: Container(
            padding: EdgeInsets.only(top: 12.h, bottom: isActive ? 0 : 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEBFDFF),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.2193, 0.5653],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4366).withOpacity(0.04),
                  offset: Offset(0, 3.h),
                  blurRadius: 5.r,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 0.h),
                  child: SizedBox(
                    height: 40.h,
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: Image.asset(
                            'assets/pngs/shield_icon_small.png',
                            width: 36.r,
                            height: 36.r,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Snabbit',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.shieldBlue,
                                      fontSize: 16.sp,
                                      height: 18 / 16,
                                    ),
                              ),
                              Text(
                                lang.getMessage(
                                    'snabbit_shield_card_kavach', 'Kavach'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.shieldBlue,
                                      fontSize: 16.sp,
                                      height: 18 / 16,
                                    ),
                              ),
                              SizedBox(height: 2.h),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isActive
                              ? PulseDot(
                                  key: const ValueKey('pulse'),
                                  color: const Color(0xFF3559E9),
                                  size: 14.r,
                                )
                              : widget.onStartMonitoring != null
                                  ? FilledButton(
                                      key: const ValueKey('activate'),
                                      onPressed: isLowStorage
                                          ? null
                                          : () => widget.onStartMonitoring?.call(),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: isLowStorage
                                            ? AppColors.n50
                                            : const Color(0xFF1b7de9),
                                        disabledBackgroundColor: AppColors.n50,
                                        foregroundColor: AppColors.n0,
                                        disabledForegroundColor: AppColors.n0,
                                        minimumSize: Size.zero,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8.w, vertical: 4.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6.r),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/svgs/shield_play_icon.svg',
                                            width: 10.r,
                                            height: 10.r,
                                            color: AppColors.n0,
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            lang.getMessage(
                                                'snabbit_shield_card_activate',
                                                'Activate'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.n0,
                                                  height: 18 / 12,
                                                ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('empty'),
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isActive ? 1.0 : 0.0,
                    child: isActive
                        ? _WaveformWidget(amplitude: shield.amplitude)
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Fixed waveform animation matching React Safety Shield.
/// Uses Timer for target updates + AnimatedContainer spring for smooth transitions.
/// Bars are vertically centered (like React's items-center).
class _WaveformWidget extends StatefulWidget {
  const _WaveformWidget({this.amplitude = 0});

  final double amplitude;

  @override
  State<_WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<_WaveformWidget> {
  static const int _barCount = 50;
  static const double _minH = 8.0;
  static const double _maxH = 42.0;

  late List<double> _bars;
  Timer? _timer;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _bars = List.generate(_barCount, (_) => _rng.nextDouble() * 30 + 10);
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final t = DateTime.now().millisecondsSinceEpoch / 200.0;
    setState(() {
      for (var i = 0; i < _barCount; i++) {
        final wave = sin(t + i / 5) * 10;
        final noise = _rng.nextDouble() * 10 - 5;
        final target = 25.0 + wave + noise;
        _bars[i] = (_bars[i] + (target - _bars[i]) * 0.4).clamp(_minH, _maxH);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final containerH = 39.h;
    final barArea = containerH - 12.h;
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      height: containerH,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_barCount, (i) {
                final fraction = (_bars[i] / _maxH).clamp(0.16, 1.0);
                final h = fraction * barArea;

                const blue = Color(0xFF3559E9);
                const lightBlue = Color(0xFF1787F4);
                final baseColor = i.isEven ? blue : lightBlue;
                final opacity = (0.1 + 0.4 * fraction).clamp(0.2, 0.8);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  width: 3.w,
                  height: h,
                  margin: EdgeInsets.symmetric(horizontal: 1.5.w),
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(opacity),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageWarningBanner extends StatelessWidget {
  const _StorageWarningBanner();

  static const _accentColor = Color(0xFFE93544);

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    return GestureDetector(
      onTap: () => openAppSettings(),
      child: Container(
        padding:
            EdgeInsets.only(left: 12.w, right: 12.w, top: 12.h, bottom: 10.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12.r),
              bottomRight: Radius.circular(12.r)),
          gradient: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xFFFFFFFF), // #FFF at 20%
              Color(0xFFFFE5E5), // #FFE5E5 at 100%
            ],
            stops: [0.2, 1.0],
          ),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/pngs/storage_warning.png',
              width: 28.r,
              height: 28.r,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                lang.getMessage('snabbit_shield_storage_banner',
                    'Clear storage to enable safety recording.'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _accentColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14.sp,
                    ),
              ),
            ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right, size: 22.r, color: _accentColor),
          ],
        ),
      ),
    );
  }
}
