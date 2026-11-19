import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/constants/app_constants.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/domain/usecases/stats_import_usecases.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';

/// Состояния экрана импорта.
sealed class ImportState extends Equatable {
  const ImportState();

  @override
  List<Object?> get props => [];
}

class ImportInitial extends ImportState {
  const ImportInitial();
}

class ImportLoading extends ImportState {
  const ImportLoading();
}

class ImportLoaded extends ImportState {
  final List<RemoteTodo> todos;
  const ImportLoaded(this.todos);

  @override
  List<Object?> get props => [todos];
}

/// Сервер ответил пустым списком.
class ImportEmpty extends ImportState {
  const ImportEmpty();
}

class ImportSaving extends ImportState {
  final List<RemoteTodo> todos;
  const ImportSaving(this.todos);

  @override
  List<Object?> get props => [todos];
}

class ImportSaved extends ImportState {
  final int count;
  const ImportSaved(this.count);

  @override
  List<Object?> get props => [count];
}

/// [duringSave] = true: упало сохранение, загруженный список не потерян,
/// повтор отправит в базу уже загруженные задачи без нового запроса к серверу.
class ImportError extends ImportState {
  final Failure failure;
  final bool duringSave;
  const ImportError(this.failure, {this.duringSave = false});

  @override
  List<Object?> get props => [failure, duringSave];
}

class ImportCubit extends Cubit<ImportState> {
  final int projectId;
  final FetchRemoteTodos _fetch;
  final ImportTodos _import;
  final SessionCubit _session;

  List<RemoteTodo> _todos = const [];

  ImportCubit(this.projectId, this._fetch, this._import, this._session)
      : super(const ImportInitial());

  /// Загружает список с сервера.
  Future<void> fetch() async {
    // Не отправляем второй запрос, пока идёт первый.
    if (state is ImportLoading || state is ImportSaving) return;
    emit(const ImportLoading());

    final result = await _fetch(limit: kImportLimit);
    if (isClosed) return;
    result.fold(
      (failure) => emit(ImportError(failure)),
      (list) {
        _todos = list;
        emit(list.isEmpty ? const ImportEmpty() : ImportLoaded(list));
      },
    );
  }

  /// Сохраняет загруженные задачи в локальную базу.
  Future<void> save() async {
    if (state is ImportSaving || _todos.isEmpty) return;

    final actor = _session.state;
    if (actor == null) {
      emit(const ImportError(SessionCubit.noUserFailure, duringSave: true));
      return;
    }
    emit(ImportSaving(_todos));

    final result = await _import(
        projectId: projectId, actorId: actor, todos: _todos);
    if (isClosed) return;
    result.fold(
      (failure) => emit(ImportError(failure, duringSave: true)),
      (count) => emit(ImportSaved(count)),
    );
  }

  /// Кнопка «Повторить»: повторяет то действие, которое не получилось.
  Future<void> retry() {
    final last = state;
    if (last is ImportError && last.duringSave) return save();
    return fetch();
  }
}
