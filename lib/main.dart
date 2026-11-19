import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskflow/core/di/injection.dart';
import 'package:taskflow/src/domain/entities/task_entities.dart';
import 'package:taskflow/src/presentation/bloc/dashboard_cubit.dart';
import 'package:taskflow/src/presentation/bloc/projects_cubit.dart';
import 'package:taskflow/src/presentation/bloc/session_cubit.dart';
import 'package:taskflow/src/presentation/bloc/tasks_cubit.dart';
import 'package:taskflow/src/presentation/bloc/users_cubit.dart';
import 'package:taskflow/src/presentation/pages/dashboard_page.dart';
import 'package:taskflow/src/presentation/pages/projects_page.dart';
import 'package:taskflow/src/presentation/pages/tasks_page.dart';
import 'package:taskflow/src/presentation/pages/users_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const TaskFlowApp());
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Один на всё приложение, закрывать его не нужно.
        BlocProvider<SessionCubit>.value(value: getIt<SessionCubit>()),
        BlocProvider<UsersCubit>(create: (_) => getIt<UsersCubit>()..load()),
        BlocProvider<ProjectsCubit>(
            create: (_) => getIt<ProjectsCubit>()..load()),
        BlocProvider<TasksCubit>(
            create: (_) =>
                getIt<TasksCubit>(param1: const TaskFilterEntity())..load()),
        BlocProvider<DashboardCubit>(
            create: (_) => getIt<DashboardCubit>()..load()),
      ],
      child: MaterialApp(
        title: 'TaskFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _pages = <Widget>[
    ProjectsPage(),
    TasksPage(),
    UsersPage(),
    DashboardPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder), label: 'Проекты'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Задачи'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Пользователи'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Статистика'),
        ],
      ),
    );
  }
}
