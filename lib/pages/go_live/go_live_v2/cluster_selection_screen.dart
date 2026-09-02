import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/cluster_details.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/hood_selection_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/cluster.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/region_selection_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/shift_hours_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/utils/go_live_v2_tracking.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/widgets/go_live_progress_indicator.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/widgets/no_shifts_available_modal.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Screen 1: Select top 3 work areas (clusters)
class ClusterSelectionScreen extends StatefulWidget {
  static const String routeName = '/go-live-v2/cluster-selection';
  static const String noShiftsRouteName =
      '/go-live-v2/cluster-selection-no-shifts';
  static const String shiftNotAvailableRouteName =
      '/go-live-v2/cluster-selection-shift-not-available';

  const ClusterSelectionScreen({super.key});

  @override
  State<ClusterSelectionScreen> createState() => _ClusterSelectionScreenState();
}

class _ClusterSelectionScreenState extends State<ClusterSelectionScreen> {
  final int maxSelection = 3;

  @override
  void initState() {
    super.initState();
    // Fetch clusters when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchClusters();
      // Show appropriate error modal if navigated here due to error
      final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
      if (provider.errorType == 'NO_SHIFTS_AVAILABLE') {
        showNoShiftsAvailableModal(context);
        // Clear saved clusters and hoods after showing modal
        provider.clearSelectedClusters();
        provider.clearAllHoodSelections();
        // Clear error type after showing modal
        provider.setErrorType(null);
      } else if (provider.errorType == 'SHIFT_NOT_AVAILABLE') {
        showShiftNotAvailableModal(context);
        // Clear error type after showing modal
        provider.setErrorType(null);
      }
    });
  }

  Future<void> _fetchClusters() async {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    final userProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    await provider.fetchClusters(tcId: userProvider.user?.tc?.id);

    // If partner is already onboarded, navigate directly to ClusterDetailsPage
    if (provider.isPartnerAlreadyOnboardedOnClusters && mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        ClusterDetailsPage.routeName,
        (route) => route.isFirst,
      );
      return;
    }

    // Track screen load
    if (provider.clustersError == null &&
        provider.availableClusters.isNotEmpty) {
      await GoLiveV2Tracking.trackWorkSelectionLoad(
        allClusters: provider.availableClusters,
        recommendedClusters: provider.availableClusters
            .where((c) => c.isHigherEarnings)
            .toList(),
      );
    }
  }

  void _toggleCluster(GoLiveCluster cluster) {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    provider.toggleCluster(cluster);
  }

  void _onContinue() {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    final userProvider =
        Provider.of<UserProfileProvider>(context, listen: false);

    if (!provider.canProceedFromClusterSelection) {
      // Show error - at least 2 clusters must be selected
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(languageProvider.getMessage(
          'go_live_v2_cluster_min_selection_error',
          'Please select at least 2 work areas',
        ))),
      );
      return;
    }

    // Track cluster selection CTA
    GoLiveV2Tracking.trackWorkSelectionCta(
      selectedClusters: provider.selectedClusters,
      recommendedClusters:
          provider.availableClusters.where((c) => c.isHigherEarnings).toList(),
    );

    // Check if any selected clusters are big clusters needing hood selection
    final bigClusters = provider.bigClustersNeedingHoodSelection;

    if (bigClusters.isNotEmpty) {
      // Navigate to hood selection for the first big cluster
      Navigator.pushNamed(
        context,
        HoodSelectionScreen.routeName,
        arguments: bigClusters.first,
      );
      return;
    }

    // No big clusters or all have hoods selected - proceed to shift hours
    final workSchedule = userProvider.user?.workSchedule?.value;
    final isWeekendOnly = workSchedule == WorkSchedule.weekendOnly;

    // Navigate based on work schedule:
    // - weekendOnly: Go directly to weekend shift hours screen
    // - everyday (or null): Go to regular weekday shift hours screen
    if (isWeekendOnly) {
      // Set hasSelectedWeekend to true since weekend-only users will only have weekend shifts
      provider.setHasSelectedWeekend(true);
      Navigator.pushNamed(context, ShiftHoursScreen.weekendRouteName);
    } else {
      Navigator.pushNamed(context, ShiftHoursScreen.routeName);
    }
  }

  void _handleBackPressed() {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    provider.clearSelectedClusters();
    Navigator.pushReplacementNamed(
      context,
      RegionSelectionScreen.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Consumer<GoLiveV2Provider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: CommonAppBar(
              title: const SizedBox.shrink(),
              onBackPressed: () {
                _handleBackPressed();
              },
            ),
            body: Column(
              children: [
                // Progress indicator - step 2 of 5 (after region selection)
                const GoLiveProgressIndicator(currentStep: 2, totalSteps: 5),

                Expanded(
                  child: provider.isLoadingClusters
                      ? _buildLoadingState()
                      : provider.clustersError != null
                          ? _buildErrorState(provider.clustersError!)
                          : SingleChildScrollView(
                              padding: EdgeInsets.all(20.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Icon
                                  RemoteImageHandler(
                                    imageUrl: "go_live/work_areas.png".cdn,
                                    width: 80.w,
                                    height: 80.h,
                                  ),
                                  SizedBox(height: 4.h),

                                  // Title
                                  Consumer<LanguageProvider>(
                                    builder: (context, languageProvider, _) =>
                                        Text(
                                      languageProvider.getMessage(
                                        'go_live_v2_cluster_title',
                                        'Select top 3 work areas',
                                      ),
                                      style: TextStyle(
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),

                                  // Subtitle with distance info
                                  Consumer<LanguageProvider>(
                                    builder: (context, languageProvider, _) =>
                                        Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 16.sp,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          languageProvider.getMessage(
                                            'go_live_v2_distance_from_home',
                                            'Distance shown is from Expert\'s home location',
                                          ),
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 24.h),

                                  // Cluster list
                                  _buildClusterList(provider),
                                ],
                              ),
                            ),
                ),

                // Continue button
                _buildContinueButton(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 16.h),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) => Text(
              languageProvider.getMessage(
                'go_live_v2_loading_work_areas',
                'Loading work areas...',
              ),
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48.sp,
            color: Colors.red,
          ),
          SizedBox(height: 16.h),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) => Column(
              children: [
                Text(
                  languageProvider.getMessage(
                    'go_live_v2_cluster_load_failed',
                    'Failed to load work areas',
                  ),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  error,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: _fetchClusters,
                  child: Text(languageProvider.getMessage(
                    'go_live_v2_retry',
                    'Retry',
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterList(GoLiveV2Provider provider) {
    final clusters = provider.availableClusters;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clusters.length,
      itemBuilder: (context, index) {
        final cluster = clusters[index];
        final isSelected = provider.isClusterSelected(cluster);
        final selectionIndex = provider.getClusterSelectionIndex(cluster);
        final isDisabled = !isSelected && provider.isMaxClustersSelected;

        return _buildClusterItem(
          cluster: cluster,
          isSelected: isSelected,
          selectionNumber: selectionIndex,
          isDisabled: isDisabled,
        );
      },
    );
  }

  Widget _buildClusterItem({
    required GoLiveCluster cluster,
    required bool isSelected,
    int? selectionNumber,
    required bool isDisabled,
  }) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 12.h,
        top: cluster.hasHigherEarnings ? 12.h : 0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: isSelected ? const Color(0xFFFCE4EC) : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            child: InkWell(
              onTap: isDisabled ? null : () => _toggleCluster(cluster),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 16.h,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        isSelected ? AppColors.brand : const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    // Cluster name
                    Expanded(
                      child: Text(
                        cluster.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: isDisabled ? Colors.grey[400] : Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Distance (if available)
                    if (cluster.distanceText != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12.sp,
                            color: Colors.black.withOpacity(0.5),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            cluster.distanceText!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 12.w),
                    ],
                    // Selection indicator on the right
                    if (isSelected && selectionNumber != null)
                      Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$selectionNumber',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 32.w,
                        height: 32.h,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Higher earnings badge (top-center, positioned absolutely)
          if (cluster.hasHigherEarnings)
            Positioned(
              top: -10.h,
              left: 12.w,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.g20,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RemoteImageHandler(
                        imageUrl: "go_live/rupee_earnings.png".cdn,
                        width: 34.w,
                        height: 16.w,
                      ),
                      SizedBox(width: 6.w),
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, _) => Text(
                          languageProvider.getMessage(
                            'go_live_v2_higher_earnings',
                            'Higher earnings',
                          ),
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.n90,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(GoLiveV2Provider provider) {
    final bool canContinue = provider.canProceedFromClusterSelection;
    final availableClusters = provider.availableClusters;
    final showHelperText = availableClusters.length >= maxSelection;

    return Container(
      padding: EdgeInsets.all(20.w),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) => Column(
          children: [
            // Helper text - only show when 3 or more clusters are available
            if (showHelperText) ...[
              Text(
                languageProvider.getFormattedMessage(
                  'go_live_v2_cluster_helper_text',
                  'You can select up to {{max_selection}} areas',
                  {
                    'max_selection': maxSelection,
                  },
                ),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 16.sp,
                      color: Colors.grey[600],
                    ),
              ),
              SizedBox(height: 16.h),
            ],
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canContinue ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  disabledBackgroundColor: Colors.grey[300],
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  languageProvider.getMessage(
                    'go_live_v2_continue',
                    'Continue',
                  ),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
