import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/colors.dart';

class CommonAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? title;
  final double elevation;
  final bool? centerTitle;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;

  const CommonAppBar({
    super.key,
    this.title,
    this.elevation = 0.0,
    this.centerTitle = false,
    this.actions,
    this.onBackPressed,
  });

  @override
  State<CommonAppBar> createState() => _CommonAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _CommonAppBarState extends State<CommonAppBar> {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: widget.elevation,
      title: widget.title,
      centerTitle: widget.centerTitle,
      leading: InkWell(
        onTap: () {
          if (widget.onBackPressed != null) {
            widget.onBackPressed!();
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        child: const Icon(
          Icons.arrow_back_ios_rounded,
          color: AppColors.n80,
        ),
      ),
      actions: widget.actions,
    );
  }
}
