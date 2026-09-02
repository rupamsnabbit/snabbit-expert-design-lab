import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';

import '../../services/clevertap.dart';
import '../../utils/colors.dart';
import '../../utils/tracking_events.dart';

class AddressDetails extends StatefulWidget {
  final Map<String, dynamic>? widgetData;

  const AddressDetails({
    super.key,
    this.widgetData,
  });

  @override
  State<AddressDetails> createState() => _AddressDetailsState();
}

class _AddressDetailsState extends State<AddressDetails> {
  bool init = true;
  late LanguageProvider languageProvider;
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    setLanguage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
  }

  Future<void> _speakAddress() async {
    final address =
        "${widget.widgetData?["address"] ?? ""}\n${widget.widgetData?["geo_address"] ?? ""}";
    await flutterTts.speak(address);
    await ClevertapSetup.logEvent(TrackingEvents.speakAddressButtonClicked, {
      "action": "speak address button click",
    });
  }

  Future<void> setLanguage() async {
    await flutterTts.setLanguage("hi-IN");
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_pin,
          size: 30.sp,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            "${widget.widgetData?["address"] ?? ""}\n${widget.widgetData?["geo_address"] ?? ""}",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.n80,
                ),
          ),
        ),
        SizedBox(width: 16.w),
        OutlinedButton(
          onPressed: _speakAddress,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.n90,
            side: const BorderSide(color: AppColors.n40),
            padding: EdgeInsets.all(13.r),
          ),
          child: Row(
            children: [
              Text(
                languageProvider.getMessage(
                  'speak',
                  'Speak',
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.volume_up,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
