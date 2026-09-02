extension StringCDNExtension on String {
  String get cdn {
    if (startsWith("https")) {
      return this;
    }
    return "https://assets-expert.snabbit.com/$this"; //  control this from BE
  }
}