import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/game_constants.dart';
import '../../data/models/character_model.dart';
import '../providers/game_providers.dart';

/// Character sheet screen
class CharacterScreen extends ConsumerWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final character = ref.watch(characterProvider);
    final gold = ref.watch(goldProvider);

    if (character == null) {
      return const Center(
        child: Text('No character loaded'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: _buildHeader(context, character, gold),
          ),
          const SizedBox(height: 24),
          _buildAbilityScores(context, character),
          const SizedBox(height: 24),
          _buildCombatStats(context, character),
          const SizedBox(height: 24),
          _buildSkills(context, character),
          const SizedBox(height: 24),
          if (character.backgroundStory != null)
            _buildBackstory(context, character),
          const SizedBox(height: 100), // Bottom padding for nav bar
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CharacterModel character, int gold) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bgMedium,
            AppColors.bgDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dragonGold.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Character avatar/icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.dragonGold.withValues(alpha: 0.3),
                  AppColors.mysticPurple.withValues(alpha: 0.3),
                ],
              ),
              border: Border.all(color: AppColors.dragonGold, width: 2),
            ),
            child: Center(
              child: Text(
                character.name.substring(0, 1).toUpperCase(),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.dragonGold,
                ),
              ),
            ),
          ).animate()
            .scale(duration: 400.ms, curve: Curves.elasticOut),
          
          const SizedBox(height: 16),
          
          // Name
          Text(
            character.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          
          const SizedBox(height: 4),
          
          // Race and Class
          Text(
            '${character.race.displayName} ${character.characterClass.displayName}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.parchmentDark,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Level and XP
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatBadge(
                context,
                'Level',
                '${character.level}',
                AppColors.dragonGold,
              ),
              const SizedBox(width: 16),
              _buildStatBadge(
                context,
                'XP',
                '${character.experiencePoints}',
                AppColors.arcaneBlue,
              ),
              const SizedBox(width: 16),
              _buildStatBadge(
                context,
                'Gold',
                '$gold',
                AppColors.charismaGold,
              ),
            ],
          ),
          
          // XP progress bar
          const SizedBox(height: 16),
          _buildXPProgressBar(context, character),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .slideY(begin: -0.1, end: 0, duration: 400.ms);
  }

  Widget _buildStatBadge(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXPProgressBar(BuildContext context, CharacterModel character) {
    final currentLevelXP = character.level > 1 
        ? GameConstants.xpThresholds[character.level - 1] 
        : 0;
    final nextLevelXP = character.level < GameConstants.maxLevel
        ? GameConstants.xpThresholds[character.level]
        : GameConstants.xpThresholds.last;
    
    final progress = character.level >= GameConstants.maxLevel
        ? 1.0
        : (character.experiencePoints - currentLevelXP) / (nextLevelXP - currentLevelXP);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'XP to Level ${character.level + 1}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.parchmentDark,
              ),
            ),
            Text(
              '${character.xpToNextLevel} XP needed',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.parchmentDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.bgDark,
            valueColor: const AlwaysStoppedAnimation(AppColors.dragonGold),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildAbilityScores(BuildContext context, CharacterModel character) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ability Scores',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _AbilityScoreCard(
                ability: Ability.strength,
                score: character.abilityScores.strength,
                modifier: character.getAbilityModifier(Ability.strength),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AbilityScoreCard(
                ability: Ability.dexterity,
                score: character.abilityScores.dexterity,
                modifier: character.getAbilityModifier(Ability.dexterity),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AbilityScoreCard(
                ability: Ability.constitution,
                score: character.abilityScores.constitution,
                modifier: character.getAbilityModifier(Ability.constitution),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _AbilityScoreCard(
                ability: Ability.intelligence,
                score: character.abilityScores.intelligence,
                modifier: character.getAbilityModifier(Ability.intelligence),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AbilityScoreCard(
                ability: Ability.wisdom,
                score: character.abilityScores.wisdom,
                modifier: character.getAbilityModifier(Ability.wisdom),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AbilityScoreCard(
                ability: Ability.charisma,
                score: character.abilityScores.charisma,
                modifier: character.getAbilityModifier(Ability.charisma),
              ),
            ),
          ],
        ),
      ],
    ).animate()
      .fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildCombatStats(BuildContext context, CharacterModel character) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Combat',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _CombatStatCard(
                label: 'Hit Points',
                value: '${character.currentHitPoints}/${character.maxHitPoints}',
                icon: Icons.favorite,
                color: character.currentHitPoints > character.maxHitPoints / 2
                    ? AppColors.success
                    : character.currentHitPoints > character.maxHitPoints / 4
                        ? AppColors.warning
                        : AppColors.error,
                progress: character.currentHitPoints / character.maxHitPoints,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CombatStatCard(
                label: 'Armor Class',
                value: '${character.armorClass}',
                icon: Icons.shield,
                color: AppColors.arcaneBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CombatStatCard(
                label: 'Initiative',
                value: _formatModifier(character.initiativeModifier),
                icon: Icons.speed,
                color: AppColors.dexterityGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CombatStatCard(
                label: 'Proficiency',
                value: '+${character.proficiencyBonus}',
                icon: Icons.star,
                color: AppColors.dragonGold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CombatStatCard(
                label: 'Speed',
                value: '${character.speed} ft',
                icon: Icons.directions_run,
                color: AppColors.parchment,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CombatStatCard(
                label: 'Passive Perception',
                value: '${character.passivePerception}',
                icon: Icons.visibility,
                color: AppColors.wisdomSilver,
              ),
            ),
          ],
        ),
      ],
    ).animate()
      .fadeIn(delay: 300.ms, duration: 400.ms);
  }

  Widget _buildSkills(BuildContext context, CharacterModel character) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skills',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgMedium.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dragonGold.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: Skill.values.map((skill) {
              final isProficient = character.proficientSkills.contains(skill);
              final isExpert = character.expertiseSkills.contains(skill);
              final modifier = character.getSkillModifier(skill);
              
              return _SkillRow(
                skill: skill,
                modifier: modifier,
                isProficient: isProficient,
                isExpert: isExpert,
              );
            }).toList(),
          ),
        ),
      ],
    ).animate()
      .fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _buildBackstory(BuildContext context, CharacterModel character) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Backstory',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgMedium.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dragonGold.withValues(alpha: 0.2)),
          ),
          child: Text(
            character.backgroundStory!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.parchmentDark,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  String _formatModifier(int mod) {
    return mod >= 0 ? '+$mod' : '$mod';
  }
}

