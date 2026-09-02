import 'package:snabbit_runner/services/iot/cleanup/cleanup_job.dart';
import 'package:snabbit_runner/services/iot/sender/sender.dart';

/// Handles flush operations - send all pending data and cleanup
/// Used during kill switch to ensure data is sent before shutdown
class FlushHandler {
  final Sender _sender;
  final CleanupJob _cleanupJob;

  FlushHandler({
    Sender? sender,
    CleanupJob? cleanupJob,
  })  : _sender = sender ?? Sender(),
        _cleanupJob = cleanupJob ?? CleanupJob();

  /// Flush all pending data for a user
  /// 1. Send all unsent data to backend
  /// 2. Run cleanup to remove old sent records
  /// Returns true if flush completed successfully
  Future<bool> flush(String userId, String iotEndpoint) async {
    try {
      // Step 1: Send all unsent data
      final sentCount = await _sender.sendAllData(userId, iotEndpoint);

      // Step 2: Cleanup old sent records
      final deletedCount = await _cleanupJob.cleanupAllData(userId);

      // Flush successful if we completed both steps
      // (even if sentCount and deletedCount are 0)
      return true;
    } catch (e) {
      // Flush failed
      return false;
    }
  }

  /// Flush and delete all data for a user (for logout/user switch)
  /// More aggressive than regular flush - deletes ALL data
  /// Returns true if completed successfully
  Future<bool> flushAndDeleteAll(String userId, String iotEndpoint) async {
    try {
      // Step 1: Try to send all unsent data
      await _sender.sendAllData(userId, iotEndpoint);

      // Step 2: Delete ALL user data (sent and unsent)
      await _cleanupJob.deleteAllUserData(userId);

      return true;
    } catch (e) {
      // Even if send fails, still try to delete all data
      try {
        await _cleanupJob.deleteAllUserData(userId);
      } catch (deleteError) {
        // Ignore delete error
      }
      return false;
    }
  }
}
