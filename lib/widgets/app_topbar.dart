import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = false,
    this.logoWidth = 92,
    this.logoSize = 44,
  });

  final String title;
  final List<Widget>? actions;
  final bool centerTitle;

  // supaya gampang perbesar logo dari tiap page kalau mau
  final double logoWidth;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      centerTitle: centerTitle,
      leadingWidth: logoWidth,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Image.asset(
          'assets/images/logo_poltekkes.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}