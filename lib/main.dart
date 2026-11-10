import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend/config/firebase_options.dart';
import 'backend/repositories/auth_repository.dart';
import 'backend/repositories/menu_repository.dart';
import 'backend/repositories/order_repository.dart';
import 'backend/services/notification_service.dart';
import 'frontend/navigation/router.dart';
import 'frontend/theme/theme.dart';
import 'frontend/widgets/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Automatic background synchronization: upload 37 menu products and sync orders to Cloud Firestore
    unawaited(MenuRepository().syncMenuToFirestore());
    unawaited(OrderRepository().syncPendingOrdersToFirestore());
    unawaited(AuthRepository().ensureAdminAccountExists());
    OrderRepository.startPeriodicAutoSync();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('NotificationService initialization error: $e');
  }

  runApp(const ProviderScope(child: CoughfeeApp()));
}

class CoughfeeApp extends ConsumerWidget {
  const CoughfeeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'CafeGO',
      debugShowCheckedModeBanner: false,
      theme: appLightTheme,
      darkTheme: appDarkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
