import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../providers/game_providers.dart';

/// Main scaffold with bottom navigation
class MainScaffold extends ConsumerWidget {
  final Widget child;
  
  const MainScaffold({super.key, required this.child});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bgDarkest,
              AppColors.bgDark,
            ],
          ),
        ),
        child: child,
      ),
      bottomNavigationBar: _BottomNavBar(ref: ref),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final WidgetRef ref;
  
  const _BottomNavBar({required this.ref});
  
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        border: Border(
          top: BorderSide(
            color: AppColors.dragonGold.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home,
                label: 'Menu',
                isSelected: false,
                isExit: true,
                onTap: () {
                  // Unfocus any text fields to prevent Flutter Web errors
                  FocusScope.of(context).unfocus();
                  _showExitDialog(context);
                },
              ),
              _NavItem(
                icon: Icons.auto_stories,
                label: 'Story',
                isSelected: location == '/story',
                onTap: () {
                  FocusScope.of(context).unfocus();
                  context.go('/story');
                },
              ),
              _NavItem(
                icon: Icons.person,
                label: 'Hero',
                isSelected: location == '/character',
                onTap: () {
                  FocusScope.of(context).unfocus();
                  context.go('/character');
                },
              ),
              _NavItem(
                icon: Icons.inventory_2,
                label: 'Items',
                isSelected: location == '/inventory',
                onTap: () {
                  FocusScope.of(context).unfocus();
                  context.go('/inventory');
                },
              ),
              _NavItem(
                icon: Icons.assignment,
                label: 'Quests',
                isSelected: location == '/quests',
                onTap: () {
                  FocusScope.of(context).unfocus();
                  context.go('/quests');
                },
              ),
              _NavItem(
                icon: Icons.settings,
                label: 'Settings',
                isSelected: location == '/settings',
                onTap: () {
                  FocusScope.of(context).unfocus();
                  context.go('/settings');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.dragonGold.withValues(alpha: 0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: AppColors.dragonGold),
            SizedBox(width: 8),
            Text('Exit to Menu'),
          ],
        ),
        content: const Text(
          'Your progress will be saved automatically. Return to the main menu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dragonGold,
              foregroundColor: AppColors.bgDarkest,
            ),
            onPressed: () async {
              // Save game before exiting
              await ref.read(gameStateProvider.notifier).saveGame();
              
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (context.mounted) {
                context.go('/');
              }
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExit;
  final VoidCallback onTap;
  
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isExit = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final Color itemColor = isExit 
        ? AppColors.parchment.withValues(alpha: 0.7)
        : (isSelected ? AppColors.dragonGold : AppColors.parchmentDark);
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.dragonGold.withValues(alpha: 0.15)
              : (isExit ? AppColors.bgMedium.withValues(alpha: 0.3) : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.dragonGold.withValues(alpha: 0.3))
              : (isExit ? Border.all(color: AppColors.parchmentDark.withValues(alpha: 0.2)) : null),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: itemColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: itemColor,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


