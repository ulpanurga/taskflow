import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/presentation/bloc/data_state.dart';

/// Базовый Cubit для экранов, которые следят за данными (watch из базы).
/// Подписывается на поток из UseCase и сам выбирает
/// Loading / Success / Empty / Error.
abstract class WatchCubit<T> extends Cubit<DataState<T>> {
  WatchCubit() : super(const DataInitial());

  StreamSubscription<Either<Failure, T>>? _subscription;

  /// Поток данных из UseCase.
  Stream<Either<Failure, T>> watchSource();

  /// Когда данные считаются пустыми.
  bool isEmptyData(T data) => data is Iterable && data.isEmpty;

  /// Запускает загрузку.
  /// [force] — перезапустить, даже если уже грузим.
  /// [silent] — не показывать Loading (старые данные остаются на экране).
  void load({bool force = false, bool silent = false}) {
    // Защита от повторных запросов: если уже грузим, второй раз не начинаем.
    if (!force && state is DataLoading && _subscription != null) return;

    _subscription?.cancel();
    if (!silent) _safeEmit(DataLoading<T>());

    _subscription = watchSource().listen((result) {
      result.fold(
        (failure) => _safeEmit(DataError<T>(failure)),
        (data) => _safeEmit(
            isEmptyData(data) ? DataEmpty<T>() : DataSuccess<T>(data)),
      );
    });
  }

  /// Кнопка «Повторить» на экране ошибки.
  void retry() => load(force: true);

  void _safeEmit(DataState<T> newState) {
    if (!isClosed) emit(newState);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
