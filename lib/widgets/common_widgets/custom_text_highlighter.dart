// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:snabbit_runner/utils/colors.dart';
//
// class CustomTextHighlighter extends StatelessWidget {
//   CustomTextHighlighter({
//     super.key,
//     required this.substitute,
//     required this.text,
//     required this.customHighlighter,
//     this.textStyle,
//     required this.placeholder,
//   });
//
//   final String substitute;
//   final String text;
//   final String placeholder;
//   final Widget Function(String text)
//   customHighlighter;
//   final TextStyle? textStyle;
//
//   @override
//   Widget build(BuildContext context) {
//     List<InlineSpan> content = [];
//     final splitText = splitPlaceholderText(
//       text,
//       placeholder,
//     );
//     for (String text in splitText) {
//       if (text == placeholder) {
//         content.add(WidgetSpan(
//           alignment: PlaceholderAlignment.baseline,
//           baseline: TextBaseline.alphabetic,
//           child: customHighlighter(substitute),
//         ));
//       } else {
//         content.add(TextSpan(text: text,),);
//       }
//     }
//
//     return RichText(
//       text: TextSpan(
//         style: Theme.of(context)
//             .textTheme
//             .bodyMedium
//             ?.copyWith(
//           fontSize: 14.sp,
//           height: 20 / 14,
//           color: AppColors.n0,
//         )
//             .merge(textStyle),
//         children: content,
//       ),
//     );
//   }
//
//   List<String> splitPlaceholderText(String input, String placeholder) {
//     if (!input.contains(placeholder)) {
//       return [input];
//     }
//
//     final parts = input.split(placeholder);
//     final result = <String>[];
//
//     if (parts.first.isNotEmpty) {
//       result.add(parts.first);
//     }
//
//     result.add(placeholder);
//
//     if (parts.length > 1 && parts.last.isNotEmpty) {
//       result.add(parts.last);
//     }
//
//     return result;
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';

class CustomTextHighlighter extends StatelessWidget {
  CustomTextHighlighter({
    super.key,
    required this.text,
    required this.customHighlighter,
    this.textStyle,
    this.textAlign,
  });

  final String text;
  final Widget Function(String text) customHighlighter;
  final TextStyle? textStyle;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> content = _buildSpansFromText(text);

    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14.sp,
          height: 20 / 14,
          color: AppColors.n0,
        ).merge(textStyle),
        children: content,
      ),
    );
  }

  List<InlineSpan> _buildSpansFromText(String input) {
    final RegExp regExp = RegExp(r'{{(.*?)}}');
    final List<InlineSpan> spans = [];

    int start = 0;

    for (final match in regExp.allMatches(input)) {
      if (match.start > start) {
        // Add plain text before match
        spans.add(TextSpan(text: input.substring(start, match.start)));
      }

      final matchText = match.group(1); // Extract inside of {{ }}
      if (matchText != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: customHighlighter(matchText),
          ),
        );
      }

      start = match.end;
    }

    if (start < input.length) {
      // Add remaining text
      spans.add(TextSpan(text: input.substring(start)));
    }

    return spans;
  }
}
