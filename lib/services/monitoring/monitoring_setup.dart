import 'package:snabbit_runner/providers/user_profile.dart';

abstract class MonitoringSetupInterface{
  Future<void> initializeService();
  Future<void> setUserData(UserProfile user);

}