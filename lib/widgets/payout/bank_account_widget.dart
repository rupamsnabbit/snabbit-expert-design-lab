import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/payout/expert_bank_details.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_bank_or_upi_details_screen.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/payout_http.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_assets.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_widgets/add_button_with_dashed_border.dart';
import 'package:snabbit_runner/widgets/common_widgets/custom_add_details_banner.dart';
import 'package:snabbit_runner/widgets/payout/bank_details_bottom_sheet.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Widget to display active bank account or empty state
/// Fetches bank account data from API and displays accordingly
class BankAccountWidget extends StatefulWidget {
  const BankAccountWidget({
    super.key,
  });

  @override
  State<BankAccountWidget> createState() => _BankAccountWidgetState();
}

class _BankAccountWidgetState extends State<BankAccountWidget> {
  bool _init = true;
  bool _loading = true;
  ExpertBankDetails? _bankDetails;

  late LanguageProvider _languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) {
      _init = false;
      _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      _fetchBankAccount();
    }
  }

  /// Fetches the active bank account from the API
  Future<void> _fetchBankAccount() async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await PayoutHttp.getActiveBankAccount();
      if (response != null && response.statusCode == 200) {
        final data = response.data;
        if (data != null) {
          setState(() {
            _bankDetails = ExpertBankDetails.fromJson(data);
            _loading = false;
          });
        } else {
          setState(() {
            _bankDetails = null;
            _loading = false;
          });
        }
      } else {
        setState(() {
          _bankDetails = null;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _bankDetails = null;
        _loading = false;
      });
    }
  }

  /// Formats account number with masking
  String _formatAccountNumber(String? accountNumberLast4) {
    if (accountNumberLast4 == null || accountNumberLast4.isEmpty) {
      return 'xxxx xxxx';
    }
    // Format as "xxxx xxxx 6288" if we have last 4 digits
    return 'xxxx xxxx $accountNumberLast4';
  }

  /// Gets bank name from meta or defaults to "Bank"
  String _getBankName() {
    if (_bankDetails?.meta != null) {
      final bankName = _bankDetails!.meta!['bank_name'];
      if (bankName != null && bankName.toString().isNotEmpty) {
        return bankName.toString();
      }
    }
    return _languageProvider.getMessage('bank', 'Bank');
  }

  /// Gets icon URL from meta
  String? _getIconUrl() {
    if (_bankDetails?.meta != null) {
      final iconUrl = _bankDetails!.meta!['icon_url'];
      if (iconUrl != null && iconUrl.toString().isNotEmpty) {
        return iconUrl.toString();
      }
    }
    return null;
  }

  /// Checks if bank account has issues
  bool _hasIssues() {
    return _bankDetails?.verificationStatus != true ||
        _bankDetails?.isActive != true;
  }

  /// Checks if we have valid bank account details
  bool _hasValidBankDetails() {
    // First check if the user profile indicates bank is verified (like drawer menu logic)
    final userProfile =
        Provider.of<UserProfileProvider>(context, listen: false);
    if (userProfile.user?.bankVerified == false ||
        userProfile.user?.bankVerified == null) {
      return false;
    }

    // If not verified by user profile, check if we have actual bank details
    if (_bankDetails == null) return false;

    // Check if we have either UPI ID or account details
    final hasUpiDetails = _bankDetails?.isUpiAccount == true &&
        (_bankDetails?.upiId?.isNotEmpty ?? false);
    final hasBankDetails = _bankDetails?.isUpiAccount == false &&
        (_bankDetails?.accountNumberLast4?.isNotEmpty ?? false);

    return hasUpiDetails || hasBankDetails;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: 361.w,
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.n0,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 1),
              blurRadius: 4,
            ),
          ],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_bankDetails == null || !_hasValidBankDetails()) {
      return _buildEmptyState();
    }

    return _buildBankAccountCard();
  }

  /// Builds the empty state when no bank account is available
  Widget _buildEmptyState() {
    return Container(
      width: 361.w,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.n0,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add button with dashed border
          GestureDetector(
            onTap: () {
              Navigator.of(context)
                  .pushNamed(AddBankOrUpiDetailsScreen.routeName);
            },
            child: SizedBox(
              width: 329.w,
              height: 52.h,
              child: AddButtonWithDashedBorder(
                text: _languageProvider.getMessage(
                  'add_upi_id_bank_account',
                  'Add UPI ID/ bank account',
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Custom add details banner
          SizedBox(
            width: 329.w,
            child: CustomAddDetailsBanner(
              title: {
                "key": "add_bank_account_benefit_text",
                "text": "{{add_bank_account_highlight}} to enable payout",
                "style": {
                  "name": "Metropolis",
                  "font_size": 14,
                  "color": "#C50F1F",
                  "weight": 600,
                  "style": "normal",
                },
                "data": [
                  {
                    "key": "add_bank_account_highlight",
                    "text": "Add UPI / bank account",
                    "style": {
                      "name": "Metropolis",
                      "font_size": 14,
                      "color": "#C50F1F",
                      "weight": 800,
                      "style": "normal"
                    }
                  }
                ],
                "alignment": "left"
              },
              image: RemoteConfigAssets.addBankMiniBanner,
              backgroundColor: AppColors.r0,
              padding: EdgeInsets.zero,
              imageWidth: 51.w,
              titlePadding: EdgeInsets.all(12.r),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the bank account card when bank account is available
  Widget _buildBankAccountCard() {
    final textTheme = Theme.of(context).textTheme;
    final hasIssues = _hasIssues();
    final bankName = _getBankName();
    final iconUrl = _getIconUrl();
    final accountNumberLast4 = _bankDetails?.accountNumberLast4;

    return Container(
      width: 361.w,
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 20.h),
      decoration: BoxDecoration(
        color: AppColors.n0,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (_bankDetails != null) {
                showBankDetailsBottomSheet(
                    context: context, bankDetails: _bankDetails!);
              }
            },
            child: Container(
              width: 321.w,
              height: 80.h,
              decoration: BoxDecoration(
                color: AppColors.n0,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.n30,
                  width: 1.r,
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 19.62.h, 14.w, 19.62.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Bank icon with status indicator
                        _buildBankIcon(iconUrl: iconUrl, hasIssues: hasIssues),
                        SizedBox(width: 13.w),
                        // Bank details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Bank name
                              Text(
                                bankName,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.02,
                                  height: 20 / 14,
                                  color: hasIssues
                                      ? AppColors.n90.withValues(alpha: 0.4)
                                      : AppColors.n90,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              // Account number
                              Flexible(
                                child: FittedBox(
                                  child: Text(
                                    _bankDetails?.isUpiAccount == true
                                        ? 'ID: ${_bankDetails?.upiId ?? ""}'
                                        : 'A/C no: ${_formatAccountNumber(accountNumberLast4)}',
                                    style: textTheme.bodySmall?.copyWith(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.02,
                                      height: 16 / 12,
                                      color: hasIssues
                                          ? const Color(0xFF6D7783)
                                              .withValues(alpha: 0.4)
                                          : const Color(0xFF6D7783),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Chevron button
                        Container(
                          width: 24.w,
                          height: 24.h,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.n30,
                              width: 1.5.r,
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16.r,
                            color: AppColors.n90,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Primary Bank tag
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.g10,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12.r),
                          bottomLeft: Radius.circular(4.r),
                        ),
                      ),
                      child: Text(
                        _languageProvider.getMessage(
                          'primary_bank',
                          'Primary Bank',
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.02,
                          color: AppColors.g50,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: () {
              Navigator.of(context)
                  .pushNamed(AddBankOrUpiDetailsScreen.routeName);
            },
            child: AddButtonWithDashedBorder(
              text: _languageProvider.getMessage(
                'update_upi_id_bank_account',
                'Update UPI ID/ bank account',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the bank icon with status indicator
  Widget _buildBankIcon({
    required String? iconUrl,
    required bool hasIssues,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bank icon container
        Container(
          width: 40.76.w,
          height: 40.76.h,
          decoration: BoxDecoration(
            color: AppColors.n20,
            shape: BoxShape.circle,
          ),
          child: iconUrl != null && iconUrl.isNotEmpty
              ? ClipOval(
                  child: RemoteImageHandler(
                    imageUrl: iconUrl,
                    width: 24.r,
                    height: 24.r,
                    fit: BoxFit.cover,
                    errorWidget: SvgPicture.asset(
                      AssetConstants.defaultBankIcon,
                      width: 24.r,
                      height: 24.r,
                    ),
                  ),
                )
              : SvgPicture.asset(
                  AssetConstants.defaultBankIcon,
                  width: 24.r,
                  height: 24.r,
                ),
        ),
        // Status indicator overlay
        if (hasIssues)
          // Warning icon overlay
          Positioned(
            right: -1.71.w,
            top: -2.78.h,
            child: SvgPicture.asset(
              AssetConstants.bankWarning,
              width: 16.w,
            ),
          )
        else
          // Success checkmark overlay
          Positioned(
            right: -3.71.w,
            top: -2.78.h,
            child: SvgPicture.asset(
              AssetConstants.assuredCheck,
              width: 20.38.w,
              height: 20.38.h,
            ),
          ),
      ],
    );
  }
}
