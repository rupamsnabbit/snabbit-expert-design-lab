import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/selfie_provider.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/job_login/selfie_login.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';

class AutoLoginSelfieCheck extends StatefulWidget {
  const AutoLoginSelfieCheck({super.key});

  @override
  State<AutoLoginSelfieCheck> createState() => _AutoLoginSelfieCheckState();
}

class _AutoLoginSelfieCheckState extends State<AutoLoginSelfieCheck>
    with SingleTickerProviderStateMixin {
  bool init = true;
  late final LoginSelfieProvider loginSelfieProvider;
  late final LanguageProvider languageProvider;
  late LoginSelfie loginSelfie;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      loginSelfieProvider =
          Provider.of<LoginSelfieProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(languageProvider.getMessage('selfie_check_title',
              "You were automatically logged in. Please take a selfie to continue")),
          SizedBox(height: 48.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final loginCtaProps = <String, dynamic>{
                  'timestamp': DateTime.now().toUtc().toIso8601String(),
                  'source': 'auto_login_selfie_check',
                };
                MixpanelSetup.logEvent(
                    TrackingEvents.loginCtaClick, loginCtaProps);
                final position = await fetchCurrentLocation();

                loginSelfie = LoginSelfie.fromMap(
                  {
                    'lat': position?.latitude,
                    'lng': position?.longitude,
                  },
                );
                loginSelfieProvider.selfie = loginSelfie;

                Navigator.of(context)
                    .pushNamed(SelfieForLogin.routeName)
                    .then((_) async {
                  if (context.mounted) {
                    final runnerRtDataProvider =
                        Provider.of<RunnerRtDataProvider>(context,
                            listen: false);
                    await runnerRtDataProvider.fetchDataNow();
                  }
                });
                await ClevertapSetup.logEvent(
                    TrackingEvents.jobLoginLoginButtonClicked, {
                  "action": "job login button clicked",
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.g40,
              ),
              child: Text(
                languageProvider.getMessage("login", 'Login'),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
