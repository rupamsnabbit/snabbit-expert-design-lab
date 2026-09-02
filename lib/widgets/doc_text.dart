import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/colors.dart';
import 'pdf_view.dart';

class CustomText {
  final String key;
  final String text;
  final String? url;

  CustomText({
    required this.key,
    required this.text,
    this.url,
  });

  factory CustomText.fromJson(Map<String, dynamic> json) {
    return CustomText(
      key: json['key'],
      text: json['text'],
      url: json['url'],
    );
  }
}

class RichDocText extends StatelessWidget {
  final String text;
  final List<CustomText> data;
  final TextStyle? style;
  final void Function(String linkKey)? onLinkTap;

  const RichDocText({
    super.key,
    required this.text,
    required this.data,
    this.style,
    this.onLinkTap,
  });

  factory RichDocText.fromJson(
    Map<String, dynamic> json, {
    TextStyle? style,
    void Function(String linkKey)? onLinkTap,
  }) {
    return RichDocText(
      text: json['text'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => CustomText.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      style: style,
      onLinkTap: onLinkTap,
    );
  }

  List<InlineSpan> _parseTextToSpans(BuildContext context) {
    final List<InlineSpan> spans = [];
    final RegExp placeholderRegex = RegExp(r'\{\{([^}]+)\}\}');
    String remainingText = text;
    int lastEnd = 0;

    for (final match in placeholderRegex.allMatches(text)) {
      // Add text before the placeholder as TextSpan
      if (match.start > lastEnd) {
        final beforeText = text.substring(lastEnd, match.start);
        if (beforeText.isNotEmpty) {
          spans.add(TextSpan(
            text: beforeText,
            style: style ?? Theme.of(context).textTheme.bodyMedium,
          ));
        }
      }

      // Find the corresponding data for this placeholder
      final placeholderKey = match.group(1);
      final docData = data.firstWhere(
        (item) => item.key == placeholderKey,
        orElse: () => CustomText(
          key: placeholderKey ?? '',
          text: placeholderKey ?? '',
        ),
      );

      // Add the DocText as WidgetSpan
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InkWell(
          onTap: docData.url != null
              ? () {
                  onLinkTap?.call(docData.key);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PdfViewPage(
                        url: docData.url ?? "",
                      ),
                    ),
                  );
                }
              : null,
          child: Text(
            docData.text,
            style: (style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
              decoration: TextDecoration.underline,
              color: AppColors.n80,
              height: 1.h,
            ),
          ),
        ),
      ));

      lastEnd = match.end;
    }

    // Add remaining text after the last placeholder
    if (lastEnd < text.length) {
      final remainingPart = text.substring(lastEnd);
      if (remainingPart.isNotEmpty) {
        spans.add(TextSpan(
          text: remainingPart,
          style: style ?? Theme.of(context).textTheme.bodyMedium,
        ));
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      softWrap: true,
      text: TextSpan(

        children: _parseTextToSpans(context),
      ),
    );
  }
}
