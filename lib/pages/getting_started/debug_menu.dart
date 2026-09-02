import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/debug/runner_app_current_state_stubs.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/debug/chucker_debug.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/kmp_bridge.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';

class DebugMenu extends StatefulWidget {
  static const String routeName = "/debug_menu";

  const DebugMenu({super.key});

  @override
  State<DebugMenu> createState() => _DebugMenuState();
}

class _DebugMenuState extends State<DebugMenu> {
  String? selectedEnv;
  bool isCustomEnv = false;

  final TextEditingController _remoteUrlController = TextEditingController();
  final TextEditingController _onboardingUrlController =
      TextEditingController();
  final TextEditingController _atlasUrlController = TextEditingController();
  final TextEditingController _bffUrlController = TextEditingController();
  final TextEditingController _payoutsUrlController = TextEditingController();
  final TextEditingController _localWebviewUrlController =
      TextEditingController(text: 'https://');
  final TextEditingController _webviewCustomUrlController =
      TextEditingController();

  String _selectedWebviewEnv = 'PROD';

  OtpServiceProvider _selectedDebugOtpProvider = OtpServiceProvider.otpless;

  /// Debug sound-volume presets (label → override). 'Default (100%)' maps to
  /// null = no override (full volume + setMaxVolume active).
  static const Map<String, double?> _soundVolumePresets = {
    'Default (100%)': null,
    '50%': 0.5,
    '25%': 0.25,
    '10%': 0.1,
    'Mute (0%)': 0.0,
  };
  String _selectedSoundVolumePreset = 'Default (100%)';

  /// Chucker network-inspector in-app notification toggle + alignment, mirrored
  /// from SharedPreferences. Alignment is a preset key from
  /// [chuckerAlignmentLabels]. Applied via [applyChuckerDebugSettings].
  bool _chuckerShowNotification = false;
  String _selectedChuckerAlignment = 'bottomCenter';

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  RunnerAppCurrentStateStub? _selectedCurrentStateStub;

  // KMP bridge test
  String? _kmpResult;
  bool _kmpLoading = false;
  String? _kmpError;

  final Map<String, Env> _predefinedEnvs = {
    'PROD': prodEnv,
    'ALPHA': alphaEnv,
    'STAGING-ENV1': stagingEnv1,
    'STAGING-ENV3': stagingEnv3,
    'STAGING-ENV4': stagingEnv4,
    'KAVACH-TEST': kavachTestEnv,
    'DEV': devEnv,
    'LOCAL': localEnv,
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentEnvironment();
  }

  Future<void> _loadCurrentEnvironment() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEnv = prefs.getString('debug_selected_env');

