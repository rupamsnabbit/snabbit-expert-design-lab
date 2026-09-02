import 'package:snabbit_runner/models/onboarding_question_data.dart';

/// Data class for consent text display
class ConsentTextData {
  final String url;
  final String text;
  final String question;

  const ConsentTextData({
    required this.url,
    required this.text,
    required this.question,
  });

  /// Creates ConsentTextData from OnboardingQuestionData
  /// Returns default object with empty strings if parsing fails
  factory ConsentTextData.fromQuestionData(
      OnboardingQuestionData questionData) {
    try {
      final questionText = questionData.question ?? '';
      final uiConfig = questionData.uiConfig;
      final consentLinkText = uiConfig?['consent_link_text'] ?? '';
      final consentDocumentUrl = uiConfig?['consent_document_url'] ?? '';

      return ConsentTextData(
        url: consentDocumentUrl,
        text: consentLinkText,
        question: questionText,
      );
    } catch (e) {
      // Return default object with empty strings on error
      return const ConsentTextData(
        url: '',
        text: '',
        question: '',
      );
    }
  }
}
