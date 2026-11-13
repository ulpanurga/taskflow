import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/app_database.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/projects_screen.dart';
import 'presentation/screens/tasks_screen.dart';
import 'presentation/screens/users_screen.dart';
import 'repositories/attachment_repository.dart';
import 'repositories/comment_repository.dart';
import 'repositories/data_seeder.dart';
import 'repositories/index_benchmark.dart';
import 'repositories/project_repository.dart';
import 'repositories/stats_repository.dart';
import 'repositories/task_repository.dart';
import 'repositories/user_repository.dart';
import 'state/session_controller.dart';
import 'state/tasks_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TaskFlowApp(db: AppDatabase(openConnection())));
}

class TaskFlowApp extends StatelessWidget {
  final AppDatabase db;
  const TaskFlowApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final taskRepo = TaskRepository(db);
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<UserRepository>.value(value: UserRepository(db)),
        Provider<ProjectRepository>.value(value: ProjectRepository(db)),
        Provider<TaskRepository>.value(value: taskRepo),
        Provider<CommentRepository>.value(value: CommentRepository(db)),
        Provider<AttachmentRepository>.value(value: AttachmentRepository(db)),
        Provider<StatsRepository>.value(value: StatsRepository(db)),
        Provider<DataSeeder>.value(value: DataSeeder(db)),
        Provider<IndexBenchmark>.value(value: IndexBenchmark(db, taskRepo)),
        ChangeNotifierProvider<SessionController>(
            create: (_) => SessionController()),
        // Контроллер списка «Все задачи»
        ChangeNotifierProvider<TasksController>(
            create: (c) => TasksController(c.read<TaskRepository>())),
      ],
      child: MaterialApp(
        title: 'TaskFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    ProjectsScreen(),
    TasksScreen(),
    UsersScreen(),
    DashboardScreen(),
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
