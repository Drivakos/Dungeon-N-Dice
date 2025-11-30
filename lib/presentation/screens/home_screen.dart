import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/game_constants.dart';
import '../../data/models/character_model.dart';
import '../../data/services/auth_service.dart';
import '../providers/game_providers.dart';
import '../providers/auth_providers.dart';

/// Home screen with main menu
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              AppColors.bgMedium,
              AppColors.bgDarkest,
            ],
          ),
        ),
        child: SafeArea(
          child: authState.when(
            data: (state) => _buildContent(context, ref, state),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.dragonGold),
            ),
            error: (e, _) => _buildContent(context, ref, AuthState.unauthenticated),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AuthState authState) {
    final isAuthenticated = authState == AuthState.authenticated;
    
    return Column(
      children: [
        const Spacer(flex: 2),
        
        // Title
        _buildTitle(context),
        
        const SizedBox(height: 16),
        
        // Subtitle
        Text(
          'An AI-Driven Adventure',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.parchmentDark,
            letterSpacing: 2,
          ),
        ).animate()
          .fadeIn(delay: 400.ms, duration: 600.ms),
        
        const Spacer(flex: 2),
        
        // Menu buttons based on auth state
        if (isAuthenticated)
          _buildAuthenticatedMenu(context, ref)
        else
          _buildUnauthenticatedMenu(context, ref),
        
        const Spacer(),
        
        // Footer
        _buildFooter(context),
        
        const SizedBox(height: 24),
      ],
    );
  }
  
  Widget _buildTitle(BuildContext context) {
    return Column(
      children: [
        // Dragon icon
        Icon(
          Icons.auto_awesome,
          size: 64,
          color: AppColors.dragonGold,
        ).animate()
          .fadeIn(duration: 600.ms)
          .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 600.ms),
        
        const SizedBox(height: 24),
        
        // Title text
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              AppColors.dragonGold,
              AppColors.dragonGold.withValues(alpha: 0.8),
              AppColors.dragonGold,
            ],
          ).createShader(bounds),
          child: Text(
            'AI Dungeon',
            style: GoogleFonts.cinzel(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: AppColors.dragonGold.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        ).animate()
          .fadeIn(delay: 200.ms, duration: 600.ms)
          .slideY(begin: 0.3, end: 0, duration: 600.ms),
      ],
    );
  }

  /// Menu for authenticated users - show their saves
  Widget _buildAuthenticatedMenu(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final savesAsync = ref.watch(userSavesProvider);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          // User status
          if (currentUser != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_done, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      currentUser.displayName.isNotEmpty 
                          ? currentUser.displayName 
                          : 'Adventurer',
                      style: const TextStyle(color: AppColors.success, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showLogoutDialog(context, ref),
                    child: const Icon(Icons.logout, color: AppColors.success, size: 16),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),
          
          // New Adventure button
          _MenuButton(
            label: 'NEW ADVENTURE',
            icon: Icons.add_circle_outline,
            onTap: () => _showNewGameDialog(context, ref),
          ).animate()
            .fadeIn(delay: 600.ms, duration: 400.ms)
            .slideX(begin: -0.2, end: 0, duration: 400.ms),
          
          const SizedBox(height: 16),
          
          // Continue / My Adventures based on saves
          savesAsync.when(
            data: (saves) {
              if (saves.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Column(
                children: [
                  // Continue most recent
                  _MenuButton(
                    label: 'CONTINUE',
                    icon: Icons.play_arrow,
                    isPrimary: true,
                    onTap: () => _loadSaveAndPlay(context, ref, saves.first.id),
                  ).animate()
                    .fadeIn(delay: 700.ms, duration: 400.ms)
                    .slideX(begin: 0.2, end: 0, duration: 400.ms),
                  
                  const SizedBox(height: 16),
                  
                  // My Adventures (all saves)
                  _MenuButton(
                    label: 'MY ADVENTURES',
                    icon: Icons.folder_open,
                    onTap: () => context.push('/saves'),
                  ).animate()
                    .fadeIn(delay: 800.ms, duration: 400.ms)
                    .slideX(begin: -0.2, end: 0, duration: 400.ms),
                ],
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.all(20),
              child: const CircularProgressIndicator(
                color: AppColors.dragonGold,
                strokeWidth: 2,
              ),
            ).animate().fadeIn(delay: 700.ms),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Could not load saves',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Menu for unauthenticated users - must login first
  Widget _buildUnauthenticatedMenu(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          // Info text
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgMedium.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.dragonGold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  color: AppColors.dragonGold.withValues(alpha: 0.7),
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your adventures are saved to the cloud',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.parchment,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to start playing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.parchmentDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ).animate()
            .fadeIn(delay: 500.ms, duration: 400.ms),
          
          // Continue as Guest (auto-creates account)
          _MenuButton(
            label: 'PLAY AS GUEST',
            icon: Icons.play_arrow,
            isPrimary: true,
            onTap: () => _handleGuestLogin(context, ref),
          ).animate()
            .fadeIn(delay: 600.ms, duration: 400.ms)
            .slideX(begin: -0.2, end: 0, duration: 400.ms),
          
          const SizedBox(height: 16),
          
          // Sign In
          _MenuButton(
            label: 'SIGN IN',
            icon: Icons.login,
            onTap: () => context.push('/login'),
          ).animate()
            .fadeIn(delay: 700.ms, duration: 400.ms)
            .slideX(begin: 0.2, end: 0, duration: 400.ms),
          
          const SizedBox(height: 16),
          
          // Create Account
          _MenuButton(
            label: 'CREATE ACCOUNT',
            icon: Icons.person_add,
            onTap: () => context.push('/register'),
          ).animate()
            .fadeIn(delay: 800.ms, duration: 400.ms)
            .slideX(begin: -0.2, end: 0, duration: 400.ms),
        ],
      ),
    );
  }
  
  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        Text(
          'Powered by AI Storytelling',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.parchmentDark.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 12,
              color: AppColors.dragonGold.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Text(
              'D&D 5e Mechanics',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.parchmentDark.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.auto_awesome,
              size: 12,
              color: AppColors.dragonGold.withValues(alpha: 0.5),
            ),
          ],
        ),
      ],
    ).animate()
      .fadeIn(delay: 1000.ms, duration: 600.ms);
  }

  Future<void> _handleGuestLogin(BuildContext context, WidgetRef ref) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.dragonGold),
      ),
    );
    
    final result = await ref.read(authServiceProvider).continueAsGuest();
    
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
    }
    
    if (result.success) {
      ref.invalidate(authStateProvider);
      ref.invalidate(userSavesProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome, Adventurer! Your progress will be saved.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to continue as guest'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadSaveAndPlay(BuildContext context, WidgetRef ref, String saveId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.dragonGold),
      ),
    );
    
    try {
      // Load save from cloud
      final cloudService = ref.read(cloudSaveServiceProvider);
      final saveData = await cloudService.loadSave(saveId);
      
      if (saveData != null) {
        // Update game state with loaded save
        ref.read(gameStateProvider.notifier).updateState(saveData);
        ref.read(selectedSaveIdProvider.notifier).state = saveId;
        
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading
          context.go('/story');
        }
      } else {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load save'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
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
            Icon(Icons.logout, color: AppColors.dragonGold),
            SizedBox(width: 8),
            Text('Sign Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out? Your saves are stored in the cloud and will be available when you sign back in.',
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
              await ref.read(authServiceProvider).signOut();
              ref.invalidate(authStateProvider);
              ref.invalidate(userSavesProvider);
              
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showNewGameDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    CharacterClass selectedClass = CharacterClass.fighter;
    CharacterRace selectedRace = CharacterRace.human;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.bgDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.dragonGold.withValues(alpha: 0.5)),
          ),
          title: Row(
            children: [
              const Icon(Icons.person_add, color: AppColors.dragonGold),
              const SizedBox(width: 8),
              Text(
                'Create Character',
                style: GoogleFonts.cinzel(
                  color: AppColors.dragonGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Character Name
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: AppColors.parchment),
                  decoration: InputDecoration(
                    labelText: 'Character Name',
                    labelStyle: TextStyle(color: AppColors.parchmentDark),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.dragonGold.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.dragonGold),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppColors.bgMedium,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Race Selection
                Text(
                  'Race',
                  style: TextStyle(color: AppColors.parchmentDark, fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<CharacterRace>(
                  value: selectedRace,
                  dropdownColor: AppColors.bgMedium,
                  style: const TextStyle(color: AppColors.parchment),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.dragonGold.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.dragonGold),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppColors.bgMedium,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: CharacterRace.values.map((race) {
                    return DropdownMenuItem(
                      value: race,
                      child: Text(race.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedRace = value);
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Class Selection
                Text(
                  'Class',
                  style: TextStyle(color: AppColors.parchmentDark, fontSize: 12),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<CharacterClass>(
                  value: selectedClass,
                  dropdownColor: AppColors.bgMedium,
                  style: const TextStyle(color: AppColors.parchment),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.dragonGold.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.dragonGold),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppColors.bgMedium,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: CharacterClass.values.map((charClass) {
                    return DropdownMenuItem(
                      value: charClass,
                      child: Text(charClass.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedClass = value);
                    }
                  },
                ),
              ],
            ),
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
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a character name'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                
                Navigator.of(dialogContext).pop();
                
                await _createNewAdventure(
                  context,
                  ref,
                  name: name,
                  race: selectedRace,
                  characterClass: selectedClass,
                );
              },
              child: const Text('Begin Adventure'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewAdventure(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    required CharacterRace race,
    required CharacterClass characterClass,
  }) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.dragonGold),
      ),
    );
    
    try {
      // Create character with factory
      final factory = ref.read(characterFactoryProvider);
      final character = factory.createCharacter(
        name: name,
        race: race,
        characterClass: characterClass,
        abilityScores: _rollAbilityScores(),
      );
      
      // Create game state locally first
      final repo = ref.read(gameRepositoryProvider);
      final gameState = await repo.createNewGame(
        saveName: '$name\'s Adventure',
        character: character,
      );
      
      // Save to cloud
      final cloudService = ref.read(cloudSaveServiceProvider);
      final saveId = await cloudService.createSave(
        saveName: '$name\'s Adventure',
        gameState: gameState,
      );
      
      if (saveId != null) {
        // Update local state with the cloud save ID
        final updatedState = gameState.copyWith(id: saveId);
        ref.read(gameStateProvider.notifier).updateState(updatedState);
        ref.read(selectedSaveIdProvider.notifier).state = saveId;
        
        // Refresh saves list
        ref.invalidate(userSavesProvider);
        
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading
          context.go('/story');
        }
      } else {
        throw Exception('Failed to create cloud save');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating adventure: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  AbilityScores _rollAbilityScores() {
    // Standard array for simplicity
    return const AbilityScores(
      strength: 15,
      dexterity: 14,
      constitution: 13,
      intelligence: 12,
      wisdom: 10,
      charisma: 8,
    );
  }
}

/// Custom menu button
class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(
                    colors: [
                      AppColors.dragonGold,
                      AppColors.dragonGold.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            color: isPrimary ? null : AppColors.bgMedium.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? AppColors.dragonGold
                  : AppColors.dragonGold.withValues(alpha: 0.3),
              width: isPrimary ? 2 : 1,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.dragonGold.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? AppColors.bgDarkest : AppColors.dragonGold,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.cinzel(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? AppColors.bgDarkest : AppColors.dragonGold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