    setState(() {
      if (savedEnv == 'CUSTOM') {
        isCustomEnv = true;
        selectedEnv = 'CUSTOM';
        _remoteUrlController.text =
            prefs.getString('debug_custom_remote_url') ?? '';
        _onboardingUrlController.text =
            prefs.getString('debug_custom_onboarding_url') ?? '';
        _atlasUrlController.text =
            prefs.getString('debug_custom_atlas_url') ?? '';
        _bffUrlController.text = prefs.getString('debug_custom_bff_url') ?? '';
        _payoutsUrlController.text =
            prefs.getString('debug_custom_payouts_url') ?? '';
      } else {
        selectedEnv = savedEnv ?? GlobalState().currentEnv.name;
        isCustomEnv = false;
      }

      final savedWebviewEnv = prefs.getString('debug_webview_env');
      if (savedWebviewEnv == 'CUSTOM') {
        _selectedWebviewEnv = 'CUSTOM';
        _webviewCustomUrlController.text =
            prefs.getString('debug_webview_base_url') ?? '';
      } else if (savedWebviewEnv != null &&
          webviewEnvUrls.containsKey(savedWebviewEnv)) {
        _selectedWebviewEnv = savedWebviewEnv;
      }

      final forceEdumarc = prefs.getBool('debug_force_edumarc_otp') ?? false;
      _selectedDebugOtpProvider = forceEdumarc
          ? OtpServiceProvider.edumarc
          : OtpServiceProvider.otpless;

      final soundVol = prefs.getDouble('debug_sound_volume');
      _selectedSoundVolumePreset = _soundVolumePresets.entries
          .firstWhere(
            (e) => e.value == soundVol,
            orElse: () => const MapEntry('Default (100%)', null),
          )
          .key;

      _chuckerShowNotification =
          prefs.getBool('debug_chucker_show_notification') ?? false;
      final savedAlignment =
          prefs.getString('debug_chucker_notification_alignment');
      _selectedChuckerAlignment =
          chuckerAlignmentLabels.containsKey(savedAlignment)
              ? savedAlignment!
              : 'bottomCenter';
    });
  }

  String? _validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL is required';
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }
    if (!value.endsWith('/')) {
      return 'URL must end with /';
    }
    return null;
  }

  Future<void> _applyEnvironment() async {
    if (isCustomEnv && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      if (isCustomEnv) {
        // Save custom environment
        await prefs.setString('debug_selected_env', 'CUSTOM');
        await prefs.setString(
            'debug_custom_remote_url', _remoteUrlController.text.trim());
        await prefs.setString('debug_custom_onboarding_url',
            _onboardingUrlController.text.trim());
        await prefs.setString(
            'debug_custom_atlas_url', _atlasUrlController.text.trim());
        await prefs.setString(
            'debug_custom_bff_url', _bffUrlController.text.trim());
        await prefs.setString(
            'debug_custom_payouts_url', _payoutsUrlController.text.trim());

        // Update GlobalState immediately
        GlobalState().currentEnv = Env(
          name: 'CUSTOM',
          remoteUrl: _remoteUrlController.text.trim(),
          onboardingUrl: _onboardingUrlController.text.trim(),
          atlasUrl: _atlasUrlController.text.trim(),
          bffUrl: _bffUrlController.text.trim(),
          payoutsUrl: _payoutsUrlController.text.trim(),
        );
      } else if (selectedEnv != null) {
        // Save predefined environment
        await prefs.setString('debug_selected_env', selectedEnv!);
        await prefs.remove('debug_custom_remote_url');
        await prefs.remove('debug_custom_onboarding_url');
        await prefs.remove('debug_custom_atlas_url');
        await prefs.remove('debug_custom_bff_url');
        await prefs.remove('debug_custom_payouts_url');

        // Update GlobalState immediately
        GlobalState().currentEnv = _predefinedEnvs[selectedEnv]!;
      }

      // Set flag to show toast on restart
      await prefs.setBool('debug_env_changed', true);

      if (mounted) {
        _restartApp();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving environment: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _restartApp() {
    // Clear navigation stack and restart app
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  /// Debug-only: open AppWebView with an arbitrary URL, bypassing the
  /// drawer menu's https-production-only gate. Used to exercise the bifrost
  /// against a local Vite dev server.
  void _openLocalWebview() {
    final url = _localWebviewUrlController.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid URL')),
      );
      return;
    }
    Navigator.of(context).pushNamed(
      AppWebViewPage.routeName,
      arguments: WebViewArgs(
        url: url,
        title: 'Local Webview',
      ),
    );
  }

  String? _validateWebviewUrl(String value) {
    if (value.isEmpty) return 'URL is required';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a valid URL';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'URL must use http:// or https://';
    }
    return null;
  }

  /// Base URL [buildWebviewUrl] would currently resolve to, plus its source,
  /// for the debug-menu status card.
  String _effectiveWebviewBaseUrl() {
    final override = GlobalState().debugWebviewBaseUrl;
    if (override != null && override.isNotEmpty) {
      return '$override\n(debug override)';
    }
    final rcUrl = RemoteConfigService.instance.getString(
      RemoteConfigKeys.webviewBaseUrl,
      defaultValue: defaultWebviewBaseUrl,
    );
    return '$rcUrl\n(Remote Config / default)';
  }

  Future<void> _applyWebviewEnv() async {
    final env = _selectedWebviewEnv;
    final String baseUrl;
    if (env == 'CUSTOM') {
      final custom = _webviewCustomUrlController.text.trim();
      final error = _validateWebviewUrl(custom);
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      baseUrl = custom;
    } else {
      baseUrl = webviewEnvUrls[env]!;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('debug_webview_env', env);
    await prefs.setString('debug_webview_base_url', baseUrl);
    if (!mounted) return;
    GlobalState().debugWebviewBaseUrl = baseUrl;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Webview environment set to $env')),
    );
  }

  Future<void> _resetWebviewEnv() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('debug_webview_env');
    await prefs.remove('debug_webview_base_url');
    if (!mounted) return;
    GlobalState().debugWebviewBaseUrl = null;
    setState(() {
      _selectedWebviewEnv = 'PROD';
      _webviewCustomUrlController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Webview override cleared — using Remote Config'),
      ),
    );
  }

  Future<void> _applyDebugOtpProvider() async {
    final forceEdumarc =
        _selectedDebugOtpProvider == OtpServiceProvider.edumarc;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_force_edumarc_otp', forceEdumarc);
    if (!mounted) return;
    GlobalState().debugForceEdumarcOtpProvider = forceEdumarc;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(forceEdumarc
            ? 'OTP override: forcing edumarc'
            : 'OTP override cleared — using app config'),
      ),
    );
  }

  String _otpOverrideStatus() {
    if (GlobalState().debugForceEdumarcOtpProvider) {
      return 'forcing edumarc (overrides app config)';
    }
    final fromAppConfig =
        GlobalState().appConfig?.otpServiceProvider.name ?? 'edumarc (default)';
    return 'no override — app config: $fromAppConfig';
  }

  Future<void> _applyDebugSoundVolume() async {
    final override = _soundVolumePresets[_selectedSoundVolumePreset];
    final prefs = await SharedPreferences.getInstance();
    if (override == null) {
      await prefs.remove('debug_sound_volume');
    } else {
      await prefs.setDouble('debug_sound_volume', override);
    }
    if (!mounted) return;
    GlobalState().debugSoundVolume = override;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(override == null
            ? 'Sound volume override cleared — full volume'
            : 'Sound volume set to $_selectedSoundVolumePreset'),
      ),
    );
  }

  String _soundVolumeStatus() {
    final v = GlobalState().debugSoundVolume;
    if (v == null) {
      return 'no override — full volume (setMaxVolume active)';
    }
    return '${(v * 100).round()}% — setMaxVolume disabled while active';
  }

  Future<void> _applyChuckerNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        'debug_chucker_show_notification', _chuckerShowNotification);
    await prefs.setString(
        'debug_chucker_notification_alignment', _selectedChuckerAlignment);
    GlobalState().debugChuckerShowNotification = _chuckerShowNotification;
    GlobalState().debugChuckerNotificationAlignment = _selectedChuckerAlignment;
    // Gated so the only chucker reference in this method is dead code in
    // release builds and tree-shaken out with the package.
    if (kDebugMode) {
      await applyChuckerDebugSettings();
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_chuckerShowNotification
            ? 'Network notification on — '
                '${chuckerAlignmentLabels[_selectedChuckerAlignment]}'
            : 'Network notification off'),
      ),
    );
  }

  String _chuckerNotificationStatus() {
    // Reflect the applied/saved state (GlobalState), not the unsaved dropdown/
    // switch selection — mirrors `_soundVolumeStatus`. Updates on Apply.
    if (!GlobalState().debugChuckerShowNotification) {
      return 'off — no in-app notification on requests';
    }
    final key = GlobalState().debugChuckerNotificationAlignment;
    return 'on — ${chuckerAlignmentLabels[key] ?? key}';
  }

  void _tryRefreshRunnerState() {
    try {
      Provider.of<RunnerRtDataProvider>(context, listen: false)
          .fetchCurrentState();
    } catch (_) {}
  }

  void _applyCurrentStateStub() {
    final stub = _selectedCurrentStateStub;
    if (stub == null) return;
    applyDebugRunnerAppCurrentStateStub(stub);
    _tryRefreshRunnerState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'current_state stub active: ${stub.debugTitle}. Polling refresh triggered.',
          ),
        ),
      );
    }
  }

  void _clearCurrentStateStub() {
    clearDebugRunnerAppCurrentStateStub();
    _tryRefreshRunnerState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('current_state stub cleared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Menu'),
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.n0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.r),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Environment',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Environment Dropdown
                    DropdownButtonFormField<String>(
                      value: isCustomEnv ? 'CUSTOM' : selectedEnv,
                      decoration: InputDecoration(
                        labelText: 'Environment',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 16.h,
                        ),
                      ),
                      isExpanded: true,
                      items: [
                        ..._predefinedEnvs.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          );
                        }),
                        DropdownMenuItem<String>(
                          value: 'CUSTOM',
                          child: Text(
                            'CUSTOM - Enter custom URLs',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          if (value == 'CUSTOM') {
                            isCustomEnv = true;
                            selectedEnv = 'CUSTOM';
                            // Pre-fill common URLs if fields are empty
                            if (_onboardingUrlController.text.isEmpty) {
                              _onboardingUrlController.text =
                                  'https://opero.stg.snabbit.net/';
                            }
                            if (_atlasUrlController.text.isEmpty) {
                              _atlasUrlController.text =
                                  'https://atlas-iot.stg.snabbit.net/';
                            }
                            if (_bffUrlController.text.isEmpty) {
                              _bffUrlController.text =
                                  'https://bff-service.stg.snabbit.net/api/';
                            }
                            if (_payoutsUrlController.text.isEmpty) {
                              _payoutsUrlController.text =
                                  'https://payout-service.stg.snabbit.net/';
                            }
                          } else {
                            isCustomEnv = false;
                            selectedEnv = value;
                          }
                        });
                      },
                    ),

                    // Show selected environment URL
                    if (!isCustomEnv && selectedEnv != null) ...[
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Text(
                          _predefinedEnvs[selectedEnv]?.remoteUrl ?? '',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.n60,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 16.h),

                    // Custom environment inputs
                    if (isCustomEnv) ...[
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: AppColors.n10,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: AppColors.n30),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter Custom Hosts',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12.h),

                            // Remote URL
                            Text(
                              'Remote URL',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            TextFormField(
                              controller: _remoteUrlController,
                              decoration: InputDecoration(
                                hintText: 'http://192.168.1.1:8000/',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 12.h,
                                ),
                              ),
                              validator: _validateUrl,
                            ),
                            SizedBox(height: 16.h),

                            // Onboarding URL
                            Text(
                              'Onboarding URL',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            TextFormField(
                              controller: _onboardingUrlController,
                              decoration: InputDecoration(
                                hintText: 'http://192.168.1.2:8080/',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 12.h,
                                ),
                              ),
                              validator: _validateUrl,
                            ),
                            SizedBox(height: 16.h),

                            // Atlas URL
                            Text(
                              'Atlas URL',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            TextFormField(
                              controller: _atlasUrlController,
                              decoration: InputDecoration(
                                hintText:
                                    'https://atlas-iot.stg.snabbit.net/',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 12.h,
                                ),
                              ),
                              validator: _validateUrl,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'BFF URL',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            TextFormField(
                              controller: _bffUrlController,
                              decoration: InputDecoration(
                                hintText:
                                    'https://bff-service.stg.snabbit.net/api/',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 12.h,
                                ),
                              ),
                              validator: _validateUrl,
                            ),
                            SizedBox(height: 16.h),

                            // Payouts URL
                            Text(
                              'Payouts URL',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            TextFormField(
                              controller: _payoutsUrlController,
                              decoration: InputDecoration(
                                hintText:
                                    'https://payout-service.stg.snabbit.net/',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 12.h,
                                ),
                              ),
                              validator: _validateUrl,
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 24.h),

                    // Apply button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _applyEnvironment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Apply and Restart',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.n20,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // KMP Bridge Test
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KMP Shared Module',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _kmpLoading
                                  ? null
                                  : () async {
                                      setState(() {
                                        _kmpLoading = true;
                                        _kmpResult = null;
                                        _kmpError = null;
                                      });
                                      try {
                                        final result =
                                            await KmpBridge.getHelloMessage();
                                        setState(() {
                                          _kmpResult = result;
                                        });
                                      } catch (e) {
                                        setState(() {
                                          _kmpError = e.toString();
                                        });
                                      } finally {
                                        setState(() {
                                          _kmpLoading = false;
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: _kmpLoading
                                  ? SizedBox(
                                      height: 16.h,
                                      width: 16.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Test KMP Bridge',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          if (_kmpResult != null) ...[
                            SizedBox(height: 8.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(10.r),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6.r),
                                border:
                                    Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Text(
                                _kmpResult!,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                          if (_kmpError != null) ...[
                            SizedBox(height: 8.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(10.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6.r),
                                border:
                                    Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Text(
                                _kmpError!,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Current environment info
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: AppColors.n50,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Active Environment:',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.n90,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            GlobalState().currentEnv.name,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Remote: ${GlobalState().currentEnv.remoteUrl}',
                            style: TextStyle(
                                fontSize: 11.sp, color: AppColors.n80),
                          ),
                          Text(
                            'Onboarding: ${GlobalState().currentEnv.onboardingUrl}',
                            style: TextStyle(
                                fontSize: 11.sp, color: AppColors.n80),
                          ),
                          Text(
                            'Atlas: ${GlobalState().currentEnv.atlasUrl}',
                            style: TextStyle(
                                fontSize: 11.sp, color: AppColors.n80),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),
                    const Divider(),
                    SizedBox(height: 16.h),

                    // ── Select Webview Environment ─────────────────────
                    Text(
                      'Select Webview Environment',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Base URL for all in-app webview routes (payouts, '
                      'etc.). Independent of the app environment above; '
                      'applies to the next webview opened — no restart.',
                      style: TextStyle(fontSize: 12.sp, color: AppColors.n80),
                    ),
                    SizedBox(height: 16.h),
                    DropdownButtonFormField<String>(
                      value: _selectedWebviewEnv,
                      decoration: InputDecoration(
                        labelText: 'Webview Environment',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 16.h,
                        ),
                      ),
                      isExpanded: true,
                      items: [
                        ...webviewEnvUrls.keys.map(
                          (name) => DropdownMenuItem<String>(
                            value: name,
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                        DropdownMenuItem<String>(
                          value: 'CUSTOM',
                          child: Text(
                            'CUSTOM - Enter custom URL',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedWebviewEnv = value);
                      },
                    ),
                    if (_selectedWebviewEnv != 'CUSTOM') ...[
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Text(
                          webviewEnvUrls[_selectedWebviewEnv] ?? '',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.n60,
                          ),
                        ),
                      ),
                    ],
                    if (_selectedWebviewEnv == 'CUSTOM') ...[
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: _webviewCustomUrlController,
                        decoration: InputDecoration(
                          labelText: 'Custom Webview URL',
                          hintText: 'https://your-dev-webapp.example.com/',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 16.h,
                          ),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                    ],
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _applyWebviewEnv,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: AppColors.n0,
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resetWebviewEnv,
                            child: const Text('Reset to Remote Config'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: AppColors.n50,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Effective Webview Base URL:',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.n90,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _effectiveWebviewBaseUrl(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.n80,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),
                    const Divider(),
                    SizedBox(height: 16.h),

                    // ── Select Debug OTP Provider ──────────────────────
                    Text(
                      'Select Debug OTP Provider',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Debug builds only. Pick `edumarc` to force OTP flows '
                      'down the traditional/edumarc HTTP path instead of '
                      'OTPless. `otpless` means no override — app config is '
                      'used as-is.',
                      style: TextStyle(fontSize: 12.sp, color: AppColors.n80),
                    ),
                    SizedBox(height: 16.h),
                    DropdownButtonFormField<OtpServiceProvider>(
                      value: _selectedDebugOtpProvider,
                      decoration: InputDecoration(
                        labelText: 'OTP Provider',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 16.h,
                        ),
                      ),
                      isExpanded: true,
                      items: const [
                        OtpServiceProvider.otpless,
                        OtpServiceProvider.edumarc,
                      ]
                          .map(
                            (p) => DropdownMenuItem<OtpServiceProvider>(
                              value: p,
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedDebugOtpProvider = value);
                      },
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _applyDebugOtpProvider,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: AppColors.n0,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: AppColors.n50,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OTP Override Status:',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.n90,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _otpOverrideStatus(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.n80,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),
                    const Divider(),
                    SizedBox(height: 16.h),

                    // ── Network Inspector (debug builds only) ──────────
                    // Gated so chucker_flutter tree-shakes out of release:
                    // with kDebugMode const-false this block — the only
                    // remaining chucker reference — is eliminated.
                    if (kDebugMode) ...[
                      Text(
                        'Network Inspector',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Debug builds only. Inspect API calls (method, URL, '
                        'headers, request/response, status, timing) made through '
                        'HttpService. Opens the Chucker inspector.',
                        style: TextStyle(fontSize: 12.sp, color: AppColors.n80),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => ChuckerFlutter.showChuckerScreen(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: AppColors.n0,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Open Network Inspector',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        'Request Notification',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Show a floating notification for each API call, with '
                        'its method, status and timing. Tap Apply to save.',
                        style: TextStyle(fontSize: 12.sp, color: AppColors.n80),
                      ),
                      SizedBox(height: 8.h),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Show notification',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: _chuckerShowNotification,
                        activeThumbColor: AppColors.brand,
                        onChanged: (value) =>
                            setState(() => _chuckerShowNotification = value),
                      ),
                      SizedBox(height: 12.h),
                      DropdownButtonFormField<String>(
                        value: _selectedChuckerAlignment,
                        decoration: InputDecoration(
                          labelText: 'Notification alignment',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 16.h,
                          ),
                        ),
                        isExpanded: true,
                        items: chuckerAlignmentLabels.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedChuckerAlignment = value);
                        },
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _applyChuckerNotificationSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: AppColors.n0,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Apply',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: AppColors.n50,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification Status:',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.n90,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              _chuckerNotificationStatus(),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.n80,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32.h),
                      const Divider(),
                      SizedBox(height: 16.h),
                    ],
                    // ── Sound Volume (debug) ───────────────────────────
                    Text(
                      'Sound Volume (debug)',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Debug builds only. Lowers all in-app sound playback '
                      '(job ringtone, notifications) and stops the app from '
                      'forcing device volume to max. Default (100%) restores '
                      'normal behaviour.',
                      style: TextStyle(fontSize: 12.sp, color: AppColors.n80),
                    ),
                    SizedBox(height: 16.h),
                    DropdownButtonFormField<String>(
                      value: _selectedSoundVolumePreset,
                      decoration: InputDecoration(
                        labelText: 'Sound Volume',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 16.h,
                        ),
                      ),
                      isExpanded: true,
                      items: _soundVolumePresets.keys
                          .map(
                            (label) => DropdownMenuItem<String>(
                              value: label,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedSoundVolumePreset = value);
                      },
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _applyDebugSoundVolume,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: AppColors.n0,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: AppColors.n50,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sound Volume Status:',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.n90,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _soundVolumeStatus(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.n80,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),
                    const Divider(),
                    SizedBox(height: 16.h),

                    // ── Webview Bifrost local test ─────────────────────
                    Text(
                      'Webview Bifrost — Local Test',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Paste the Vite dev-server HTTPS URL '
                      '(e.g. https://192.168.x.x:5173) and tap Open. '
                      'You will see a self-signed cert warning — accept it.',
                      style: TextStyle(fontSize: 12.sp, color: AppColors.n80),
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: _localWebviewUrlController,
                      decoration: InputDecoration(
                        labelText: 'Local Webview URL',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 16.h,
                        ),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openLocalWebview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          'Open Local Webview',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.n20,
                          ),
                        ),
                      ),
                    ),
                    if (kDebugMode) ...[
                      SizedBox(height: 24.h),
                      Text(
                        'current_state API stub',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Debug only: replaces GET …/runners/me/app/current_state until cleared.',
                        style: TextStyle(fontSize: 12.sp, color: AppColors.n60),
                      ),
                      SizedBox(height: 12.h),
                      DropdownButtonFormField<RunnerAppCurrentStateStub>(
                        value: _selectedCurrentStateStub,
                        decoration: InputDecoration(
                          labelText: 'Stub preset',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 16.h,
                          ),
                        ),
                        isExpanded: true,
                        items: RunnerAppCurrentStateStub.values
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e.debugTitle,
                                  style: TextStyle(fontSize: 13.sp),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedCurrentStateStub = v);
                        },
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _selectedCurrentStateStub == null
                                  ? null
                                  : _applyCurrentStateStub,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: AppColors.n0,
                              ),
                              child: const Text('Apply stub'),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _clearCurrentStateStub,
                              child: const Text('Clear stub'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _remoteUrlController.dispose();
    _onboardingUrlController.dispose();
    _atlasUrlController.dispose();
    _bffUrlController.dispose();
    _payoutsUrlController.dispose();
    _localWebviewUrlController.dispose();
    _webviewCustomUrlController.dispose();
    super.dispose();
  }
}
