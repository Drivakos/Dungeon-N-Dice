import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Main scaffold with bottom navigation
class MainScaffold extends StatelessWidget {
  final Widget child;
  
  const MainScaffold({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: const _BottomNavBar(),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();
  
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.auto_stories,
                label: 'Story',
                isSelected: location == '/story',
                onTap: () => context.go('/story'),
              ),
              _NavItem(
                icon: Icons.person,
                label: 'Character',
                isSelected: location == '/character',
                onTap: () => context.go('/character'),
              ),
              _NavItem(
                icon: Icons.inventory_2,
                label: 'Inventory',
                isSelected: location == '/inventory',
                onTap: () => context.go('/inventory'),
              ),
              _NavItem(
                icon: Icons.assignment,
                label: 'Quests',
                isSelected: location == '/quests',
                onTap: () => context.go('/quests'),
              ),
              _NavItem(
                icon: Icons.settings,
                label: 'Settings',
                isSelected: location == '/settings',
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.dragonGold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.dragonGold.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.dragonGold : AppColors.parchmentDark,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.dragonGold : AppColors.parchmentDark,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


