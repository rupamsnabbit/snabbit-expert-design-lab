import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';

class LowBatteryWarning extends StatefulWidget {
  const LowBatteryWarning({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  State<LowBatteryWarning> createState() => _LowBatteryWarningState();
}

class _LowBatteryWarningState extends State<LowBatteryWarning> {
  late RunnerRtDataProvider runnerRtDataProvider;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    runnerRtDataProvider =
        Provider.of<RunnerRtDataProvider>(context, listen: true);
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
  }

  bool showWarning() {
    return runnerRtDataProvider.widgetInfo?.data != null &&
        runnerRtDataProvider.widgetInfo?.data?["battery_warning"] == true;
  }

  @override
  Widget build(BuildContext context) {
    return showWarning()
        ? Container(
            margin: widget.margin,
            padding: EdgeInsets.fromLTRB(17.r, 10.r, 6.r, 11.r),
            decoration: BoxDecoration(
              color: AppColors.r20,
              border: Border.all(
                color: AppColors.r50,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: <Widget>[
                Image.asset(
                  'assets/pngs/low_battery_warning.png',
                  height: 37.r,
                  width: 37.r,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        languageProvider.getMessage(
                            "battery_low", "Battery low!"),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.r50,
                        ),
                      ),
                      Text(
                        languageProvider.getMessage(
                            "battery_warning_message",
                            "Request customer to allow you to charge your phone"),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.r50,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : const SizedBox();
  }
}
