import 'package:snabbit_runner/services/integrity_test/enums.dart';

class IntegrityTest {
  final String? questionText;
  final String? questionLabel;
  final QuestionType? questionType;
  final AnswerType? answerType;
  final String? leftOptionLabel;
  final String? rightOptionLabel;
  final bool? isActive;
  final List<AnswerOption>? answerOptions;
  final int id;

  IntegrityTest({
    required this.questionText,
    required this.questionLabel,
    required this.questionType,
    required this.answerType,
    required this.leftOptionLabel,
    required this.rightOptionLabel,
    required this.isActive,
    required this.answerOptions,
    required this.id,
  });

  factory IntegrityTest.fromMap(Map<String, dynamic> map) {
    return IntegrityTest(
      id: map['id'],
      questionText: map['question_text'] ?? '',
      questionLabel: map['question_label'] ?? '',
      questionType: QuestionType.values.firstWhere(
        (e) => e.name == map['question_type'],
        orElse: () => QuestionType.INTEGRITY,
      ),
      answerType: AnswerType.values.firstWhere(
        (e) => e.name == map['answer_type'],
        orElse: () => AnswerType.SUBJECTIVE,
      ),
      leftOptionLabel: map['left_option_label'] ?? 'Agree',
      rightOptionLabel: map['right_option_label'] ?? 'Disagree',
      isActive: map['is_active'] ?? false,
      answerOptions: map['answer_options'] != null
          ? map['answer_options']
              .map<AnswerOption>(
                  (e) => AnswerOption.fromMap(e))
              .toList()
          : [],
    );
  }
}

class AnswerOption {
  final String? label;
  final String option;
  final double score;
  final bool isActive;
  // final int questionId;
  final int id;

  AnswerOption({
    required this.option,
    required this.score,
    required this.isActive,
    // required this.questionId,
    required this.id,
    required this.label,
  });

  factory AnswerOption.fromMap(Map<String, dynamic> map) {
    return AnswerOption(
      option: map['option'] ?? '',
      score: map['score'] ?? 0,
      isActive: map['is_active'] ?? false,
      id: map['id']?.toInt() ?? 0,
      label: map['label'],
    );
  }
}

// class IntegrityTestRequest {
//   final String registrationStep;
//   final String questionType;

//   IntegrityTestRequest({
//     required this.registrationStep,
//     required this.questionType,
//   });

//   Map<String, dynamic> toJson() => {
//         'registration_step': registrationStep,
//         'question_type': questionType,
//       };
// }
