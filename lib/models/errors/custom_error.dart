class CustomError {
  String? errorMessageCode;
  String? title;
  String? message;
  dynamic data;

  CustomError({
    this.errorMessageCode,
    this.title,
    this.message,
    this.data,
  });

  factory CustomError.fromMap(Map<String, dynamic> map) {
    return CustomError(
      errorMessageCode: map['code'],
      title: map['title'],
      message: map['message'],
      data: map['data'],
    );
  }
}