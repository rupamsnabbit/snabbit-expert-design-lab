import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../utils/common_methods.dart';
import 'models.dart';

class CustomText extends StatelessWidget {
  final Map<String, dynamic>? textData;

  const CustomText({
    super.key,
    this.textData,
  });

  @override
  Widget build(BuildContext context) {
    if (textData == null) return const SizedBox();
    try {
      final config = CustomTextConfig.fromMap(textData!);
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      return _buildRichText(context, config, languageProvider);
    } catch (e) {
      // Fallback to simple text if parsing fails
      return Text(
        textData?['text'] ?? '',
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: getTextAlignFromString(textData?['alignment']),
      );
    }
  }

  Widget _buildRichText(BuildContext context, CustomTextConfig config,
      LanguageProvider languageProvider) {
    final List<InlineSpan> spans = [];

    // Get the text using key -> text -> SizedBox() fallback
    String? remainingText;
    if (config.key != null) {
      remainingText =
          languageProvider.getMessage(config.key!, config.text ?? config.key!);
    } else if (config.text != null) {
      remainingText = config.text;
    }

    // If no text available, return empty widget
    if (remainingText == null || remainingText.isEmpty) {
      return const SizedBox();
    }

    // Create a map for quick lookup of replacement data
    final Map<String, CustomTextData> replacementMap = {};
    for (final data in config.data) {
      replacementMap[data.key] = data;
    }

    // Find all placeholders in the text
    final RegExp placeholderPattern = RegExp(r'\{\{([^}]+)\}\}');
    final matches = placeholderPattern.allMatches(remainingText).toList();

    int lastIndex = 0;

    for (final match in matches) {
      // Add text before the placeholder as a regular TextSpan
      if (match.start > lastIndex) {
        final beforeText = remainingText.substring(lastIndex, match.start);
        if (beforeText.isNotEmpty) {
          spans.add(TextSpan(
            text: beforeText,
            style: _buildTextStyle(context, config.style),
          ));
        }
      }

      // Get the placeholder key (without the braces)
      final placeholderKey = match.group(1) ?? '';
      final replacementData = replacementMap[placeholderKey];

      if (replacementData != null) {
        // Create a styled widget for the replacement text
        // The text comes from language provider using the replacement data's language key
        spans.add(WidgetSpan(
          child: _buildStyledText(context, replacementData, config.style,
              config.alignment, languageProvider),
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
        ));
      } else {
        // If no replacement found, try to get value from language provider as fallback
        String fallbackText =
            languageProvider.getMessage(placeholderKey, match.group(0) ?? '');
        spans.add(TextSpan(
          text: fallbackText,
          style: _buildTextStyle(context, config.style),
        ));
      }

      lastIndex = match.end;
    }

    // Add any remaining text after the last placeholder
    if (lastIndex < remainingText.length) {
      final afterText = remainingText.substring(lastIndex);
      if (afterText.isNotEmpty) {
        spans.add(TextSpan(
          text: afterText,
          style: _buildTextStyle(context, config.style),
        ));
      }
    }

    // If no placeholders were found, just return the original text
    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: remainingText,
        style: _buildTextStyle(context, config.style),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: getTextAlignFromString(config.alignment),
    );
  }

  Widget _buildStyledText(
      BuildContext context,
      CustomTextData data,
      CustomTextStyle? baseStyle,
      String? alignment,
      LanguageProvider languageProvider) {
    // Get the text using key -> text fallback for data items
    String displayText =
        languageProvider.getMessage(data.key, data.text ?? data.key);

    return Text(
      displayText,
      style: _buildTextStyle(context, data.style, fallbackStyle: baseStyle),
      textAlign: getTextAlignFromString(alignment),
    );
  }

  TextStyle? _buildTextStyle(BuildContext context, CustomTextStyle? style,
      {CustomTextStyle? fallbackStyle}) {
    // Apply custom style properties
    final effectiveStyle = style ?? fallbackStyle;
    if (effectiveStyle == null) {
      // Default to bodyMedium if no style is provided
      return Theme.of(context).textTheme.bodyMedium;
    }

    // Start with the named theme style if provided, otherwise use bodyMedium
    TextStyle baseTextStyle;
    if (effectiveStyle.name != null) {
      baseTextStyle = getThemeTextStyleByName(context, effectiveStyle.name) ??
          Theme.of(context).textTheme.bodyMedium ??
          const TextStyle();
    } else {
      baseTextStyle =
          Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    }

    return baseTextStyle.copyWith(
      fontSize: effectiveStyle.fontSize?.sp,
      color: hexToColor(effectiveStyle.color),
      fontWeight: mapIntToFontWeight(effectiveStyle.weight),
      fontStyle: effectiveStyle.style == 'italic' ? FontStyle.italic : null,
    );
  }
}

