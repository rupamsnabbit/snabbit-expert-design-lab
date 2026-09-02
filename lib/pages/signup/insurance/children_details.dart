import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/signup/insurance/multiple_child_details.dart';
import 'package:snabbit_runner/pages/signup/insurance/single_child_details.dart';
import 'package:snabbit_runner/providers/user_profile.dart';

class ChildrenDetails extends StatefulWidget {
  static const String routeName = "/children-details";

  const ChildrenDetails({super.key});

  @override
  State<ChildrenDetails> createState() => _ChildrenDetailsState();
}

class _ChildrenDetailsState extends State<ChildrenDetails> {
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
    if (userProfileProvider.user?.otherDetails?.numberOfChildren?.value == null) {
      return const SizedBox();
    }
    if ((userProfileProvider.user?.otherDetails?.numberOfChildren?.value)! > 1) {
      return const MultipleChildDetails();
    } else {
      return const SingleChildDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    return init ? const CupertinoActivityIndicator() : getView();
  }
}
