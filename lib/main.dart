import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/config/remote_config_service.dart';
import 'core/constants/app_theme.dart';
import 'core/constants/app_version.dart';
import 'core/database/institution_sync_service.dart';
import 'core/database/profile_repository.dart';
import 'core/database/schedule_repository.dart';
import 'core/database/user_sync_service.dart';
import 'core/notifications/notification_service.dart';
import 'firebase_options.dart';
import 'providers/profile_provider.dart';
import 'providers/schedule_provider.dart';
import 'views/common/force_update_guard.dart';
import 'views/onboarding/splash_screen.dart';

@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Hive Storage Engine FIRST so all boxes can open safely
  await Hive.initFlutter();

  // 2. Initialize App Version from pubspec / platform package info
  await AppVersion.initialize();

  // 3. Load Environment Variables (.env)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Could not load .env: $e');
  }

  // 4. Initialize Firebase, Cloud Directory & Remote Config Flags
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    InstitutionSyncService().startListening();
    RemoteConfigService.instance.startListening();
  } catch (e) {
    debugPrint('Firebase startup error: $e');
  }

  // 5. Initialize Local Databases (Schedules + Profiles)
  final repository = ScheduleRepository();
  await repository.init();

  final profileRepository = ProfileRepository();
  await profileRepository.init();

  // 6. Background User Sync
  try {
    UserSyncService.instance.syncCurrentUser();
  } catch (e) {
    debugPrint('UserSyncService error: $e');
  }

  // 7. Initialize Notification and Alarm Service safely
  final notificationService = NotificationService();
  try {
    await notificationService.initialize();
    await notificationService.requestPermissions();

    final allSavedSchedules = repository.getAllSchedules();
    if (allSavedSchedules.isNotEmpty) {
      await notificationService.rescheduleAll(allSavedSchedules);
    }
  } catch (e) {
    debugPrint('Notification service startup error: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(profileRepository),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const RemindaApp(),
    ),
  );
}

class RemindaApp extends StatelessWidget {
  const RemindaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminda',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) => ForceUpdateGuard(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}
