import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/enums.dart';

String fmtDate(DateTime? d) =>
    d == null ? '—' : DateFormat('dd.MM.yyyy').format(d);

String fmtDateTime(DateTime d) => DateFormat('dd.MM.yyyy HH:mm').format(d);

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Показывает ошибку из действия (если она есть).
/// Возвращает true, если действие прошло успешно.
/// Текст берётся из Failure — это безопасный текст для пользователя.
Future<bool> handle(BuildContext context, Future<Failure?> action) async {
  final failure = await action;
  if (failure != null) {
    if (context.mounted) showMessage(context, failure.message);
    return false;
  }
  return true;
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
