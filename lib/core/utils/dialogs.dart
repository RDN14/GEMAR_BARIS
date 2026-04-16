import 'package:flutter/material.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String okText = 'OK',
  String cancelText = 'Batal',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(okText),
        ),
      ],
    ),
  );
  return result == true;
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}