import 'package:flutter/material.dart';

class UnderlineTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color? textColor;
  final Color? underlineColor;
  final TextStyle? textStyle;

  const UnderlineTextButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.textColor,
    this.underlineColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor ?? const Color(0xff7711D2),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: underlineColor ?? const Color(0xff7711D2),
            ),
          ),
        ),
        child: Text(text, style: textStyle,),
      ),
    );
  }
}
