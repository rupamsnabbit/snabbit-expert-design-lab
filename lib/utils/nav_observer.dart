import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/tnc_accept.dart';
import 'package:snabbit_runner/pages/payout/payout_home.dart';
import 'package:snabbit_runner/pages/signup/insurance/children_details.dart';
import 'package:snabbit_runner/pages/signup/insurance/insurance_details_v2.dart';
import 'package:snabbit_runner/pages/signup/personal_details.dart';
import 'package:snabbit_runner/pages/signup/registration_code_v2.dart';
import 'package:snabbit_runner/pages/signup/review/personal_details_review_v3.dart';
import 'package:snabbit_runner/pages/signup/review/registration_review.dart';
import 'package:snabbit_runner/pages/signup/upload_documents_pan.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

import '../pages/signup/availability_details.dart';
import '../pages/signup/availability_details_2.dart';
import '../pages/signup/bank_details.dart';
import '../pages/signup/customer_service.dart';
import '../pages/signup/family_details/family_details.dart';
import '../pages/signup/insurance_details.dart';
import '../pages/signup/integrity_test.dart';
import '../pages/signup/prior_experience.dart';
import '../pages/signup/registration_code.dart';
import '../pages/signup/select_service.dart';
import '../pages/signup/upload_documents.dart';
import '../pages/signup/work_experience.dart';

/// App-wide observer for `RouteAware` subscribers (e.g. `AppWebViewPage`) that
/// need to know when a full-screen route above them is pushed or popped.
///
/// Typed to `PageRoute` on purpose: `RouteObserver` only notifies when both
/// the changed route and the revealed route are `PageRoute`s, so transient
/// overlays (`showDialog`/`showModalBottomSheet`, which are `PopupRoute`s) are
/// ignored. Registered in `MaterialApp.navigatorObservers` alongside
/// [NavObserver].
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

class NavObserver extends NavigatorObserver {
  static Route? currentRoute;
  static Route? prevRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    currentRoute = route;
    prevRoute = previousRoute;
    // handleRouteChange(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    currentRoute = previousRoute;
    prevRoute = route;
    handleRouteChange(previousRoute);
    handleCurrentRouteChange(route);
  }

  void handleCurrentRouteChange(Route<dynamic>? route) async {
    if (route == null) {
      return;
    }
    final routeName = route.settings.name;
    if ([
      SelectService.routeName,
      RegistrationCode.routeName,
      RegistrationCodeV2.routeName,
      PersonalDetails.routeName,
      FamilyDetails.routeName,
      PriorExperience.routeName,
      UploadDocuments.routeName,
      UploadDocumentsPan.routeName,
      BankDetails.routeName,
      InsuranceDetails.routeName,
      InsuranceDetailsV2.routeName,
      AvailabilityDetails.routeName,
      CustomerService.routeName,
      IntegrityTestWidget.routeName,
      AvailabilityDetails2.routeName,
      WorkExperience.routeName,
      RegistrationReview.routeName,
      PersonalDetailsReviewV3.routeName,
      TncAcceptPage.routeName,
      ChildrenDetails.routeName,
    ].contains(routeName)) {
      final userProfileProvider = Provider.of<UserProfileProvider>(
          route.navigator!.context,
          listen: false);
      userProfileProvider.loading = true;
      userProfileProvider.notifyUserListeners();
      userProfileProvider.registrationBackAction();
    }
  }

  void handleRouteChange(Route<dynamic>? route) async {
    if (route == null) {
      return;
    }

    final routeName = route.settings.name;
    if ((routeName != null && routeName == PayoutHome.routeName)) {
      try {
        final currentPeriodProvider = Provider.of<CurrentPeriodProvider>(
            route.navigator!.context,
            listen: false);
        final payoutProvider = Provider.of<PayoutProvider>(
            route.navigator!.context,
            listen: false);
        if (currentPeriodProvider.prevSelectedStartDate?.month !=
            currentPeriodProvider.monthStartDate.month) {
          updatePayoutHome(
            payoutProvider,
            currentPeriodProvider,
          );
        }
      } catch (e) {
        // DO NOTHING
      }
    } else {
      // DO NOTHING
    }
  }
}
