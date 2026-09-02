import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/widgets/insurance_support/claim_insurance_card.dart';
import 'package:snabbit_runner/widgets/insurance_support/congratulatory_card.dart';
import 'package:snabbit_runner/widgets/insurance_support/section_heading.dart';

import 'upgrade_to_tier_card.dart';

class TierBenefits extends StatefulWidget {
  const TierBenefits({super.key});

  @override
  State<TierBenefits> createState() => _TierBenefitsState();
}

class _TierBenefitsState extends State<TierBenefits> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeading(),
        SizedBox(height: 16.h,),
        ClaimInsuranceCard(),
        SizedBox(height: 24.h,),
        UpgradeToTierCard(),
        CongratulatoryCard(),
      ],
    );
  }
}
