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
    final hasSaves = ref.watch(gameRepositoryProvider).hasSaves();
    
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
          child: Column(
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
              
              // Menu buttons
              _buildMenuButtons(context, ref, hasSaves),
              
              const Spacer(),
              
              // Footer
              _buildFooter(context),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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
          .scale(duration: 800.ms, curve: Curves.elasticOut)
          .shimmer(delay: 1000.ms, duration: 1500.ms),
        
        const SizedBox(height: 24),
        
        // Title text
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppColors.dragonGold,
              Color(0xFFFFE4B5),
              AppColors.dragonGold,
            ],
          ).createShader(bounds),
          child: Text(
            'REALM OF',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 8,
            ),
          ),
        ).animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: -0.3, end: 0, duration: 600.ms),
        
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppColors.dragonGold,
              Color(0xFFFFE4B5),
              AppColors.dragonGold,
            ],
          ).createShader(bounds),
          child: Text(
            'LEGENDS',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.white,
              letterSpacing: 12,
              fontSize: 48,
            ),
          ),
        ).animate()
          .fadeIn(delay: 200.ms, duration: 600.ms)
          .slideY(begin: 0.3, end: 0, duration: 600.ms),
      ],
    );
  }
  
  Widget _buildMenuButtons(BuildContext context, WidgetRef ref, bool hasSaves) {
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAuthenticated = authState.valueOrNull == AuthState.authenticated;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          // Auth status indicator
          if (isAuthenticated && currentUser != null)
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
                  Text(
                    'Logged in as ${currentUser.displayName}',
                    style: TextStyle(color: AppColors.success, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await ref.read(authServiceProvider).signOut();
                      ref.invalidate(authStateProvider);
                    },
                    child: const Icon(Icons.logout, color: AppColors.success, size: 16),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms)
          else
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: TextButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login, color: AppColors.dragonGold, size: 18),
                label: Text(
                  'Sign in to sync saves',
                  style: TextStyle(color: AppColors.dragonGold, fontSize: 13),
                ),
              ),
            ).animate().fadeIn(delay: 500.ms),
          
          // New Game button
          _MenuButton(
            label: 'NEW ADVENTURE',
            icon: Icons.add_circle_outline,
            onTap: () => _showNewGameDialog(context, ref),
          ).animate()
            .fadeIn(delay: 600.ms, duration: 400.ms)
            .slideX(begin: -0.2, end: 0, duration: 400.ms),
          
          const SizedBox(height: 16),
          
          // Continue button (if saves exist)
          if (hasSaves) ...[
            _MenuButton(
              label: 'CONTINUE',
              icon: Icons.play_arrow,
              isPrimary: true,
              onTap: () async {
                await ref.read(gameStateProvider.notifier).loadGame(
                  ref.read(saveGamesProvider).first.id,
                );
                if (context.mounted) {
                  context.go('/story');
                }
              },
            ).animate()
              .fadeIn(delay: 700.ms, duration: 400.ms)
              .slideX(begin: 0.2, end: 0, duration: 400.ms),
            
            const SizedBox(height: 16),
            
            // Load Game button
            _MenuButton(
              label: 'LOAD GAME',
              icon: Icons.folder_open,
              onTap: () => _showLoadGameDialog(context, ref),
            ).animate()
              .fadeIn(delay: 800.ms, duration: 400.ms)
              .slideX(begin: -0.2, end: 0, duration: 400.ms),
          ],
          
          // Cloud Saves button (if authenticated)
          if (isAuthenticated) ...[
            const SizedBox(height: 16),
            _MenuButton(
              label: 'CLOUD SAVES',
              icon: Icons.cloud,
              onTap: () => context.push('/saves'),
            ).animate()
              .fadeIn(delay: 900.ms, duration: 400.ms)
              .slideX(begin: 0.2, end: 0, duration: 400.ms),
          ],
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
  
  void _showNewGameDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _NewGameDialog(ref: ref),
    );
  }
  
  void _showLoadGameDialog(BuildContext context, WidgetRef ref) {
    final saves = ref.read(saveGamesProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.dragonGold),
        ),
        title: Text(
          'Load Game',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: saves.length,
            itemBuilder: (context, index) {
              final save = saves[index];
              return ListTile(
                title: Text(
                  save.saveName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  '${save.characterName} - Level ${save.characterLevel}\n${save.formattedPlayTime}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () async {
                    await ref.read(gameRepositoryProvider).deleteGame(save.id);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                onTap: () async {
                  await ref.read(gameStateProvider.notifier).loadGame(save.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    context.go('/story');
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

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
            color: isPrimary 
                ? AppColors.dragonGold.withValues(alpha: 0.15)
                : AppColors.bgMedium.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary 
                  ? AppColors.dragonGold 
                  : AppColors.dragonGold.withValues(alpha: 0.3),
              width: isPrimary ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? AppColors.dragonGold : AppColors.parchment,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isPrimary ? AppColors.dragonGold : AppColors.parchment,
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

class _NewGameDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  
  const _NewGameDialog({required this.ref});
  
  @override
  ConsumerState<_NewGameDialog> createState() => _NewGameDialogState();
}

class _NewGameDialogState extends ConsumerState<_NewGameDialog> {
  final _nameController = TextEditingController();
  final _saveNameController = TextEditingController();
  int _currentStep = 0;
  
  // Character creation state
  String _characterName = '';
  CharacterRace? _selectedRace;
  CharacterClass? _selectedClass;
  AbilityScores? _abilityScores;
  
  @override
  void dispose() {
    _nameController.dispose();
    _saveNameController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.dragonGold),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create Your Hero',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: _buildCurrentStep(),
            ),
            
            const SizedBox(height: 16),
            
            // Navigation buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  TextButton(
                    onPressed: () => setState(() => _currentStep--),
                    child: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),
                  
                ElevatedButton(
                  onPressed: _canProceed() ? _onNext : null,
                  child: Text(_currentStep == 3 ? 'Create' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildNameStep();
      case 1:
        return _buildRaceStep();
      case 2:
        return _buildClassStep();
      case 3:
        return _buildAbilityStep();
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What is your name, adventurer?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Enter character name',
            prefixIcon: Icon(Icons.person),
          ),
          onChanged: (value) => setState(() => _characterName = value),
        ),
        const SizedBox(height: 24),
        Text(
          'Save name:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _saveNameController,
          decoration: const InputDecoration(
            hintText: 'Enter save name',
            prefixIcon: Icon(Icons.save),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRaceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your race:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: CharacterRace.values.length,
            itemBuilder: (context, index) {
              final race = CharacterRace.values[index];
              final isSelected = _selectedRace == race;
              
              return ListTile(
                title: Text(race.displayName),
                subtitle: Text(race.description),
                selected: isSelected,
                selectedTileColor: AppColors.dragonGold.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: isSelected 
                      ? const BorderSide(color: AppColors.dragonGold)
                      : BorderSide.none,
                ),
                onTap: () => setState(() => _selectedRace = race),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildClassStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your class:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: CharacterClass.values.length,
            itemBuilder: (context, index) {
              final charClass = CharacterClass.values[index];
              final isSelected = _selectedClass == charClass;
              
              return ListTile(
                title: Text(charClass.displayName),
                subtitle: Text(charClass.description),
                selected: isSelected,
                selectedTileColor: AppColors.dragonGold.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: isSelected 
                      ? const BorderSide(color: AppColors.dragonGold)
                      : BorderSide.none,
                ),
                onTap: () => setState(() => _selectedClass = charClass),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildAbilityStep() {
    // Generate ability scores if not done yet
    _abilityScores ??= _generateStandardArray();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Ability Scores:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '(Standard Array)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _AbilityScoreDisplay(scores: _abilityScores!),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _abilityScores = _rollAbilityScores();
              });
            },
            icon: const Icon(Icons.casino),
            label: const Text('Roll New Scores'),
          ),
        ),
      ],
    );
  }
  
  AbilityScores _generateStandardArray() {
    // Standard array: 15, 14, 13, 12, 10, 8
    return const AbilityScores(
      strength: 15,
      dexterity: 14,
      constitution: 13,
      intelligence: 12,
      wisdom: 10,
      charisma: 8,
    );
  }
  
  AbilityScores _rollAbilityScores() {
    final gameMaster = ref.read(gameMasterProvider);
    final rolls = gameMaster.diceRoller.rollAbilityScoreSet();
    final scores = rolls.map((r) => r.total).toList()..sort((a, b) => b.compareTo(a));
    
    return AbilityScores(
      strength: scores[0],
      dexterity: scores[1],
      constitution: scores[2],
      intelligence: scores[3],
      wisdom: scores[4],
      charisma: scores[5],
    );
  }
  
  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _characterName.isNotEmpty && _saveNameController.text.isNotEmpty;
      case 1:
        return _selectedRace != null;
      case 2:
        return _selectedClass != null;
      case 3:
        return _abilityScores != null;
      default:
        return false;
    }
  }
  
  void _onNext() async {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      // Create character
      final factory = ref.read(characterFactoryProvider);
      final character = factory.createCharacter(
        name: _characterName,
        race: _selectedRace!,
        characterClass: _selectedClass!,
        abilityScores: _abilityScores!,
      );
      
      // Create new game
      await ref.read(gameStateProvider.notifier).createNewGame(
        saveName: _saveNameController.text,
        character: character,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        context.go('/story');
      }
    }
  }
}

class _AbilityScoreDisplay extends StatelessWidget {
  final AbilityScores scores;
  
  const _AbilityScoreDisplay({required this.scores});
  
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _ScoreChip(label: 'STR', value: scores.strength, color: AppColors.strengthRed),
        _ScoreChip(label: 'DEX', value: scores.dexterity, color: AppColors.dexterityGreen),
        _ScoreChip(label: 'CON', value: scores.constitution, color: AppColors.constitutionOrange),
        _ScoreChip(label: 'INT', value: scores.intelligence, color: AppColors.intelligenceBlue),
        _ScoreChip(label: 'WIS', value: scores.wisdom, color: AppColors.wisdomSilver),
        _ScoreChip(label: 'CHA', value: scores.charisma, color: AppColors.charismaGold),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  
  const _ScoreChip({
    required this.label,
    required this.value,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    final modifier = ((value - 10) / 2).floor();
    final modStr = modifier >= 0 ? '+$modifier' : '$modifier';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.parchment,
            ),
          ),
          Text(
            modStr,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

