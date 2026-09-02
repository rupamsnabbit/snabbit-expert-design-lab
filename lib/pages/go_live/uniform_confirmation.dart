import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/models/inventory_item.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/go_live_flow_controller.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/server_requests/inventory_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/go_live/capsule_list.dart';
import 'package:snabbit_runner/widgets/go_live/missing_items_warning.dart';
import 'package:snabbit_runner/widgets/go_live/quantity_selector.dart';
import 'package:snabbit_runner/widgets/go_live/text_divider.dart';
import 'package:snabbit_runner/widgets/go_live/top_label_dropdown.dart';

class UniformConfirmationPage extends StatefulWidget {
  static const String routeName = '/uniform-confirmation';

  const UniformConfirmationPage({super.key});

  @override
  State<UniformConfirmationPage> createState() =>
      _UniformConfirmationPageState();
}

class _UniformConfirmationPageState extends State<UniformConfirmationPage> {
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  bool init = true;
  bool loading = false;

  // fetch Swag kit state

  List<InventoryItem>? items;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      Future(() {
        initProcess();
      });
    }
    super.didChangeDependencies();
  }

  void initProcess() async {
    //fetch items
    loading = true;
    setState(() {});
    try {
      final response = await InventoryHttp.getInventoryItems();
      if (response != null &&
          response.statusCode == 200 &&
          response.data != null) {
        items = (response.data['items'] as List<dynamic>?)
            ?.map<InventoryItem>((e) => InventoryItem.fromJson(e))
            .toList();
        //manually removing yulu helmet if alternate delivery method is not yulu
        if (userProfileProvider.user?.alternateDeliveryMethod !=
            AlternateDeliveryMethod.yulu) {
          items?.removeWhere(
            (element) => element.name?.toLowerCase() == "yulu helmet",
          );
        }
      }
      loading = false;
    } catch (_) {
      loading = false;
    }
    setState(() {});
  }

  void _confirmUniform([bool confirmStockOut = false]) async {
    loading = true;
    setState(() {});
    try {
      final inventoryItems = [...?items];
      inventoryItems.removeWhere(
        (element) => element.type == ItemType.rainySeason,
      );
      if (_selectedItemRainySeason != null) {
        _selectedItemRainySeason?.type = ItemType.rainySeason;
        inventoryItems.add(_selectedItemRainySeason!);
      }

      final response = await InventoryHttp.setInventoryItems(
          userProfileProvider.user?.id ?? 0,
          inventoryItems: inventoryItems,
          confirmStockOut: confirmStockOut);
      if (response?.statusCode == 200) {
        loading = false;
        GoLiveFlowController.startFlow(context);
      } else {
        try {
          final responseError = ResponseError.fromMap(response?.data);
          final firstError = responseError.getFirstError();
          if (firstError != null && firstError.title == 'missing_items') {
            if (firstError.title == 'missing_items') {
              final items = firstError.data?['missing_items'] as List<dynamic>?;
              if (items != null) {
                final missingItems =
                    items.map((e) => InventoryItem.fromJson(e)).toList();
                // show missing items warning
                final outOfStock =
                    await showMissingItemsWarning(context, missingItems);
                if (outOfStock) {
                  _confirmUniform(outOfStock);
                }
              }
            } else {
              showSnackbar(context, firstError.message ?? '');
            }
          } else {
            showSnackbar(context, firstError?.message ?? '');
          }
        } catch (_) {
          showSnackbar(
              context, "Something went wrong. Please try again later.");
        }
        loading = false;
      }

      loading = false;
    } catch (_) {
      loading = false;
      showSnackbar(context, "Something went wrong. Please try again later.");
    }
    setState(() {});
  }

  //build different widget
  Widget _buildSwagKitItem({
    required String label,
    required String imagePath,
    bool showSize = false,
    String? selectedSize,
    ValueChanged<String?>? onSizeChanged,
    required int quantity,
    required ValueChanged<int> onQuantityChanged,
    List<String>? sizes = const [],
    int maxQuantity = 1,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          // Image
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18.sp,
                      color: Color(0xFF1D2129),
                    ),
              ),
              Image.network(
                imagePath,
                width: 120.w,
                height: 110.h,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image_not_supported_outlined),
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSize) ...[
                SizedBox(height: 12.h),
                CapsuleList<String>(
                  padding: EdgeInsets.zero,
                  label: languageProvider.getMessage(
                    'select_size',
                    'Select Size',
                  ),
                  items: sizes ?? [],
                  titleBuilder: (s) => s,
                  onSelectionChanged: onSizeChanged,
                  initialSelectedItem: selectedSize,
                  selectedItemBackgroundColor: AppColors.p50,
                  selectedItemTextColor: AppColors.n0,
                  unselectedItemTextColor: AppColors.n90,
                  unselectedItemBorderColor: AppColors.n40,
                  isCircle: true,
                  labelStyle:
                      Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.n90,
                          ),
                  itemSpacing: 16.w,
                ),
              ],
              SizedBox(height: 16.h),
              QuantitySelector(
                label: languageProvider.getMessage(
                  'select_quantity',
                  'Select Quantity:',
                ),
                initialValue: quantity,
                onChanged: onQuantityChanged,
                maxValue: maxQuantity,
              ),
            ],
          ),
        ],
      ),
    );
  }

  InventoryItem? _selectedItemRainySeason;

  Widget _buildRainySeasonSwagKitItem({
    required InventoryItem item,
  }) {
    final subItems = item.subItems ?? [];
    // int selectedIndex = 0;
    // InventoryItem selectedItem = subItems[selectedIndex];
    _selectedItemRainySeason ??= subItems.isNotEmpty ? subItems.first : null;
    return Container(
      key: ValueKey(_selectedItemRainySeason?.id),
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          // Image
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TopLabelDropDown<InventoryItem>(
                items: subItems,
                label: languageProvider.getMessage(
                    'select_any_one', "Select any one"),
                itemNameBuilder: (item) => item.name ?? '',
                initialSelection: _selectedItemRainySeason,
                onSelectionChanged: (e) {
                  if (e != null) {
                    _selectedItemRainySeason = e;
                    // item.name = e.name;
                    // item.size = null;
                    // item.quantity = 0;
                    setState(() {});
                  }
                },
              ),
              Image.network(
                _selectedItemRainySeason?.image ?? '',
                width: 120.w,
                height: 110.h,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image_not_supported_outlined),
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedItemRainySeason?.availableSizes != null) ...[
                SizedBox(height: 12.h),
                CapsuleList<String>(
                  padding: EdgeInsets.zero,
                  label: languageProvider.getMessage(
                    'select_size',
                    'Select Size',
                  ),
                  items: _selectedItemRainySeason?.availableSizes ?? [],
                  titleBuilder: (s) => s,
                  onSelectionChanged: (s) =>
                      setState(() => _selectedItemRainySeason?.size = s),
                  initialSelectedItem: _selectedItemRainySeason?.size,
                  selectedItemBackgroundColor: AppColors.p50,
                  selectedItemTextColor: AppColors.n0,
                  unselectedItemTextColor: AppColors.n90,
                  unselectedItemBorderColor: AppColors.n40,
                  isCircle: true,
                  labelStyle:
                      Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppColors.n90,
                          ),
                  itemSpacing: 16.w,
                ),
              ],
              SizedBox(height: 16.h),
              QuantitySelector(
                label: languageProvider.getMessage(
                  'select_quantity',
                  'Select Quantity:',
                ),
                initialValue: _selectedItemRainySeason?.quantity ?? 0,
                onChanged: (q) {
                  setState(() => _selectedItemRainySeason?.quantity = q);
                },
                maxValue: _selectedItemRainySeason?.maxQuantity ?? 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        elevation: 5.r,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage(
            "in_training",
            "In Training",
          ),
          style: textTheme.bodyLarge,
        ),
      ),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            onPressed: !loading && canContinue() ? _confirmUniform : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
            ),
            child: Text(
              languageProvider.getMessage("proceed", "Proceed"),
            ),
          ),
        ),
      ],
      body: init || loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : Container(
              margin: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 24.h,
              ),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                  color: AppColors.n0,
                  borderRadius: BorderRadius.circular(12.r)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title
                    SizedBox(height: 8.h),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        languageProvider.getMessage(
                          'did_you_receive_this',
                          "Did you receive these?",
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D2129),
                              letterSpacing: -1,
                            ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        languageProvider.getMessage(
                            'should_get_following_items',
                            "You should get the following items:"),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 16.sp,
                              color: Color(0xFF4E5969),
                              letterSpacing: -1,
                            ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    const Divider(color: AppColors.n40, thickness: 1),

                    // Swag kit items
                    ...?items?.map(
                      (item) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          item.type == ItemType.rainySeason &&
                                  item.subItems?.isNotEmpty == true
                              ? _buildRainySeasonSwagKitItem(
                                  item: item,
                                )
                              : _buildSwagKitItem(
                                  label: languageProvider.getMessage(
                                    item.name ?? '',
                                    item.name ?? '',
                                  ),
                                  imagePath: item.image ?? '',
                                  showSize: item.availableSizes != null,
                                  // selectedSize: _selectedSizes[item.id],
                                  // onSizeChanged: (s) =>
                                  //     setState(() => _selectedSizes[item.id ?? 0] = s),
                                  // quantity: _selectedQuantities[item.id ?? 0] ?? 0,
                                  // onQuantityChanged: (q) => setState(
                                  //     () => _selectedQuantities[item.id ?? 0] = q),
                                  selectedSize: item.size,
                                  onSizeChanged: (s) =>
                                      setState(() => item.size = s),
                                  quantity: item.quantity ?? 0,
                                  onQuantityChanged: (q) {
                                    setState(() => item.quantity = q);
                                  },
                                  sizes: item.availableSizes,
                                  maxQuantity: item.maxQuantity ?? 1,
                                ),
                          if (item.id != items?.last.id) ...[
                            SizedBox(height: 8.h),
                            const AndDivider(),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  bool canContinue() {
    if (items == null || items!.isEmpty) {
      return false;
    }
    for (final item in items!) {
      if (item.type == ItemType.rainySeason &&
              (_selectedItemRainySeason == null ||
                  (_selectedItemRainySeason != null &&
                      (_selectedItemRainySeason?.quantity ?? 0) < 1)) ||
          (_selectedItemRainySeason?.availableSizes != null &&
              _selectedItemRainySeason?.size == null)) {
        return false;
      } else if (item.type != ItemType.rainySeason &&
              (item.quantity == null || (item.quantity ?? 0) < 1) ||
          (item.availableSizes != null && item.size == null)) {
        return false;
      }
    }
    return true;
  }
}
