import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/sos.dart';

class SeeYouTomorrow extends StatefulWidget {
  const SeeYouTomorrow({
    super.key,
  });

  @override
  State<SeeYouTomorrow> createState() => _SeeYouTomorrowState();
}

class _SeeYouTomorrowState extends State<SeeYouTomorrow> {
  bool init = true;
  bool loading = true;

  late LanguageProvider languageProvider;

  Future<void> initProcess() async {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 16.h),
          Image.asset(
            'assets/See_you_tomorrow_filled.png',
            height: 150.r,
            width: 150.r,
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: Text(
                languageProvider.getMessage(
                    "see_you_tomorrow", "See you tomorrow!"),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
