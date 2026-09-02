import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/widgets/sos.dart';

class SOSActiveScreen extends StatefulWidget {
  final SOSProvider sosProvider;
  final bool isOnJob;
  final int? sosId;
  final String? sosSource;

  const SOSActiveScreen({
    super.key,
    required this.sosProvider,
    required this.isOnJob,
    this.sosId,
    this.sosSource,
  });

  @override
  State<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends State<SOSActiveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GlobalState().shieldAdapter?.logShieldEvent(
        TrackingEvents.expertShieldSosActiveLoad,
        {
          'is_on_job': widget.isOnJob,
          'sos_id': widget.sosId,
          'source': widget.sosSource ?? 'unknown',
        },
      );
    });
  }

  Future<void> _launchDialer() async {
    try {
      final String phone = widget.sosProvider.phoneNumber ??
          RemoteConfigService.instance.getString(
            RemoteConfigKeys.shieldSosFallbackPhone,
            defaultValue: "",
          );
      await CallUtils.handleCallInitiation(
        phoneNumber: phone,
        context: context,
        callSourceLabel: "SOS_ACTIVE_SCREEN",
        onFailure: ({e, st}) {
          MonitoringServiceHelper.logError("SOS_CALL_FAILED", {
            "error": e?.toString(),
            "stack_trace": st?.toString(),
          });
          MixpanelSetup.logEvent(
            TrackingEvents.failedToInitiateCallFromSOS,
            {},
          );
          if (!mounted) return;
          final lang = context.read<LanguageProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.getMessage('sos_call_failed',
                  'Unable to start the call. Please try again.')),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      );
    } catch (e, st) {
      MonitoringServiceHelper.logError("SOS_CALL_FAILED", {
        "error": e.toString(),
        "stack_trace": st.toString(),
      });
      MixpanelSetup.logEvent(
        TrackingEvents.failedToInitiateCallFromSOS,
        {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<LanguageProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Layer 1: Pink-to-white gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFB8B8), Colors.white],
                stops: [0.0, 0.5],
              ),
            ),
          ),

          // Layer 2: Dots pattern at top, fading out
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.transparent],
                stops: [0.5, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Image.asset(
                AssetConstants.shieldSosActiveDotsBg,
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),

          // Layer 3: Main content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 60.h),

                // Hero section: red concentric circles + siren
                SizedBox(
                  height: 350.r,
                  width: 350.r,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(350.r, 350.r),
                        painter: _SOSCirclesPainter(),
                      ),
                      Positioned(
                        bottom: 20.r,
                        child: Image.asset(
                          AssetConstants.shieldSirenIconLarge,
                          height: 200.r,
                          width: 200.r,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                Image.asset(
                  AssetConstants.shieldHalfCircles,
                  height: 37.h,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),

                // Elliptical pink glow below circles

                const Spacer(),

                // Title text
                Text(
                  lang.getMessage('shield_sos_active_title',
                      'Help is on the way.\nMove to a safe place.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF303030),
                    letterSpacing: -0.5,
                  ),
                ),

                SizedBox(height: 40.h),

                // Primary button: Call SOS Team
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: SizedBox(
                    height: 48.h,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        GlobalState().shieldAdapter?.logShieldEvent(
                          TrackingEvents.expertShieldSosActiveCallTeamCta,
                          {
                            'sos_id': widget.sosId,
                            'source': widget.sosSource ?? 'unknown',
                            'phone_number_available':
                                widget.sosProvider.phoneNumber != null,
                          },
                        );
                        MixpanelSetup.logEvent(
                          TrackingEvents.sosCallSupportClicked,
                          {
                            "phone_number_available":
                                widget.sosProvider.phoneNumber != null,
                          },
                        );
                        _launchDialer();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE63F3F),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 8.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            AssetConstants.phoneIcon,
                            height: 26.r,
                            width: 26.r,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            lang.getMessage(
                                'shield_sos_call_btn', 'Call SOS Team'),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                // Secondary button: I am safe, end SOS
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: SizedBox(
                    height: 48.h,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        GlobalState().shieldAdapter?.logShieldEvent(
                          TrackingEvents.expertShieldSosActiveEndSosCta,
                          {
                            'is_on_job': widget.isOnJob,
                            'sos_id': widget.sosId,
                            'source': widget.sosSource ?? 'unknown',
                          },
                        );
                        GlobalState().shieldAdapter?.deescalateSos();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF303030),
                        side: const BorderSide(
                            color: Color(0xFF303030), width: 2),
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 8.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('😊', style: TextStyle(fontSize: 26.sp)),
                          SizedBox(width: 8.w),
                          Text(
                            lang.getMessage(
                                'shield_sos_safe_btn', 'I am safe, end SOS'),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF303030),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40.h),
              ],
            ),
          ),

          // Layer 4: Kavach ribbon at top center
          Positioned(
            top: MediaQuery.of(context).padding.top + 40,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                AssetConstants.shieldBannerIcon,
                height: 40.h,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three concentric red circles with fading opacity for the SOS active screen.
class _SOSCirclesPainter extends CustomPainter {
  static const _color = Color(0xFFFEAAAA);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 228.h / 2);
    final radii = [size.width * 0.4, size.width * 0.36, size.width * 0.3];
    final opacities = [0.09, 0.08, 0.07];

    for (var i = 0; i < radii.length; i++) {
      final paint = Paint()
        ..color = _color.withValues(alpha: opacities[i])
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
