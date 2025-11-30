import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/story_screen.dart';
import '../../presentation/screens/character_screen.dart';
import '../../presentation/screens/inventory_screen.dart';
import '../../presentation/screens/quest_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/saves/saves_screen.dart';
import '../../presentation/widgets/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // Home/Landing page
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // Auth routes
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      ),
      
      // Saves management
      GoRoute(
        path: '/saves',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SavesScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      
      // Main game shell
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/story',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const StoryScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/character',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CharacterScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const InventoryScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/quests',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const QuestScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          ),
        ],
      ),
    ],
  );
});
