import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/colors.dart';

class ElevatedButtonWithLoader extends StatefulWidget {
  final String text;
  final Color bgColor;
  final Color? textColor;
  final Future<void> Function() onPressed;

  const ElevatedButtonWithLoader({
    super.key,
    required this.text,
    required this.bgColor,
    this.textColor,
    required this.onPressed,
  });

  @override
  State<ElevatedButtonWithLoader> createState() =>
      _ElevatedButtonWithLoaderState();
}

class _ElevatedButtonWithLoaderState extends State<ElevatedButtonWithLoader> {
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.bgColor,
        foregroundColor: widget.textColor ?? AppColors.n0,
      ),
      onPressed: loading ? null : () async {
        setState(() {
          loading = true;
        });
        await widget.onPressed();
        loading = false;
        if (mounted) {
          setState(() {
          });
        }
      },
      child: loading
          ? CupertinoActivityIndicator(
              color: widget.bgColor,
            )
          : Text(widget.text),
    );
  }
}