class CustomTextNS extends StatelessWidget {
  final Map<String, dynamic>? textData;
  final List<Map<String, dynamic>?>? textDataList;
  final String? separator;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  const CustomTextNS(
    this.textData, {
    super.key,
    this.textDataList,
    this.separator,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
  });

  @override
  Widget build(BuildContext context) {
    // Handle list of text data with separator
    if (textDataList != null && textDataList!.isNotEmpty) {
      try {
        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);

        final List<String> processedTexts = [];

        for (final data in textDataList!) {
          if (data == null) continue;
          final text = data['text'] ?? '';
          if (text.isEmpty) continue;

          // Get the localized text using key -> text fallback
          String localizedText;
          if (data['key'] != null) {
            localizedText = languageProvider.getMessage(
                data['key'], data['text'] ?? data['key']);
          } else {
            localizedText = text;
          }

          // Get replacement data
          final List<dynamic> dataList = data['data'] ?? [];
          final Map<String, String> replacementMap = {};

          for (final item in dataList) {
            if (item is Map<String, dynamic>) {
              final key = item['key'] ?? '';
              final value = item['text'] ?? '';
              if (key.isNotEmpty) {
                replacementMap[key] = value;
              }
            }
          }

          // Replace placeholders in the format {{key}}
          String finalText = localizedText;
          replacementMap.forEach((key, value) {
            finalText = finalText.replaceAll('{{$key}}', value);
          });

          processedTexts.add(finalText);
        }

        final combinedText = processedTexts.join(separator ?? '');

        return Text(
          combinedText,
          style: style ?? Theme.of(context).textTheme.bodyMedium,
          strutStyle: strutStyle,
          textAlign: textAlign,
          textDirection: textDirection,
          locale: locale,
          softWrap: softWrap,
          overflow: overflow,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
        );
      } catch (e) {
        return const SizedBox.shrink();
      }
    }

    // Handle single text data (original behavior)
    if (textData == null || textData!.isEmpty) {
      return const SizedBox.shrink();
    }

    final text = textData?['text'] ?? '';
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);

      // Get the localized text using key -> text fallback
      String localizedText;
      if (textData?['key'] != null) {
        localizedText = languageProvider.getMessage(
            textData!['key'], textData!['text'] ?? textData!['key']);
      } else {
        localizedText = text;
      }

      // Get replacement data
      final List<dynamic> dataList = textData?['data'] ?? [];
      final Map<String, String> replacementMap = {};

      for (final item in dataList) {
        if (item is Map<String, dynamic>) {
          final key = item['key'] ?? '';
          final value = item['text'] ?? '';
          if (key.isNotEmpty) {
            replacementMap[key] = value;
          }
        }
      }

      // Replace placeholders in the format {{key}}
      String finalText = localizedText;
      replacementMap.forEach((key, value) {
        finalText = finalText.replaceAll('{{$key}}', value);
      });

      return Text(
        finalText,
        style: style ?? Theme.of(context).textTheme.bodyMedium,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
      );
    } catch (e) {
      // Fallback to simple text if parsing fails
      return Text(
        textData?['text'] ?? '',
        style: style ?? Theme.of(context).textTheme.bodyMedium,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
      );
    }
  }
}
