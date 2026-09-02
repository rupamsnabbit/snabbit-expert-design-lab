import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/insurance_profile_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/enums.dart';

class SectionHeading extends StatefulWidget {
  const SectionHeading({super.key});

  @override
  State<SectionHeading> createState() => _SectionHeadingState();
}

class _SectionHeadingState extends State<SectionHeading> {
  late LanguageProvider languageProvider;
  late InsuranceProfileProvider insuranceProfileProvider;
  late UserProfileProvider userProfileProvider;
  bool loading = false;
  bool init = true;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      insuranceProfileProvider =
          Provider.of<InsuranceProfileProvider>(context, listen: true);
      userProfileProvider = Provider.of<UserProfileProvider>(context, listen: true);
      init = false;
    }
  }

  Tier? get tier => userProfileProvider.user?.tier;

  @override
  Widget build(BuildContext context) {
    if(insuranceProfileProvider.loading || tier == null || insuranceProfileProvider.insuranceProfile==null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Text("${tier?.normalizedDescription ?? ''} ${languageProvider.getMessage('tier_benefits', "Tier Benefits")}",
          style:  Theme.of(context)
            .textTheme
            .headlineLarge
            ?.copyWith(
          fontWeight: FontWeight.w700,
          height: 18 / 22,
          letterSpacing: -0.24,
        ),),
        SizedBox(width: 10.w,),
        SvgPicture.asset(AssetConstants.assuredCheck),
      ],
    );
  }
}
