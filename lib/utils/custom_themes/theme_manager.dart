import 'package:flutter/material.dart';

import '../themes.dart';

class ThemeManager with ChangeNotifier {
  ThemeData themeData = AppTheme.lightTheme;

  // toggleTheme(StudentAvatar studentAvatar) {
  //   themeData =
  //       studentAvatar == StudentAvatar.av2 || studentAvatar == StudentAvatar.av4
  //           ? AppTheme.darkTheme
  //           : AppTheme.lightTheme;
  //   notifyListeners();
  // }
}
