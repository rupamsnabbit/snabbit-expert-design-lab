import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';

class GoldenTextWidget extends StatelessWidget {
  final String? text;
  final Map<String, dynamic>? textData;
  final double fontSize;

  const GoldenTextWidget._({
    super.key,
    this.text,
    this.textData,
    this.fontSize = 32,
  });

  // Named constructor for simple text
  const GoldenTextWidget.fromText({
    key,
    required String text,
    double fontSize = 32,
  }) : this._(
          text: text,
          fontSize: fontSize,
        );

  // Named constructor for JSON data
  const GoldenTextWidget.fromCustomText({
    key,
    required Map<String, dynamic> textData,
    double fontSize = 32,
  }) : this._(
          textData: textData,
          fontSize: fontSize,
        );

  @override
  Widget build(BuildContext context) {
    // Handle simple text
    if (text != null) {
      return _buildGoldenText(context, ' $text! ', fontSize);
    }

    // Handle JSON data
    if (textData == null || textData!.isEmpty) {
      return const SizedBox.shrink();
    }

    final fallbackText = textData?['text'] ?? '';
    if (fallbackText.isEmpty) {
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
        localizedText = fallbackText;
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

      return _buildGoldenText(context, ' $finalText ', fontSize);
    } catch (e) {
      // Fallback to simple text if parsing fails
      return _buildGoldenText(context, ' $fallbackText ', fontSize);
    }
  }

  static Widget _buildGoldenText(
      BuildContext context, String displayText, double fontSize) {
    return Stack(
      children: [
        // Thick reddish-brown shadow for 3D effect
        Positioned(
          left: 3.w,
          top: 3.h,
          child: Text(
            displayText,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF8F1801), // Dark reddish-brown shadow
                ),
          ),
        ),

        // Main golden text with gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0xFFFDED66),
              Color(0xFFFAAA02),
            ],
            stops: [0.0, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            displayText,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [
                const Shadow(
                  color: Color(0xFFB8860B), // Dark golden outline
                  offset: Offset(0, 0),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
