enum FailureType {
  location("LOCATION"),
  phoneNumber("PHONE_NUMBER");

  final String key;

  const FailureType(this.key);

  static FailureType? fromKey(String? key) {
    if (key == null) return null;

    // Using .where() + .firstOrNull is the cleanest zero-dependency
    // way to handle missing keys without throwing an error.
    return FailureType.values.where((type) => type.key == key).firstOrNull;
  }
}
