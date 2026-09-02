import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';

class WorkScheduleSelection extends StatefulWidget {
  const WorkScheduleSelection({
    super.key,
  });

  @override
  WorkScheduleSelectionState createState() => WorkScheduleSelectionState();
}

class WorkScheduleSelectionState extends State<WorkScheduleSelection> {
  bool _isPopupOpen = false;
  WorkSchedule? _selectedItem;

  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      _selectedItem = userProfileProvider.user?.workSchedule?.value;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPopupOpen = true;
        });
        showWorkSchedulePopup(context).then(
          (value) {
            setState(() {
              _isPopupOpen = false;
              if(value!=null){
                _selectedItem = value;
              }
            });
          },
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 16.h),
        decoration: BoxDecoration(
          border:
              Border.all(color: _isPopupOpen ? AppColors.brand : AppColors.n30),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedItem?.originalText ?? '', // Display T.name
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color:
                        _selectedItem == null ? AppColors.n50 : AppColors.n90,
                  ),
            ),
            Icon(
              _isPopupOpen ? Icons.expand_less : Icons.expand_more,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

class WorkSchedulePopup extends StatefulWidget {
  const WorkSchedulePopup({super.key});

  @override
  State<WorkSchedulePopup> createState() => _WorkSchedulePopupState();
}

class _WorkSchedulePopupState extends State<WorkSchedulePopup> {
  WorkSchedule? _selected;

  late List<WorkSchedule> _workSchedules;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      _workSchedules = GlobalState().appConfig?.workSchedules ?? [];
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      _selected = userProfileProvider.user?.workSchedule?.value;
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D1D1),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),

          // Title
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              languageProvider.getMessage('work_schedule', "Work schedule"),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          SizedBox(height: 24.h),

          // Weekend only option
          if (_workSchedules.isNotEmpty)
            ..._workSchedules.map(
              (schedule) => WorkScheduleOption(
                option: schedule,
                isSelected: _selected == schedule,
                onTap: () {
                  setState(() {
                    _selected = schedule;
                  });
                },
              ),
            ),

          SizedBox(height: 16.h),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.brand),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(
                    languageProvider.getMessage('go_back', "Go back"),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.brand,
                        ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  onPressed: () {
                    userProfileProvider.user?.workSchedule?.value = _selected;
                    userProfileProvider.notifyUserListeners();
                    Navigator.pop(context, _selected);
                  },
                  child: Text(
                    languageProvider.getMessage('confirm', "Confirm"),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.n0,
                        ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}

/// Custom radio circle
class _RadioCircle extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _RadioCircle({required this.isSelected, required this.onTap,});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24.r,
        height: 24.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected? AppColors.brand : AppColors.n40,
            width: 2.r,
          ),
        ),
        child: isSelected
            ? Center(
                child: Container(
                  width: 14.r,
                  height: 14.r,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brand,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// Function to show the popup in a modal sheet
Future<WorkSchedule?> showWorkSchedulePopup(BuildContext context) {
  return showModalBottomSheet<WorkSchedule>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const WorkSchedulePopup(),
  );
}

class WorkScheduleOption extends StatelessWidget {
  final WorkSchedule option;
  final bool isSelected;
  final VoidCallback onTap;

  const WorkScheduleOption({
    super.key,
    required this.option,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          _RadioCircle(
            isSelected: isSelected,
            onTap: onTap,
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Text(
              option.originalText ?? '',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.n80,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
