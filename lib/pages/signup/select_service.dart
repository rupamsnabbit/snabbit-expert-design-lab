import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/available_service.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/snake_case_localization_key.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';

class SelectService extends StatefulWidget {
  static const String routeName = "/select-service";

  const SelectService({super.key});

  @override
  State<SelectService> createState() => _SelectServiceState();
}

class _SelectServiceState extends State<SelectService> {
  bool init = true;
  bool loading = true;
  String? error;
  List<AvailableService> services = [];
  int? selectedServiceId;
  late UserProfileProvider userProfileProvider;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      selectedServiceId = userProfileProvider.user?.service?.id;
      fetchServices();
    }
  }

  /// Fetches available services from [RunnerHttp.getServicesList] and parses the response.
  static Future<List<AvailableService>> _fetchAvailableServices() async {
    final response = await RunnerHttp.getServicesList();
    if (response != null && response.statusCode == 200) {
      final data = response.data;
      if (data is List) {
        return AvailableService.fromList(data);
      } else if (data is Map && data['services'] is List) {
        return AvailableService.fromList(data['services'] as List<dynamic>);
      }
    }
    throw Exception('Failed to fetch services');
  }

  /// GET `api/v1/runners/me/active_services` — array of `{ id, name, image_url, tag }`.
  /// UI labels use [snakeCaseLocalizationKey] on `name` / `tag` for CMS keys.
  Future<void> fetchServices() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      services = await _fetchAvailableServices();
    } catch (_) {
      services = [];
      error = languageProvider.getMessage(
        'services_fetch_failed',
        'Failed to load services. Please try again.',
      );
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  void onConfirm() async {
    if (selectedServiceId == null) return;

    final selected =
        services.where((s) => s.id == selectedServiceId).firstOrNull;
    if (selected == null) return;

    // Set the selected service on the user profile and service ID.
    userProfileProvider.user?.service = Service(
      id: selected.id,
      name: selected.name,
    );

    setState(() {
      loading = true;
    });

    try {
      await userProfileProvider.runnerRegistrationAndErrorHandler(
        context: context,
        onError: (errorMessage) {
          if (!mounted) return;
          setState(() {
            loading = false;
          });
          showSnackbar(
            context,
            (errorMessage ?? '').isNotEmpty
                ? errorMessage!
                : languageProvider.getMessage(
                    'service_selection_failed',
                    'Something went wrong. Please try again.',
                  ),
          );
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
        });
        showSnackbar(
          context,
          languageProvider.getMessage(
            'service_selection_failed',
            'Something went wrong. Please try again.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.n0,
        title: Text(
          languageProvider.getMessage(
              "registration_details_title", "Registration Details"),
          style: TextStyle(
            color: AppColors.n90,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            height: 20 / 16,
            letterSpacing: -0.24,
          ),
        ),
        leading: InkWell(
          onTap: () {
            userProfileProvider.registrationBackAction();
          },
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.n80,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.h),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: (!loading && error == null && services.isNotEmpty)
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: SizedBox(
                  height: 48.h,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      disabledBackgroundColor: AppColors.brand.withAlpha(128),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    onPressed: selectedServiceId != null ? onConfirm : null,
                    child: Text(
                      languageProvider.getMessage("confirm", "Confirm"),
                      style: TextStyle(
                        color: AppColors.brandInverted,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        height: 20 / 15,
                        letterSpacing: -0.24,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (loading) {
      return Padding(
        padding: EdgeInsets.all(16.r),
        child: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: EdgeInsets.all(16.r),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error!),
              SizedBox(height: 32.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: fetchServices,
                  child: Text(
                    languageProvider.getMessage("retry", "Retry"),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (services.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16.r),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                AssetConstants.sadEmoji,
                width: 48.r,
                height: 48.r,
              ),
              SizedBox(height: 16.h),
              Text(
                languageProvider.getMessage(
                  'no_services_available',
                  'Uh-oh! Seems like no services are available right now.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.n70,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  height: 20 / 14,
                ),
              ),
              SizedBox(height: 32.h),
              SizedBox(
                width: 1.sw,
                child: ElevatedButton(
                  onPressed: fetchServices,
                  child: Text(
                    languageProvider.getMessage("retry", "Retry"),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 52.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getMessage(
                "what_do_you_want_to_do", "What do you want to do?"),
            style: TextStyle(
              color: AppColors.n90,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              height: 24 / 20,
              letterSpacing: -0.24,
            ),
          ),
          SizedBox(height: 20.h),
          ...services.map((service) => _buildServiceCard(service)),
        ],
      ),
    );
  }

  /// Circular avatar: image must [BoxFit.cover] a square, then clip to circle.
  /// Avoid `BoxDecoration(...).copyWith(image:)` — it can drop `shape` on some SDKs.
  Widget _buildCircularServiceImage(AvailableService service) {
    final double size = 52.r;

    if (service.imageUrl != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.n30,
        ),
        clipBehavior: Clip.antiAlias,
        child: RemoteImageHandler(
          imageUrl: service.imageUrl!.cdn,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.n30,
      ),
      clipBehavior: Clip.antiAlias,
      child: Transform.scale(
        scale: 1.4,
        child: Image.asset(
          AssetConstants.snabbitExpertIcon,
          fit: BoxFit.cover,
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }

  Widget _buildServiceCard(AvailableService service) {
    final isSelected = selectedServiceId == service.id;
    final nameKey = snakeCaseLocalizationKey(service.name);
    final nameLookupKey =
        nameKey.isNotEmpty ? nameKey : 'service_${service.id}';
    final displayedName =
        languageProvider.getMessage(nameLookupKey, service.name);
    final tag = service.tag;
    String? displayedTag;
    if (tag != null) {
      final tagKey = snakeCaseLocalizationKey(tag);
      final tagLookupKey =
          tagKey.isNotEmpty ? tagKey : 'service_tag_${service.id}';
      displayedTag = languageProvider.getMessage(tagLookupKey, tag);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            selectedServiceId = service.id;
          });
        },
        child: Container(
          height: 72.h,
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.brand : AppColors.n40,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            children: [
              _buildCircularServiceImage(service),
              SizedBox(width: 15.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayedName,
                        style: TextStyle(
                          color: AppColors.n90,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          height: 24 / 20,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (displayedTag != null) ...[
                      SizedBox(height: 4.h),
                      Container(
                        height: 20.h,
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(30.r),
                          border: Border.all(
                            color: AppColors.brand.withAlpha(90),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              displayedTag,
                              style: TextStyle(
                                color: AppColors.brand,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              _buildRadioIndicator(isSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioIndicator(bool isSelected) {
    return Container(
      width: 24.r,
      height: 24.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.brand : AppColors.n40,
          width: 2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 12.r,
                height: 12.r,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brand,
                ),
              ),
            )
          : null,
    );
  }
}
