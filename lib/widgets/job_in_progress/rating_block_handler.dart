import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';

import '../../constants/assets_constants.dart';
import '../../models/errors/response_error.dart';
import '../../services/analytics/job_lifecycle_analytics.dart';
import '../../services/clevertap.dart';
import '../../services/job_http.dart';
import '../../services/runner_http.dart';
import '../../utils/common_methods.dart';
import '../../utils/tracking_events.dart';

enum BlockState {
  blockCustomer,
  manageBlockList,
  customerBlocked,
  error,
}

class RatingBlockProvider with ChangeNotifier {
  int? _currentRating;
  BlockState _currentBlockState = BlockState.blockCustomer;
  String? _error;

  BlockState get currentBlockState {
    return _currentBlockState;
  }

  set currentBlockState(BlockState val) {
    _currentBlockState = val;
    notifyListeners();
  }

  int? get currentRating {
    return _currentRating;
  }

  set currentRating(int? val) {
    _currentRating = val;
    notifyListeners();
  }

  String? get error {
    return _error;
  }

  set error(String? val) {
    _error = val;
    notifyListeners();
  }

  void reset() {
    _currentBlockState = BlockState.blockCustomer;
    _error = null;
    notifyListeners();
  }
}

class RatingBlockHandler extends StatefulWidget {
  const RatingBlockHandler({super.key});

  @override
  State<RatingBlockHandler> createState() => _RatingBlockHandlerState();
}