class _AbilityScoreCard extends StatelessWidget {
  final Ability ability;
  final int score;
  final int modifier;

  const _AbilityScoreCard({
    required this.ability,
    required this.score,
    required this.modifier,
  });

  Color get _color {
    switch (ability) {
      case Ability.strength:
        return AppColors.strengthRed;
      case Ability.dexterity:
        return AppColors.dexterityGreen;
      case Ability.constitution:
        return AppColors.constitutionOrange;
      case Ability.intelligence:
        return AppColors.intelligenceBlue;
      case Ability.wisdom:
        return AppColors.wisdomSilver;
      case Ability.charisma:
        return AppColors.charismaGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            ability.abbreviation,
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.parchment,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              modifier >= 0 ? '+$modifier' : '$modifier',
              style: TextStyle(
                color: _color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CombatStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress;

  const _CombatStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgMedium.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.parchmentDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.bgDark,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final Skill skill;
  final int modifier;
  final bool isProficient;
  final bool isExpert;

  const _SkillRow({
    required this.skill,
    required this.modifier,
    required this.isProficient,
    required this.isExpert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.dragonGold.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Proficiency indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isExpert 
                  ? AppColors.dragonGold
                  : isProficient 
                      ? AppColors.dragonGold.withValues(alpha: 0.5)
                      : Colors.transparent,
              border: Border.all(
                color: AppColors.dragonGold.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Skill name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isProficient ? AppColors.parchment : AppColors.parchmentDark,
                  ),
                ),
                Text(
                  skill.ability.abbreviation,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchmentDark.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          
          // Modifier
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isProficient 
                  ? AppColors.dragonGold.withValues(alpha: 0.15)
                  : AppColors.bgDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              modifier >= 0 ? '+$modifier' : '$modifier',
              style: TextStyle(
                color: isProficient ? AppColors.dragonGold : AppColors.parchmentDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


