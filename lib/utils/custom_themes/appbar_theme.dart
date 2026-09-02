import 'package:flutter/material.dart';

class CartAppBarTheme {
  CartAppBarTheme._();

  static const lightAppBarTheme = AppBarTheme(
    elevation: 0,
    centerTitle: false,
    surfaceTintColor: Colors.white,
    // color: Colors.white,
    backgroundColor: Colors.white,
    foregroundColor: Colors.white,
    titleSpacing: 0,
    shadowColor: Colors.black12,
    // iconTheme: IconThemeData(color: Colors.black, size: 24),
    // actionsIconTheme: IconThemeData(color: Colors.black, size: 24),
    // titleTextStyle: TextStyle(
    //     fontSize: 18.0, fontWeight: FontWeight.w600, color: Colors.black),
  ); // AppBarTheme

  static const darkAppBarTheme = AppBarTheme(
    elevation: 0,
    centerTitle: false,
    scrolledUnderElevation: 0,
    // backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    iconTheme: IconThemeData(color: Colors.black, size: 24),
    actionsIconTheme: IconThemeData(color: Colors.white, size: 24),
    titleTextStyle: TextStyle(
        fontSize: 18.0, fontWeight: FontWeight.w600, color: Colors.white),
  );
}
