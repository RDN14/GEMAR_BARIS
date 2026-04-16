import 'package:flutter/material.dart';

void showTopNotice(
  BuildContext context, {
  required String message,
  bool success = true,
}) {
  final messenger = ScaffoldMessenger.of(context);

  messenger.clearMaterialBanners();

  final backgroundColor = success ? Colors.green.shade600 : Colors.red.shade600;
  final icon = success ? Icons.check_circle : Icons.error_outline;

  messenger.showMaterialBanner(
    MaterialBanner(
      backgroundColor: backgroundColor,
      leading: Icon(icon, color: Colors.white),
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
          },
          child: const Text(
            'Tutup',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  Future.delayed(const Duration(seconds: 2), () {
    messenger.hideCurrentMaterialBanner();
  });
}