import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/cluster.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/shift_hours_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/widgets/go_live_progress_indicator.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Hood Selection Screen - shown for big clusters with multiple hoods
/// Allows user to select a specific hood within a big cluster
class HoodSelectionScreen extends StatefulWidget {
  static const String routeName = '/go-live-v2/hood-selection';

  final GoLiveCluster cluster;

  const HoodSelectionScreen({
    super.key,
    required this.cluster,
  });

  @override
  State<HoodSelectionScreen> createState() => _HoodSelectionScreenState();
}

class _HoodSelectionScreenState extends State<HoodSelectionScreen> {
  final List<Hood> _selectedHoods = [];
  final int maxSelection = 3;

  @override
  void initState() {
    super.initState();
    // Pre-load any already selected hoods for this cluster
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
      final existingHoods =
          provider.getSelectedHoodsForCluster(widget.cluster.id);
      if (existingHoods.isNotEmpty) {
        setState(() {
          _selectedHoods.addAll(existingHoods);
        });
      }
    });
  }

  void _toggleHood(Hood hood) {
    setState(() {
      if (_selectedHoods.any((h) => h.id == hood.id)) {
        _selectedHoods.removeWhere((h) => h.id == hood.id);
      } else if (_selectedHoods.length < maxSelection) {
        _selectedHoods.add(hood);
      }
    });
  }

  bool get _canContinue {
    final availableHoods = widget.cluster.hoods ?? [];
    final minRequired = availableHoods.length < 2 ? availableHoods.length : 2;
    return _selectedHoods.isNotEmpty && _selectedHoods.length >= minRequired;
  }

  void _onContinue() {
    if (!_canContinue) {
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(languageProvider.getMessage(
          'go_live_v2_hood_min_selection_error',
          'Please select at least 2 hoods',
        ))),
      );
      return;
    }

    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);

    // Store the selected hoods for this cluster
    provider.setSelectedHoods(widget.cluster.id, _selectedHoods);

    // Check if there are more big clusters pending hood selection
    final pendingBigClusters = provider.pendingBigClusters;

    if (pendingBigClusters.isNotEmpty) {
      // Navigate to hood selection for next big cluster
      Navigator.pushReplacementNamed(
        context,
        HoodSelectionScreen.routeName,
        arguments: pendingBigClusters.first,
      );
    } else {
      // All big clusters have hood selections, proceed to shift hours
      // All big clusters have hood selections, proceed to shift hours
      final userProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      final workSchedule = userProvider.user?.workSchedule?.value;
      final isWeekendOnly = workSchedule == WorkSchedule.weekendOnly;

      if (isWeekendOnly) {
        provider.setHasSelectedWeekend(true);
        Navigator.pushNamed(context, ShiftHoursScreen.weekendRouteName);
      } else {
        Navigator.pushNamed(context, ShiftHoursScreen.routeName);
      }
    }
  }

  void _handleBackPressed() {
    // Clear all hood selections when going back to cluster selection
    // This ensures a fresh start if user changes their cluster choices
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    provider.clearAllHoodSelections();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: CommonAppBar(
          title: const SizedBox.shrink(),
          onBackPressed: _handleBackPressed,
        ),
        body: Column(
          children: [
            // Progress indicator - step 2 of 5 (same as cluster selection)
            const GoLiveProgressIndicator(currentStep: 2, totalSteps: 5),

            Expanded(
              child: SingleChildScrollView(
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
                      builder: (context, languageProvider, _) => Text(
                        languageProvider.getMessage(
                          'go_live_v2_hood_selection_title',
                          'Select your locality',
                        ),
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // Cluster name subtitle
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, _) => Text(
                        languageProvider.getMessage(
                          'go_live_v2_hood_selection_subtitle',
                          'in ${widget.cluster.name}',
                        ),
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),

                    // Hood list
                    _buildHoodList(),
                  ],
                ),
              ),
            ),

            // Continue button
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHoodList() {
    final hoods = widget.cluster.hoods ?? [];

    // Sort hoods by hunger score (descending)
    final sortedHoods = List<Hood>.from(hoods)
      ..sort((a, b) => b.hungerScore.compareTo(a.hungerScore));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedHoods.length,
      itemBuilder: (context, index) {
        final hood = sortedHoods[index];
        final isSelected = _selectedHoods.any((h) => h.id == hood.id);

        return _buildHoodItem(
          hood: hood,
          isSelected: isSelected,
        );
      },
    );
  }

  Widget _buildHoodItem({
    required Hood hood,
    required bool isSelected,
  }) {
    final selectionIndex = _selectedHoods.indexWhere((h) => h.id == hood.id);
    final selectionNumber = selectionIndex != -1 ? selectionIndex + 1 : null;
    final isDisabled = !isSelected && _selectedHoods.length >= maxSelection;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: isSelected ? const Color(0xFFFCE4EC) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: isDisabled ? null : () => _toggleHood(hood),
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 16.h,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppColors.brand : const Color(0xFFE0E0E0),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                // Hood name
                Expanded(
                  child: Text(
                    hood.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: isDisabled ? Colors.grey[400] : Colors.black,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
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
    );
  }

  Widget _buildContinueButton() {
    final availableHoods = widget.cluster.hoods ?? [];
    final showHelperText = availableHoods.length >= maxSelection;

    return Container(
      padding: EdgeInsets.all(20.w),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) => Column(
          children: [
            // Helper text - only show when 3 or more hoods are available
            if (showHelperText) ...[
              Text(
                languageProvider.getFormattedMessage(
                  'go_live_v2_hood_helper_text',
                  'You can select up to {{max_selection}} localities',
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
                onPressed: _canContinue ? _onContinue : null,
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
