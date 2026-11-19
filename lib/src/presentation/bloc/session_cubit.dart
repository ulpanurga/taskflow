import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/core/error/failures.dart';

/// Текущий пользователь. От его имени пишется история и комментарии.
/// Состояние — id пользователя или null.
class SessionCubit extends Cubit<int?> {
  SessionCubit() : super(null);

  static const noUserFailure = ValidationFailure(
      'Сначала выберите текущего пользователя на вкладке «Пользователи»');

  void setUser(int? id) => emit(id);
}
