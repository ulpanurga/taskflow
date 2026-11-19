import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/presentation/bloc/data_state.dart';
import 'package:taskflow/src/presentation/bloc/watch_cubit.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class EmptyView extends StatelessWidget {
  final String text;
  const EmptyView({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

/// Экран ошибки с кнопкой «Повторить».
class ErrorView extends StatelessWidget {
  final Failure failure;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.failure, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final noNetwork = failure is NetworkFailure;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(noNetwork ? Icons.wifi_off : Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(failure.message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Показывает нужный вид по состоянию DataState:
/// Loading, Error (с повтором), Empty или данные.
class DataStateView<C extends WatchCubit<T>, T> extends StatelessWidget {
  final String emptyText;
  final Widget Function(BuildContext context, T data) builder;

  const DataStateView({
    super.key,
    required this.emptyText,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<C, DataState<T>>(
      builder: (context, state) {
        if (state is DataSuccess<T>) return builder(context, state.data);
        if (state is DataError<T>) {
          return ErrorView(
            failure: state.failure,
            onRetry: () => context.read<C>().retry(),
          );
        }
        if (state is DataEmpty<T>) return EmptyView(text: emptyText);
        return const LoadingView();
      },
    );
  }
}
