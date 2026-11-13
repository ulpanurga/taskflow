import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/enums.dart';
import '../models/exceptions.dart';

String fmtDate(DateTime? d) =>
    d == null ? '—' : DateFormat('dd.MM.yyyy').format(d);

String fmtDateTime(DateTime d) => DateFormat('dd.MM.yyyy HH:mm').format(d);

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Выполняет действие и показывает ошибку бизнес-правил в SnackBar.
/// Возвращает true, если всё прошло успешно.
Future<bool> guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } on ValidationException catch (e) {
    if (context.mounted) showMessage(context, e.message);
  } catch (e) {
    if (context.mounted) showMessage(context, 'Ошибка: $e');
  }
  return false;
}

Color statusColor(TaskStatus s) {
  switch (s) {
    case TaskStatus.todo:
      return Colors.blueGrey;
    case TaskStatus.inProgress:
      return Colors.blue;
    case TaskStatus.done:
      return Colors.green;
    case TaskStatus.cancelled:
      return Colors.red;
  }
}

Color priorityColor(TaskPriority p) {
  switch (p) {
    case TaskPriority.low:
      return Colors.grey;
    case TaskPriority.medium:
      return Colors.amber.shade700;
    case TaskPriority.high:
      return Colors.orange;
    case TaskPriority.critical:
      return Colors.red;
  }
}

Future<bool> confirm(BuildContext context, String text) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да')),
      ],
    ),
  );
  return res ?? false;
}

class StatusChip extends StatelessWidget {
  final TaskStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status.title, style: TextStyle(color: c, fontSize: 12)),
    );
  }
}
