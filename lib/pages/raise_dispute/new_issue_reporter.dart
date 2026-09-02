import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/models/issue_data.dart';
import 'package:snabbit_runner/models/issue_type_config.dart';
import 'package:snabbit_runner/pages/raise_dispute/issue_history.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/server_requests/raise_dispute_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/raise_dispute/text_area_popup.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/raise_dispute/bottom_sheet.dart';
import 'package:snabbit_runner/widgets/raise_dispute/issue_card.dart';
import 'package:snabbit_runner/widgets/raise_dispute/issue_selector.dart';
import 'package:snabbit_runner/widgets/raise_dispute/issue_status_popup.dart'; // Using the intl package for date formatting

// The main widget to display the issue history.
class NewIssueReporter extends StatefulWidget {
  static const String routeName = '/new-issue-reporter';

  const NewIssueReporter({Key? key}) : super(key: key);

  @override
  State<NewIssueReporter> createState() => _NewIssueReporterState();
}

class _NewIssueReporterState extends State<NewIssueReporter> {
  bool _isLoading = false;
  String? _selectedIssue;
  late LanguageProvider languageProvider;
  late BottomSheetViewProvider bottomSheetViewProvider;
  bool init = true;
  List<String>? issueTypes;
  late CurrentPeriodProvider periodProvider;
  List<IssueTypeConfig>? issueTypeConfigs;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      periodProvider = Provider.of<CurrentPeriodProvider>(context, listen: true);
      bottomSheetViewProvider =
          Provider.of<BottomSheetViewProvider>(context, listen: true);

      issueTypes = GlobalState().appConfig?.issueTypes ?? [];
      issueTypeConfigs=GlobalState().appConfig?.issueTypeConfigs;
    }
    super.didChangeDependencies();
  }

  bool canContinue() {
    return _selectedIssue != null && !_isLoading;
  }

  bool shouldAddComment(){
    if(_selectedIssue==null || issueTypeConfigs==null) return false;
    final match = issueTypeConfigs?.indexWhere((element) => element.type?.toLowerCase()==_selectedIssue?.toLowerCase(),) ?? -1;
    if(match!=-1){
      return issueTypeConfigs?[match].showTextField==true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        elevation: 5.r,
        centerTitle: true,
      ),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: canContinue()
                ? () async {
                    if (shouldAddComment()) {
                      bottomSheetViewProvider.issueData =
                          IssueData(
                            issueDate: periodProvider.currentDate,
                            issueType: _selectedIssue,
                          );
                      bottomSheetViewProvider
                          .updateState(BottomSheetState.reportNewIssue);
                      showDynamicBottomSheet(
                        context,
                      );
                    } else {
                      try{
                        setState(() {
                          _isLoading=true;
                        });
                        final response = await RaiseDisputeHttp.reportIssue(IssueData(
                          issueDate: periodProvider.currentDate,
                          issueType: _selectedIssue,
                        ),);
                        if (response?.statusCode == 200) {

                          Navigator.pushReplacementNamed(context,IssueHistory.routeName);
                          showToast(context,message: languageProvider.getMessage('issue_has_been_raised', "Issue has been raised"));
                        } else {
                          ErrorHandler.handleResponseError(
                            response: response,
                            context: context,
                            onError: (context, responseError) {
                              final error = responseError.errors?.first;
                              try {
                                bottomSheetViewProvider.issueData =
                                    IssueData.fromJson(error?.data);
                                showDynamicBottomSheet(
                                  context,
                                );
                              } catch (_){
                                showSnackbar(
                                    context, error?.message ?? '');
                              }
                            },
                          );
                        }
                      }catch(e){
                        showSnackbar(
                            context, "Something went wrong - $e");
                      } finally {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }
                  }
                : null,
            child: _isLoading || init
                ? const CupertinoActivityIndicator()
                : Text(
                    languageProvider.getMessage('continue', "Continue"),
                  ),
          ),
        ),
      ],
      body: _isLoading || init
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AssetConstants.reportNewIssue),
                if (issueTypes != null && issueTypes?.isNotEmpty==true)
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16.w,
                        24.h,
                        16.w,
                        0,
                      ),
                      child: IssueSelector(
                        issueTypes: issueTypes ?? [],
                        selectedItem: _selectedIssue,
                        issueDate: periodProvider.currentDate,
                        languageProvider: languageProvider,
                        onSelectionChanged: (value) {
                          String? newValue;
                          if (_selectedIssue != value) {
                            newValue = value;
                          }
                          setState(() {
                            _selectedIssue = newValue;
                          });
                        },
                      ),
                    ),
                  )
                else
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 48.h),
                      child: Text(
                        languageProvider.getMessage(
                            "something_went_wrong", "Something went wrong"),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    bottomSheetViewProvider.reset();
    super.dispose();
  }
}
