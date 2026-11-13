import 'package:flutter/foundation.dart';

import '../models/exceptions.dart';

/// Хранит текущего пользователя — от его имени выполняются действия
/// (смена статуса, комментарии и т.д.).
class SessionController extends ChangeNotifier {
  int? _userId;
  int? get userId => _userId;

  void setUser(int? id) {
    _userId = id;
    notifyListeners();
  }

  int requireUser() {
    final id = _userId;
    if (id == null) {
      throw const ValidationException(
          'Сначала выберите текущего пользователя на вкладке «Пользователи»');
    }
    return id;
  }
}
