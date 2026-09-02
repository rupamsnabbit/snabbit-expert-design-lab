import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/issue_data.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/server_requests/raise_dispute_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/raise_dispute/text_area_popup.dart';
import 'package:snabbit_runner/widgets/raise_dispute/issue_status_popup.dart';

enum BottomSheetState {
  reportNewIssue,requestReview,overview
}

class BottomSheetViewProvider with ChangeNotifier {
  IssueData? _issueData;
  BottomSheetState _state = BottomSheetState.overview;

  BottomSheetViewProvider();

  IssueData? get issueData => _issueData;
  BottomSheetState? get state => _state;

  void updateState(BottomSheetState newState) {
    _state = newState;
    notifyListeners();
  }

  set issueData(IssueData? data) {
    _issueData=data;
    notifyListeners();
  }

  void reset(){
    _issueData=null;
    _state=BottomSheetState.overview;
  }
}

void showDynamicBottomSheet(BuildContext context) {

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.n0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(12.r),
      ),
    ),

    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // 👈 shifts up with keyboard
        ),
        child: const DynamicBottomSheetContent(),
      );
    },
  ).then((value) {
    if(!context.mounted) return;
    context.read<BottomSheetViewProvider>().updateState(BottomSheetState.overview);
  },);
}

class DynamicBottomSheetContent extends StatefulWidget {
  const DynamicBottomSheetContent({super.key});

  @override
  State<DynamicBottomSheetContent> createState() => _DynamicBottomSheetContentState();
}

class _DynamicBottomSheetContentState extends State<DynamicBottomSheetContent> {

  late BottomSheetViewProvider bottomSheetViewProvider;
  late LanguageProvider languageProvider;
  bool init=true;

  @override
  void didChangeDependencies() {
    if(init){
      init=false;
      bottomSheetViewProvider=Provider.of<BottomSheetViewProvider>(context,listen: true);
      languageProvider=Provider.of<LanguageProvider>(context,listen: true);
    }
    super.didChangeDependencies();
  }

  Widget get currentStateView {
    switch(bottomSheetViewProvider.state){
      case BottomSheetState.reportNewIssue:
        return TextAreaPopup(
          title: languageProvider.getMessage(
              'other_issue_title', 'Write your issue in detail'),
          hintText: languageProvider.getMessage(
              'other_issue_hint_text',
              'Please let us know the reason here'),
          submitButtonText:
          languageProvider.getMessage('submit', 'Submit'),
          review: false,
        );
      case BottomSheetState.requestReview:
        return TextAreaPopup(
          title: languageProvider.getMessage("review_confirmation_title","Review can be made only once. Are you sure?"),
          hintText: languageProvider.getMessage(
              'other_issue_hint_text',
              'Please let us know the reason here'),
          submitButtonText: languageProvider.getMessage('confirm',"Confirm"),
          review: true,
        );
      case BottomSheetState.overview:
        return IssueStatusPopup(issueData: bottomSheetViewProvider.issueData ?? IssueData(),);
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: currentStateView,
    );
  }
}

void showToast(
    BuildContext context, {
      String? message,
    }) {
  if (message == null || message.isEmpty) return;
  Widget toast = Container(
    padding: EdgeInsets.symmetric(vertical: 12.h,horizontal: 26.w,),
    margin: EdgeInsets.symmetric(horizontal: 16.w),
    decoration: BoxDecoration(
      boxShadow: const [
        BoxShadow(
          color: Color(0xFFE7E9F4), // Hex color for shadow
          offset: Offset(0, 4), // Horizontal and vertical offset
          blurRadius: 4, // Blur radius
          spreadRadius: 0, // Spread radius
        ),
      ],
      borderRadius: BorderRadius.circular(12.r),
      color: const Color(0xFF1F1F20).withOpacity(0.8),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 7.5.h,
          backgroundColor: Color(0xFF40935A),
          child: Icon(Icons.check,color: Color(0xFFD9D9D9),size: 10.r,),
        ),
        SizedBox(width: 10.w,),
        Flexible(
          child: Text(
            message ?? "",
            softWrap: true,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xffF5EFF7),
            ),
          ),
        ),
      ],
    ),
  );
  showCustomToast(
      widget: toast,
      bottomPosition: 48.h,
      context: context);
}