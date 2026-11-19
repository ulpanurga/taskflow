import 'package:equatable/equatable.dart';
import 'package:taskflow/core/error/failures.dart';

/// Общие состояния экрана с данными:
/// Initial -> Loading -> Success / Empty / Error.
sealed class DataState<T> extends Equatable {
  const DataState();

  @override
  List<Object?> get props => [];
}

class DataInitial<T> extends DataState<T> {
  const DataInitial();
}

class DataLoading<T> extends DataState<T> {
  const DataLoading();
}

class DataSuccess<T> extends DataState<T> {
  final T data;
  const DataSuccess(this.data);

  @override
  List<Object?> get props => [data];
}

/// Данные загрузились, но их нет (пустой список).
class DataEmpty<T> extends DataState<T> {
  const DataEmpty();
}

class DataError<T> extends DataState<T> {
  final Failure failure;
  const DataError(this.failure);

  @override
  List<Object?> get props => [failure];
}
