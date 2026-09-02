import 'dart:async';
import 'dart:math';

class RetryHelper {
  /// Executes a function with exponential backoff retries.
  ///
  /// [operation] The async function to execute. It should throw an exception on failure.
  /// [maxRetries] The maximum number of retries before giving up. Default is 3.
  /// [initialDelay] The initial delay before the first retry. Default is 1 second.
  /// [delayFactor] The factor by which the delay increases with each retry. Default is 2.
  static Future<T> exponentialBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    int delayFactor = 2,
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    assert(maxRetries >= 0);
    assert(delayFactor >= 1);

    final random = Random();

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        final baseDelayMs =
            initialDelay.inMilliseconds * pow(delayFactor, attempt).toInt();
        final cappedDelayMs = min(baseDelayMs, maxDelay.inMilliseconds);
        final jitter = random.nextInt(500);

        await Future.delayed(
          Duration(milliseconds: cappedDelayMs + jitter),
        );
      }
    }

    // Last attempt
    return await operation();
  }
}
