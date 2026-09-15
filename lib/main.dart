import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/services/cloud_sync_service.dart';
import 'core/services/local_database_service.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabaseService.instance.init();
  try {
    final syncService = CloudSyncService();
    await syncService.initializeClient();
  } catch (e) {
    debugPrint('Supabase initial setup error: $e');
  }
  runApp(const ProviderScope(child: PossessionTrackerApp()));
}

class PossessionTrackerApp extends StatelessWidget {
  const PossessionTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
