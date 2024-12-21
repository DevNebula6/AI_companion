import 'package:flutter/material.dart';

typedef DialogOptionBuilder<T> = Map<String, T?> Function();

Future<T?> showGenericDialog<T>({
  required BuildContext context,
  required String title,
  required String content,
  required DialogOptionBuilder<T> options,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      final optionsMap = options();
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(content),
            ...optionsMap.entries.map((entry) {
              return ListTile(
                title: Text(entry.key),
                onTap: () {
                  Navigator.of(context).pop(entry.value);
                },
              );
            })
          ],
        ),
      );
    },
  );
}
