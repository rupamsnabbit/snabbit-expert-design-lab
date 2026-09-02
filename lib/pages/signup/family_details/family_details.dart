import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/family_details/family_details_married.dart';
import 'package:snabbit_runner/pages/signup/family_details/family_details_unmarried.dart';
import 'package:snabbit_runner/pages/signup/family_details/family_details_widowed.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/enums.dart';

import 'family_details_divorced.dart';

class FamilyDetails extends StatefulWidget {
  static const String routeName = "/family_details";

  const FamilyDetails({super.key});

  @override
  State<FamilyDetails> createState() => _FamilyDetailsState();
}

class _FamilyDetailsState extends State<FamilyDetails> {
  late UserProfileProvider userProfileProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      setState(() {
        init = false;
      });
    }
  }

  Widget getView() {
    switch (userProfileProvider.user?.maritalStatus) {
      case MaritalStatus.married:
        return const FamilyDetailsIfMarried();
      case MaritalStatus.divorced:
        return const FamilyDetailsIfDivorced();
      case MaritalStatus.widow:
        return const FamilyDetailsIfWidowed();
      default:
        return const FamilyDetailsIfUnmarried();
    }
  }

  @override
  Widget build(BuildContext context) {
    return init ? const CupertinoActivityIndicator() : getView();
  }
}
