import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'config.dart';
import 'services/backend_service.dart';
import 'services/local_store.dart';
import 'services/omdb_service.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MovieTrackerApp());
}

class MovieTrackerApp extends StatelessWidget {
  const MovieTrackerApp({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AppState(
      LocalStore(),
      AppConfig.advancedMode ? BackendService() : OmdbService(),
    )..initialize(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'فیلم‌یار',
      locale: const Locale('fa'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B3FD0)),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const _Gate(),
    ),
  );
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return state.user == null && !state.guestMode
        ? const AuthScreen()
        : const AppShell();
  }
}
