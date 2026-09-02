import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';

import 'job_accepted.dart';

class AutoMarkArrival extends StatefulWidget {
  const AutoMarkArrival({super.key});

  @override
  State<AutoMarkArrival> createState() => _AutoMarkArrivalState();
}

class _AutoMarkArrivalState extends State<AutoMarkArrival> {
  late RunnerRtDataProvider runnerRtDataProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 16.h,
      ),
      child: Column(
        children: [
          Image.asset(
            AssetConstants.autoMarkArrival,
            height: 100.h,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 11.h,
              bottom: 15.h,
            ),
            child: Text(
              "You have arrived",
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 24,
                  ),
            ),
          ),
          Row(
            children: [
              JobAcceptedBottomActionButton(
                widgetData: runnerRtDataProvider.widgetInfo?.data,
                widgetName: runnerRtDataProvider.widgetInfo?.name,
                shouldPopFirst: true,
              ),
            ],
          )
        ],
      ),
    );
  }
}