class _RatingBlockHandlerState extends State<RatingBlockHandler> {
  bool init = true;
  late LanguageProvider languageProvider;
  late RatingBlockProvider ratingBlockProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = context.watch<LanguageProvider>();
      ratingBlockProvider = context.watch<RatingBlockProvider>();
      runnerRtDataProvider = context.watch<RunnerRtDataProvider>();
      Future(() {
        ratingBlockProvider.currentRating = null;
        ratingBlockProvider.reset();
      });
    }
    super.didChangeDependencies();
  }

  Future<void> rateCustomerApi() async {
    try {
      final response = await RunnerHttp.runnerCustomerRating(
        jobId: runnerRtDataProvider.jobId,
        data: {"customer_rating": ratingBlockProvider.currentRating},
      );
      if (response?.statusCode == 200) {
        ClevertapSetup.logEvent(TrackingEvents.ratedCustomerSucessfully, {
          "action": "runner rated the customer",
        });
        runnerRtDataProvider.fetchDataNow();
      } else {
        // error = "Something went wrong";
        if (mounted) {
          showSnackbar(context, "An unexpected error has occurred.");
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context, "An unexpected error has occurred - $e");
      }
    }
  }

  Widget get bottomButtons {
    return Row(
      children: [
        Container(
          width: 1.sw,
          color: AppColors.n0,
          padding: EdgeInsets.all(16.r),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await rateCustomerApi();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.g40,
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      'submit',
                      'Submit',
                    ),
                  ),
                ),
              ),
              if (ratingBlockProvider.currentRating != null &&
                  ratingBlockProvider.currentRating! <= 2)
                SizedBox(width: 16.r),
              if (ratingBlockProvider.currentRating != null &&
                  ratingBlockProvider.currentRating! <= 2)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      JobLifecycleAnalytics.logEvent(
                          TrackingEvents.ratingCustomerBlockCta, {
                        'rating_value': ratingBlockProvider.currentRating,
                      });
                      showModalBottomSheet(
                        context: context,
                        builder: (_) {
                          return const CommonBottomSheetSetup(
                            child: BlockBottomSheet(),
                          );
                        },
                      ).then((_) {
                        if (ratingBlockProvider.currentBlockState ==
                            BlockState.customerBlocked) {
                          runnerRtDataProvider.fetchDataNow();
                        }
                        Future.delayed(const Duration(milliseconds: 500))
                            .then((_) {
                          /// Delayed is added to avoid jarring experience
                          ratingBlockProvider.reset();
                        });
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.r40,
                      backgroundColor: AppColors.n0,
                      side: const BorderSide(color: AppColors.r40),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.block_flipped,
                            color: AppColors.r40,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            languageProvider.getMessage(
                              "block_customer",
                              "Block customer",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void setBottomButtons() {
    if (ratingBlockProvider.currentRating != null) {
      Future(() {
        runnerRtDataProvider.updateBottomButtonJobProgress(bottomButtons);
      });
    } else {
      Future(() {
        runnerRtDataProvider.updateBottomButtonJobProgress(null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    setBottomButtons();
    return Column(
      children: [
        Text(
          languageProvider.getMessage(
            "rate_customer",
            "How was your experience?",
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: 30.h),
        RatingStars(
          onRatingSelected: (val) async {
            ratingBlockProvider.currentRating = val;
            JobLifecycleAnalytics.logEvent(TrackingEvents.ratingEmojiSelect, {
              'rating_value': val,
            });
          },
        ),
      ],
    );
  }
}

class RatingStars extends StatefulWidget {
  final Function(int) onRatingSelected;

  const RatingStars({required this.onRatingSelected, super.key});

  @override
  State<RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<RatingStars> {
  bool init = true;
  late RatingBlockProvider ratingBlockProvider;

  final List<String> _starAssets = [
    AssetConstants.star1,
    AssetConstants.star2,
    AssetConstants.star3,
    AssetConstants.star4,
    AssetConstants.star5,
  ];

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      ratingBlockProvider = context.watch<RatingBlockProvider>();
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_starAssets.length, (index) {
        final rating = index + 1;
        final isSelected = ratingBlockProvider.currentRating == rating;

        return GestureDetector(
          onTap: () {
            widget.onRatingSelected(rating);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: !isSelected && ratingBlockProvider.currentRating != null
                  ? 0.3
                  : 1,
              child: SvgPicture.asset(
                _starAssets[index],
                height: isSelected ? 55.h : 46.h,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class BlockBottomSheet extends StatefulWidget {
  const BlockBottomSheet({super.key});

  @override
  State<BlockBottomSheet> createState() => _BlockBottomSheetState();
}

class _BlockBottomSheetState extends State<BlockBottomSheet> {
  bool init = true;
  bool loading = false;
  late LanguageProvider languageProvider;
  late RatingBlockProvider ratingBlockProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = context.watch<LanguageProvider>();
      ratingBlockProvider = context.watch<RatingBlockProvider>();
      runnerRtDataProvider = context.watch<RunnerRtDataProvider>();
    }
    super.didChangeDependencies();
  }

  Widget get mainWidget {
    switch (ratingBlockProvider.currentBlockState) {
      case BlockState.blockCustomer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 30.h),
            Text(
              languageProvider.getMessage(
                'block_customer_warning_title',
                'Are you sure you want to block?',
              ),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 21.sp,
                  ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 12.h,
                bottom: 28.h,
              ),
              child: Text(
                languageProvider.getMessage(
                  'block_customer_warning_subtitle',
                  'Blocked customer won’t be able to book you in future.',
                ),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.n60,
                    ),
              ),
            ),
            SizedBox(
              width: 1.sw,
              child: ElevatedButton(
                onPressed: () async {
                  // if (blockedCustomers.length < 5) {
                  setState(() {
                    loading = true;
                  });
                  Response? response = await blockCustomer(
                      runnerRtDataProvider.widgetInfo?.data?['customer_id'],
                      runnerRtDataProvider.widgetInfo?.data?['job_id']);
                  setState(() {
                    loading = false;
                  });
                  if (response != null && response.statusCode == 200) {
                    rateCustomerApi(runnerRtDataProvider, ratingBlockProvider);
                    ratingBlockProvider.currentBlockState =
                        BlockState.customerBlocked;
                    Future.delayed(const Duration(seconds: 4)).then((_) {
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    });
                    await ClevertapSetup.logEvent(
                        TrackingEvents.blockedCustomer, {
                      "action": "block customer feature used",
                    });
                  } else {
                    try {
                      final error =
                          ResponseError.fromMap(response?.data).errors![0];
                      if (error.errorMessageCode ==
                          ServerError.MAX_CUSTOMERS_BLOCKED.name) {
                        ratingBlockProvider.currentBlockState =
                            BlockState.manageBlockList;
                      } else {
                        throw "${error.message}";
                      }
                    } catch (e) {
                      ratingBlockProvider.error = "$e";
                      ratingBlockProvider.currentBlockState = BlockState.error;
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.r40,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.block_flipped,
                      color: AppColors.n0,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      languageProvider.getMessage(
                        "block_customer",
                        "Block customer",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 1.sw,
              padding: EdgeInsets.only(
                top: 8.h,
                bottom: 32.h,
              ),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.n90,
                  side: const BorderSide(color: AppColors.n90),
                ),
                child: Text(
                  languageProvider.getMessage(
                    'go_back',
                    'Go back',
                  ),
                ),
              ),
            ),
          ],
        );
      case BlockState.error:
        return SizedBox(
            height: 0.2.sh,
            child: Center(
                child: Text(
              ratingBlockProvider.error ?? "Something went wrong",
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.r40),
            )));
      case BlockState.customerBlocked:
        return Column(
          children: [
            SizedBox(height: 38.h),
            Container(
              height: 48.r,
              decoration: const BoxDecoration(
                color: AppColors.g40,
                shape: BoxShape.circle,
              ),
              padding: EdgeInsets.all(10.r),
              child: const FittedBox(
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.n0,
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              languageProvider.getMessage(
                'customer_blocked',
                'Customer blocked',
              ),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: EdgeInsets.only(
                top: 8.h,
                bottom: 32.h,
              ),
              child: const RatingCustomerInfo(),
            ),
          ],
        );
      case BlockState.manageBlockList:
        return ManageBlockList(
          closePopup: () {
            Future.delayed(const Duration(seconds: 4)).then((_) {
              if (mounted) {
                Navigator.of(context).pop();
              }
            });
          },
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? SizedBox(
            height: 0.3.sh,
            child: const CupertinoActivityIndicator(),
          )
        : mainWidget;
  }
}

class RatingCustomerInfo extends StatelessWidget {
  const RatingCustomerInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RunnerRtDataProvider>(
        builder: (context, runnerRtDataProvider, _) {
      return Container(
        width: 1.sw,
        padding: EdgeInsets.symmetric(
          vertical: 12.h,
          horizontal: 8.w,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.n40),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              runnerRtDataProvider.widgetInfo?.data?['customer_name'] ??
                  "Snabbit Customer",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (runnerRtDataProvider.widgetInfo?.data?['customer_address'] !=
                null)
              Text(
                runnerRtDataProvider.widgetInfo?.data?['customer_address'] ??
                    "",
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.n80),
              ),
          ],
        ),
      );
    });
  }
}

class BlockedCustomerInfo extends StatelessWidget {
  final BlockedCustomer blockedCustomer;

  const BlockedCustomerInfo({super.key, required this.blockedCustomer});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          blockedCustomer.name ?? "Snabbit Customer",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (blockedCustomer.address != null)
          Text(
            blockedCustomer.address ?? "",
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.n80),
          ),
      ],
    );
  }
}

class ManageBlockList extends StatefulWidget {
  final VoidCallback closePopup;

  const ManageBlockList({
    super.key,
    required this.closePopup,
  });

  @override
  State<ManageBlockList> createState() => _ManageBlockListState();
}

class _ManageBlockListState extends State<ManageBlockList> {
  bool init = true;
  bool loading = true;
  List<BlockedCustomer>? blockedCustomers;
  late RatingBlockProvider ratingBlockProvider;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      ratingBlockProvider = context.watch<RatingBlockProvider>();
      languageProvider = context.watch<LanguageProvider>();
      runnerRtDataProvider = context.watch<RunnerRtDataProvider>();
      if (mounted) {
        initProcess().then((_) {
          loading = false;
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    try {
      Response? response = await JobHttp.getBlockedCustomers();
      if (response != null && response.statusCode == 200) {
        blockedCustomers = response.data.map<BlockedCustomer>((e) {
          return BlockedCustomer.fromJson(e);
        }).toList();
      } else {
        throw "";
      }
    } catch (e) {
      Future(() {
        ratingBlockProvider.currentBlockState = BlockState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? SizedBox(
            height: 0.3.sh,
            child: const CupertinoActivityIndicator(),
          )
        : Column(
            children: [
              SizedBox(height: 30.h),
              Transform.flip(
                flipY: true,
                child: Icon(
                  Icons.info_rounded,
                  color: AppColors.r40,
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                "${languageProvider.getMessage(
                  'unblock_someone_to_block',
                  'Unblock someone to block customer',
                )}:",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 12.h),
              const RatingCustomerInfo(),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageProvider.getMessage(
                        'block_list',
                        'Block List',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (blockedCustomers != null)
                      Text(
                        '${blockedCustomers!.length}/${blockedCustomers!.length} ${languageProvider.getMessage(
                          'customers_blocked',
                          'customers blocked',
                        )}',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.r50,
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                  ],
                ),
              ),
              if ((blockedCustomers?.length ?? 0) > 0)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: blockedCustomers!.length,
                  itemBuilder: (_, index) {
                    final blockedCustomer = blockedCustomers![index];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BlockedCustomerInfo(
                          blockedCustomer: blockedCustomer,
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            JobLifecycleAnalytics.logEvent(
                                TrackingEvents.ratingCustomerUnblockCta, {
                              'unblocked_customer_id': blockedCustomer.id,
                            });
                            setState(() {
                              loading = true;
                            });
                            try {
                              Response? unblockResponse = await unblockCustomer(
                                  blockedCustomer.id,
                                  runnerRtDataProvider
                                      .widgetInfo?.data?['job_id']);
                              if (unblockResponse?.statusCode == 200) {
                                Response? blockResponse = await blockCustomer(
                                    runnerRtDataProvider
                                        .widgetInfo?.data?['customer_id'],
                                    runnerRtDataProvider
                                        .widgetInfo?.data?['job_id']);
                                if (blockResponse?.statusCode == 200) {
                                  rateCustomerApi(runnerRtDataProvider, ratingBlockProvider);
                                  ratingBlockProvider.currentBlockState =
                                      BlockState.customerBlocked;
                                  widget.closePopup();
                                } else {
                                  final error =
                                      ResponseError.fromMap(blockResponse?.data)
                                          .errors![0];
                                  if (error.errorMessageCode ==
                                      ServerError.MAX_CUSTOMERS_BLOCKED.name) {
                                    await initProcess();
                                    ratingBlockProvider.currentBlockState =
                                        BlockState.manageBlockList;
                                  } else {
                                    throw "${error.message}";
                                  }
                                }
                              } else {
                                final error =
                                    ResponseError.fromMap(unblockResponse?.data)
                                        .errors![0];
                                throw "${error.message}";
                              }
                            } catch (e) {
                              ratingBlockProvider.error = "$e";
                              ratingBlockProvider.currentBlockState =
                                  BlockState.error;
                            }
                            setState(() {
                              loading = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.n90,
                            side: const BorderSide(color: AppColors.n40),
                          ),
                          child: Text(
                            languageProvider.getMessage(
                              'unblock',
                              'Unblock',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  separatorBuilder: (_, __) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      child: Divider(
                        color: AppColors.n30,
                        height: 1.h,
                      ),
                    );
                  },
                ),
              SizedBox(height: 32.h),
            ],
          );
  }
}

class BlockedCustomer {
  int id;
  String? name;
  String? address;

  BlockedCustomer({
    required this.id,
    this.name,
    this.address,
  });

  factory BlockedCustomer.fromJson(Map<String, dynamic> json) {
    return BlockedCustomer(
      id: json['customer']['id'],
      name: json['customer']?['user']?['name'],
      address: json['job']?['booking']?['address_str'],
    );
  }
}

Future<Response?> blockCustomer(int? customerId, int? jobId) async {
  Response? response = await JobHttp.blockCustomer(data: {
    "pref_type": "BLACKLISTED",
    "customer_id": customerId,
    "job_id": jobId,
  });
  return response;
}

Future<Response?> unblockCustomer(int? customerId, int? jobId) async {
  Response? response = await JobHttp.blockCustomer(data: {
    "pref_type": null,
    "customer_id": customerId,
    "job_id": jobId,
  });
  return response;
}

Future<void> rateCustomerApi(RunnerRtDataProvider runnerRtDataProvider,
    RatingBlockProvider ratingBlockProvider) async {
  try {
    final response = await RunnerHttp.runnerCustomerRating(
      jobId: runnerRtDataProvider.jobId,
      data: {"customer_rating": ratingBlockProvider.currentRating},
    );
    if (response?.statusCode == 200) {
      ClevertapSetup.logEvent(TrackingEvents.ratedCustomerSucessfully, {
        "action": "runner rated the customer",
      });
    }
  } catch (e) {
    // DO NOTHING
  }
}
