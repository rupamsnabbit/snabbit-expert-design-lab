import 'package:snabbit_runner/providers/language_provider.dart';

class CF<T> {
  T? value;
  String? key;
  List<dynamic>? acceptedValues;

  CF({
    this.value,
    this.key,
    this.acceptedValues,
  });

  bool contains(val) {
    return acceptedValues?.contains(val) == true;
  }

  bool isValueAcceptable() {
    if (value == null ||
        acceptedValues == null ||
        acceptedValues?.isEmpty == true) {
      return true;
    }
    return contains(value);
  }
}

class NumberRangeCF extends CF<num> {
  NumberRangeCF({
    num? value,
    String? key,
    List<num>? acceptedValues,
  }) : super(value: value, key: key, acceptedValues: acceptedValues);

  @override
  bool isValueAcceptable() {
    if (value == null ||
        acceptedValues == null ||
        acceptedValues?.isEmpty == true) {
      return true;
    }
    return value != null &&
        value! >= acceptedValues?.first &&
        value! <= acceptedValues?.last;
  }
}

class BooleanCF extends CF<bool> {
  bool? acceptedValue;

  BooleanCF({
    bool? value,
    String? key,
    this.acceptedValue,
  }) : super(
          value: value,
          key: key,
        );

  @override
  bool isValueAcceptable() {
    if (acceptedValue == null || value == null) {
      return true;
    }
    return value == acceptedValue;
  }

  String? getCriticalError(LanguageProvider languageProvider) {
    return isValueAcceptable()
        ? null
        : languageProvider.getMessage(
            'pls_review_answer_carefully',
            "Please review this answer carefully",
          );
  }
}

class ListCF<T> extends CF<List<T>> {
  ListCF({
    List<T>? value,
    String? key,
    List<T>? acceptedValues,
  }) : super(
          value: value,
          key: key,
          acceptedValues: acceptedValues,
        );

  @override
  bool isValueAcceptable() {
    if (value == null ||
        value?.isEmpty == true ||
        acceptedValues == null ||
        acceptedValues?.isEmpty == true) {
      return true;
    }
    for (T item in (value ?? [])) {
      if (acceptedValues?.contains(item) == false) {
        return false;
      }
    }
    return true;
  }
}
