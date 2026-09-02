import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/cluster_details.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/cluster_selection_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/confirm_shift_timings_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/go_live_recommendations_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/hood_selection_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/cluster.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/region_selection_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/shift_hours_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/shift_time_selection_screen.dart';
import 'package:snabbit_runner/pages/go_live/potential_earnings.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/remote_config/go_live_feature_flags.dart';

/// Controller widget that wraps the Go Live V2 flow with state management
/// and provides navigation between screens
class GoLiveFlowController extends StatelessWidget {
  static const String routeName = '/go-live-v2';
  static final GoLiveV2Provider _goLiveV2Provider = GoLiveV2Provider();

  const GoLiveFlowController({super.key});

  /// Start the Go Live flow from the beginning
  ///
  /// This checks the Firebase Remote Config `enable_golive_v2` feature flag:
  /// - If globally enabled OR user's TC ID is in the enabled list → Go Live V2
  /// - Otherwise → Old PotentialEarnings flow
  static void startFlow(BuildContext context) {
    // Get user's TC ID from UserProfileProvider
    int? userTcId;
    try {
      final userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      userTcId = userProfileProvider.user?.tc?.id;
    } catch (_) {
      // Provider may not be available, userTcId remains null
    }

    // Check feature flag to decide which flow to use
    if (GoLiveFeatureFlags.isEnabledForTc(userTcId)) {
      // Use Go Live V2 flow
      _goLiveV2Provider.reset();
      Navigator.pushNamed(context, routeName);
    } else {
      // Use old PotentialEarnings flow
      Navigator.pushNamed(context, PotentialEarnings.routeName);
    }
  }

  /// Register all routes for the Go Live V2 flow
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      routeName: (context) => const GoLiveFlowController(),
      RegionSelectionScreen.routeName: (context) =>
          ChangeNotifierProvider.value(
            value: _goLiveV2Provider,
            child: const RegionSelectionScreen(),
          ),
      ClusterSelectionScreen.routeName: (context) =>
          ChangeNotifierProvider.value(
            value: _goLiveV2Provider,
            child: const ClusterSelectionScreen(),
          ),
      ClusterSelectionScreen.noShiftsRouteName: (context) {
        // Set error type in provider before showing screen
        _goLiveV2Provider.setErrorType('NO_SHIFTS_AVAILABLE');
        return ChangeNotifierProvider.value(
          value: _goLiveV2Provider,
          child: const ClusterSelectionScreen(),
        );
      },
      ClusterSelectionScreen.shiftNotAvailableRouteName: (context) {
        // Set error type in provider before showing screen
        _goLiveV2Provider.setErrorType('SHIFT_NOT_AVAILABLE');
        return ChangeNotifierProvider.value(
          value: _goLiveV2Provider,
          child: const ClusterSelectionScreen(),
        );
      },
      HoodSelectionScreen.routeName: (context) {
        // Get cluster from arguments
        final cluster =
            ModalRoute.of(context)!.settings.arguments as GoLiveCluster;
        return ChangeNotifierProvider.value(
          value: _goLiveV2Provider,
          child: HoodSelectionScreen(cluster: cluster),
        );
      },
      ShiftHoursScreen.routeName: (context) {
        // Ensure weekend mode is false for regular flow
        _goLiveV2Provider.setWeekendMode(false);
        return ChangeNotifierProvider.value(
          value: _goLiveV2Provider,
          child: const ShiftHoursScreen(),
        );
      },
      ShiftHoursScreen.weekendRouteName: (context) {
        // Set weekend mode in provider
        _goLiveV2Provider.setWeekendMode(true);
        return ChangeNotifierProvider.value(
          value: _goLiveV2Provider,
          child: const ShiftHoursScreen(),
        );
      },
      ShiftTimeSelectionScreen.routeName: (context) {
        // Ensure weekend mode is false for regular flow
        _goLiveV2Provider.setWeekendMode(false);
        return ChangeNotifierProvider.value(
          value: _goLiveV2Provider,
          child: const ShiftTimeSelectionScreen(),
        );
      },
      ShiftTimeSelectionScreen.weekendRouteName: (context) {
        // Set weekend mode in provider
        _goLiveV2Provider.setWeekendMode(true);
        return ChangeNotifierProvider.value(
          value: _goLiveV2Provider,
          child: const ShiftTimeSelectionScreen(),
        );
      },
      ConfirmShiftTimingsScreen.routeName: (context) =>
          ChangeNotifierProvider.value(
            value: _goLiveV2Provider,
            child: const ConfirmShiftTimingsScreen(),
          ),
      // ClusterDetailsPage with V2 provider for V2 flow
      // Note: This route is also registered in main.dart for V1 flow (without provider)
      // The route registered here takes precedence when navigating from V2 flow
      ClusterDetailsPage.routeName: (context) => ChangeNotifierProvider.value(
            value: _goLiveV2Provider,
            child: const ClusterDetailsPage(),
          ),
      GoLiveRecommendationsScreen.routeName: (context) {
        // Ensure weekend mode is false for regular flow
        _goLiveV2Provider.setWeekendMode(false);
        return ChangeNotifierProvider.value(
          value: _goLiveV2Provider,
          child: const GoLiveRecommendationsScreen(),
        );
      },
      GoLiveRecommendationsScreen.weekendRouteName: (context) {
        // Set weekend mode in provider
        _goLiveV2Provider.setWeekendMode(true);
        return ChangeNotifierProvider.value(
          value: _goLiveV2Provider,
          child: const GoLiveRecommendationsScreen(),
        );
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the flow with the provider - start with region selection
    return ChangeNotifierProvider.value(
      value: _goLiveV2Provider,
      child: const RegionSelectionScreen(),
    );
  }
}

/// Navigation helper methods
class GoLiveNavigation {
  /// Navigate to cluster selection (first screen)
  static void toClusterSelection(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      ClusterSelectionScreen.routeName,
      (route) => false,
    );
  }

  /// Navigate to shift hours selection
  static void toShiftHours(BuildContext context) {
    Navigator.pushNamed(context, ShiftHoursScreen.routeName);
  }

  /// Navigate to time selection
  static void toTimeSelection(BuildContext context) {
    Navigator.pushNamed(context, ShiftTimeSelectionScreen.routeName);
  }

  /// Navigate to recommendations
  static void toRecommendations(BuildContext context) {
    Navigator.pushNamed(context, GoLiveRecommendationsScreen.routeName);
  }

  /// Exit the flow and return to previous screen
  static void exitFlow(BuildContext context) {
    // Reset the v2 provider
    try {
      final goLiveV2Provider =
          Provider.of<GoLiveV2Provider>(context, listen: false);
      goLiveV2Provider.reset();
    } catch (_) {
      // Provider may not be available in all contexts
    }

    // Pop all screens until we exit the flow
    Navigator.popUntil(
        context,
        (route) =>
            route.settings.name == null ||
            !route.settings.name!.contains('go-live-v2'));
  }

  /// Restart the flow from the beginning
  static void restartFlow(BuildContext context) {
    try {
      final goLiveV2Provider =
          Provider.of<GoLiveV2Provider>(context, listen: false);
      goLiveV2Provider.reset();
    } catch (_) {
      // Provider may not be available in all contexts
    }

    toClusterSelection(context);
  }
}
