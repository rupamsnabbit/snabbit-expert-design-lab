import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/colors.dart';

// Floating Action Button
class Fab extends StatelessWidget {
  final bool continuee;
  final bool loading;
  final void Function()? onPressed;
  final String name;
  const Fab({
    super.key,
    this.name = "Continue",
    required this.continuee,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FloatingActionButton.extended(
        backgroundColor: continuee ? AppColors.brand : AppColors.n50,
        onPressed: continuee ? onPressed : null,
        elevation: 0,
        label: loading
            ? const CupertinoActivityIndicator(
                color: Colors.white,
              )
            : Text(
                name,
                style:
                    TextStyle(color: continuee ? Colors.white : Colors.black54),
              ),
      ),
    );
  }
}
