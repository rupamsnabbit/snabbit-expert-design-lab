abstract class BasicLogsInterface {
  Future<void> logDebug(
    String message,
    Map<String, dynamic> data,
  );

  Future<void> logInfo(
    String message,
    Map<String, dynamic> data,
  );

  Future<void> logWarning(
    String message,
    Map<String, dynamic> data,
  );

  Future<void> logError(
    String message,
    Map<String, dynamic> data,
  );

  Future<void> logCriticalError(
    String message,
    Map<String, dynamic> data,
  );

  Future<dynamic> reportError(
    String message,
    Map<String, dynamic>? data,
    String? stackTrace,
  );
}
