import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/services/storage_service.dart';
import 'data/services/journal_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  await StorageService.initialize();
  await JournalService.initialize();
  
  runApp(
    const ProviderScope(
      child: DnDAIGame(),
    ),
  );
}

class DnDAIGame extends ConsumerWidget {
  const DnDAIGame({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    
    return MaterialApp.router(
      title: 'D&D AI Adventure',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}


