import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/go_live/cluster_details.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/cluster_selection_screen.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/widgets/go_live_progress_indicator.dart';
import 'package:snabbit_runner/pages/go_live/uniform_confirmation.dart';
import 'package:snabbit_runner/providers/go_live_v2_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/server_requests/go_live_v2_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Screen 0: Select region before cluster selection
class RegionSelectionScreen extends StatefulWidget {
  static const String routeName = '/go-live-v2/region-selection';

  const RegionSelectionScreen({super.key});

  @override
  State<RegionSelectionScreen> createState() => _RegionSelectionScreenState();
}

class _RegionSelectionScreenState extends State<RegionSelectionScreen> {
  Region? _selectedRegion;

  @override
  void initState() {
    super.initState();
    // Fetch regions when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRegions();
    });
  }

  Future<void> _fetchRegions() async {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    await provider.fetchRegions();
    // If partner is already onboarded, navigate directly to ClusterDetailsPage
    if (provider.isPartnerAlreadyOnboardedOnRegions && mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        ClusterDetailsPage.routeName,
        (route) => route.isFirst,
      );
      return;
    }
  }

  void _selectRegion(Region region) {
    setState(() {
      _selectedRegion = region;
    });
  }

  void _onContinue() {
    if (_selectedRegion == null) {
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(languageProvider.getMessage(
          'go_live_v2_region_selection_error',
          'Please select a city',
        ))),
      );
      return;
    }

    // Store selected region in provider
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    provider.setSelectedRegion(_selectedRegion!);

    // Navigate to cluster selection screen
    Navigator.pushNamed(context, ClusterSelectionScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        // Navigate to uniform confirmation screen instead of default back
        Navigator.pushReplacementNamed(
          context,
          UniformConfirmationPage.routeName,
        );
      },
      child: Consumer<GoLiveV2Provider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: CommonAppBar(
              title: const SizedBox.shrink(),
              onBackPressed: () {
                // Navigate to uniform confirmation screen instead of default back
                Navigator.pushReplacementNamed(
                  context,
                  UniformConfirmationPage.routeName,
                );
              },
            ),
            body: Column(
              children: [
                // Progress indicator - step 1 of 5 (region selection is first)
                const GoLiveProgressIndicator(currentStep: 1, totalSteps: 5),

                Expanded(
                  child: provider.isLoadingRegions
                      ? _buildLoadingState()
                      : provider.isPartnerAlreadyOnboardedOnRegions
                          ? _buildLoadingState() // Show loading while navigating
                          : provider.regionsError != null
                              ? _buildErrorState(provider.regionsError!)
                              : SingleChildScrollView(
                                  padding: EdgeInsets.all(20.w),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
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
                                        builder:
                                            (context, languageProvider, _) =>
                                                Text(
                                          languageProvider.getMessage(
                                            'go_live_v2_region_title',
                                            'Select your city',
                                          ),
                                          style: TextStyle(
                                            fontSize: 24.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 32.h),

                                      // Region list
                                      _buildRegionList(),
                                    ],
                                  ),
                                ),
                ),

                // Continue button
                _buildContinueButton(),
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
                'go_live_v2_loading_regions',
                'Loading regions...',
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
                    'go_live_v2_region_load_failed',
                    'Failed to load regions',
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
                  onPressed: _fetchRegions,
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

  Widget _buildRegionList() {
    final provider = Provider.of<GoLiveV2Provider>(context, listen: false);
    final regions = provider.availableRegions;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: regions.length,
      itemBuilder: (context, index) {
        final region = regions[index];
        final isSelected = _selectedRegion?.id == region.id;

        return _buildRegionItem(
          region: region,
          isSelected: isSelected,
        );
      },
    );
  }

  Widget _buildRegionItem({
    required Region region,
    required bool isSelected,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: isSelected ? const Color(0xFFFCE4EC) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: () => _selectRegion(region),
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
                // Region name
                Expanded(
                  child: Text(
                    region.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Selection indicator on the right
                if (isSelected)
                  Container(
                    width: 32.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
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
    final bool canContinue = _selectedRegion != null;

    return Container(
      padding: EdgeInsets.all(20.w),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) => Column(
          children: [
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
