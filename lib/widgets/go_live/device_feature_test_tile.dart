import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart'; // For responsive sizing


enum _TestResult {
  success,
  failure,
  none,
}

class DeviceFeatureTestTile extends StatefulWidget {
  final String leadingIcon;
  final String titleText;
  final String titleKey;
  final Widget Function(VoidCallback onSuccess, VoidCallback onFailure) expandedContentBuilder; // Optional content for expansion
  final bool? isExpanded; // Optional initial expansion state
  final bool? reset;

  const DeviceFeatureTestTile({
    super.key,
    required this.leadingIcon,
    required this.titleText,
    required this.titleKey,
    required this.expandedContentBuilder,
    this.isExpanded,
    this.reset,
  });

  @override
  State<DeviceFeatureTestTile> createState() => _DeviceFeatureTestTileState();
}

class _DeviceFeatureTestTileState extends State<DeviceFeatureTestTile> {
  late bool _isExpanded;
  // bool _isTested = false;
  _TestResult _testStatus = _TestResult.none;
  bool init=true;

  bool get isExpanded => widget.isExpanded ?? _isExpanded;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
   if(init){
      init = false;
      _isExpanded = widget.isExpanded ?? false;
      languageProvider = Provider.of<LanguageProvider>(context,listen: true);
   }
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant DeviceFeatureTestTile oldWidget) {
    if(widget.isExpanded==true) {
      _isExpanded = widget.isExpanded ?? false; // Update expansion state if changed
    }
    if(widget.reset == true) {
      _testStatus = _TestResult.none; // Update expansion state if changed
    }
    super.didUpdateWidget(oldWidget);
  }


  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Initialize ScreenUtil for responsive sizing (assuming it's set up in main.dart)
    return AnimatedContainer(
      decoration: BoxDecoration(
        color: AppColors.n0, // Figma: background: #FFFFFF;
        border: Border.all(
          color: AppColors.n40, // Figma: border: 0.916481px solid #D8DAE5;
          width: 0.916481.w,
        ),
        borderRadius: BorderRadius.circular(12.r), // Figma: border-radius: 12px;
      ),
      duration: Duration(milliseconds: 1000),
      curve: Curves.easeInOut, // Smooth transition for expansion
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              // setState(() {
              //   _isExpanded = !_isExpanded; // Toggle expansion state
              // });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Row( // Using Row as requested, mimicking ListTile structure
                children: [
                  SizedBox(width: 16.w), // Figma: left: 16px; for icon
                  Expanded(child: Row(
                    children: [
                      SvgPicture.asset(
                        widget.leadingIcon,
                        height: 29.r, // Figma: width: 29px; height: 29px;
                        color: Colors.black, // From Figma: border: 2px solid #000000; (implies icon color)
                      ),
                      SizedBox(width: 8.w), // Gap between icon and text (estimated from Figma)
                      // Title Text (Recurrence Detail Text)
                      Flexible( // Use Expanded to allow text to take available space
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            languageProvider.getMessage(widget.titleKey, widget.titleText),
                            style: textTheme.labelMedium?.copyWith(
                              height: 12 / 13, // Figma: line-height: 12px; (calculated)
                              color: AppColors.n80, // Figma: color: #525871;
                            ),
                            overflow: TextOverflow.ellipsis, // Handle long text
                          ),
                        ),
                      ),
                    ],
                  ),),
                  SizedBox(width: 8.w), // Gap before checkbox (estimated)
                  // Trailing Circular Checkbox
                  // Figma: background: #52BD94; border-radius: 53.1471px;
                  // Figma: border: 1.52941px solid #FFFFFF; border-radius: 0.764706px; for the checkmark
                  if(!_isExpanded)
                  Container(
                    width: 26.r, // Figma: width: 26px; height: 26px;
                    height: 26.r,
                    decoration: BoxDecoration(
                      color: _backgroundColor, // Green/G30 when checked
                      shape: BoxShape.circle, // Figma: border-radius: 53.1471px; (implies circle)
                      border: _testStatus!= _TestResult.none
                          ? Border.all(color: AppColors.n0, width: 1.52941.w,) // White border when checked
                          : null,
                    ),
                    child: _getTrailingIcon(),
                  ),
                  SizedBox(width: 16.w), // Right padding (estimated from Figma)
                ],
              ),
            ),
          ),
          if(_isExpanded) Padding(
            padding: EdgeInsets.symmetric(vertical: 32.h),
            child: _expandedContent,
          ),
        ],
      ),
    );
  }

  Widget get _expandedContent {
    if(_testStatus==_TestResult.none){
      return widget.expandedContentBuilder(
            () {
          setState(() {
            _testStatus = _TestResult.success;
          });
          Future.delayed(const Duration(milliseconds: 1000), () {
            setState(() {
              _isExpanded = false; // Collapse after success
            });
          });
        },
            () {
          setState(() {
            _testStatus = _TestResult.failure;
          });
          Future.delayed(const Duration(milliseconds: 1000), () {
            setState(() {
              _isExpanded = false; // Collapse after success
            });
          });
        },
      );
    } else{
      Widget icon;
      String text,key;
      if (_testStatus==_TestResult.success){
        icon= CircleAvatar(
          backgroundColor: AppColors.g30,
          radius: 69.5.r,
          child: Icon(
            Icons.check,
            color: AppColors.n0,
            size: 69.r, // Adjusted size for better visibility
          ),
        );
        key='test_passed';
        text = 'Test passed'; // Text for success
      } else{
        icon= CircleAvatar(
          backgroundColor: AppColors.r40,
          radius: 69.5.r,
          child: Icon(
            Icons.close,
            color: AppColors.n0,
            size: 45.r, // Adjusted size for better visibility
          ),
        );
        key='test_failed';
        text = 'Test failed'; // Text for failure
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children:[
          icon,
          SizedBox(height: 16.h),
          Flexible(
            child: FittedBox(
              child: Text(
                languageProvider.getMessage(
                  key,
                  text,
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16.sp, // Figma: font-size: 16px;
                  letterSpacing: -1, // Figma: letter-spacing: -1px;
                  color: AppColors.n80, // Figma: color: #525871;
                ),
              ),
            ),
          )
        ]
      );
    }
  }

  Color get _backgroundColor {
    if (_testStatus == _TestResult.success) {
      return AppColors.g30; // Green background for success
    } else if (_testStatus == _TestResult.failure) {
      return AppColors.r40; // Red background for failure
    } else {
      return AppColors.n40; // Default background color
    }
  }
    Widget? _getTrailingIcon() {
      if (_testStatus == _TestResult.success) {
        return Icon(
          Icons.check, // Checkmark icon
          color: AppColors.n0, // White checkmark
          size: 13.r, // Figma: width: 13px; height: 9.94px; (approximate)
        );
      } else if (_testStatus == _TestResult.failure) {
        return Icon(
          Icons.close,
          color: AppColors.n0,
          size: 13.r, // Adjusted size for better visibility
        );
      }
      return null;
    }
}
