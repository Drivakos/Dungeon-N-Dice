import '../../core/constants/game_constants.dart';
import '../../data/models/character_model.dart';
import '../../data/models/ai_response_model.dart';
import '../../data/models/story_message_model.dart';
import 'dice_roller.dart';

/// Engine for handling skill checks and ability checks
class SkillCheckEngine {
  final DiceRoller _diceRoller;
  
  SkillCheckEngine({DiceRoller? diceRoller}) : _diceRoller = diceRoller ?? DiceRoller();
  
  /// Perform a skill check based on AI proposal
  SkillCheckOutcome performSkillCheck({
    required CharacterModel character,
    required ProposedCheck proposal,
  }) {
    int modifier = 0;
    Skill? skill;
    Ability? ability;
    
    switch (proposal.checkType) {
      case CheckType.skill:
        skill = proposal.skill;
        if (skill != null) {
          modifier = character.getSkillModifier(skill);
          ability = skill.ability;
        }
        break;
      case CheckType.ability:
      case CheckType.savingThrow:
        ability = proposal.ability;
        if (ability != null) {
          modifier = character.getAbilityModifier(ability);
          // Add proficiency for saving throws if proficient
          // (This would need saving throw proficiency tracking)
        }
        break;
      case CheckType.attack:
      case CheckType.contest:
        ability = proposal.ability ?? Ability.strength;
        modifier = character.getAbilityModifier(ability);
        modifier += character.proficiencyBonus;
        break;
    }
    
    final rollResult = _diceRoller.rollSkillCheck(
      modifier: modifier,
      difficultyClass: proposal.difficultyClass,
      advantage: proposal.canUseAdvantage,
      disadvantage: proposal.hasDisadvantage,
    );
    
    return SkillCheckOutcome(
      skill: skill,
      ability: ability,
      rollResult: rollResult,
      isSuccess: rollResult.isSuccess,
      marginOfSuccess: rollResult.total - proposal.difficultyClass,
      description: proposal.description,
    );
  }
  
  /// Perform a raw ability check
  SkillCheckOutcome performAbilityCheck({
    required CharacterModel character,
    required Ability ability,
    required int difficultyClass,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    final modifier = character.getAbilityModifier(ability);
    
    final rollResult = _diceRoller.rollSkillCheck(
      modifier: modifier,
      difficultyClass: difficultyClass,
      advantage: advantage,
      disadvantage: disadvantage,
    );
    
    return SkillCheckOutcome(
      skill: null,
      ability: ability,
      rollResult: rollResult,
      isSuccess: rollResult.isSuccess,
      marginOfSuccess: rollResult.total - difficultyClass,
      description: null,
    );
  }
  
  /// Perform a skill check by skill type
  SkillCheckOutcome performSkillCheckByType({
    required CharacterModel character,
    required Skill skill,
    required int difficultyClass,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    final modifier = character.getSkillModifier(skill);
    
    final rollResult = _diceRoller.rollSkillCheck(
      modifier: modifier,
      difficultyClass: difficultyClass,
      advantage: advantage,
      disadvantage: disadvantage,
    );
    
    return SkillCheckOutcome(
      skill: skill,
      ability: skill.ability,
      rollResult: rollResult,
      isSuccess: rollResult.isSuccess,
      marginOfSuccess: rollResult.total - difficultyClass,
      description: null,
    );
  }
  
  /// Convert skill check outcome to a story message result
  SkillCheckResult toStoryResult(SkillCheckOutcome outcome) {
    return SkillCheckResult(
      skill: outcome.skill,
      ability: outcome.ability,
      diceRoll: outcome.rollResult.d20Roll.result,
      modifier: outcome.rollResult.modifier,
      totalResult: outcome.rollResult.total,
      difficultyClass: outcome.rollResult.difficultyClass,
      isSuccess: outcome.isSuccess,
      isCriticalSuccess: outcome.rollResult.isCriticalSuccess,
      isCriticalFailure: outcome.rollResult.isCriticalFailure,
      hadAdvantage: outcome.rollResult.d20Roll.hadAdvantage,
      hadDisadvantage: outcome.rollResult.d20Roll.hadDisadvantage,
    );
  }
  
  /// Get the difficulty description for a DC
  String getDifficultyDescription(int dc) {
    if (dc <= GameConstants.dcVeryEasy) return 'Very Easy';
    if (dc <= GameConstants.dcEasy) return 'Easy';
    if (dc <= GameConstants.dcMedium) return 'Medium';
    if (dc <= GameConstants.dcHard) return 'Hard';
    if (dc <= GameConstants.dcVeryHard) return 'Very Hard';
    return 'Nearly Impossible';
  }
  
  /// Calculate passive check value
  int getPassiveCheck(CharacterModel character, Skill skill) {
    return 10 + character.getSkillModifier(skill);
  }
  
  /// Perform a contested check between player and NPC/monster
  ContestedCheckOutcome performContestedCheck({
    required CharacterModel character,
    required Skill playerSkill,
    required int opponentModifier,
    String? opponentName,
    bool playerAdvantage = false,
    bool playerDisadvantage = false,
    bool opponentAdvantage = false,
    bool opponentDisadvantage = false,
  }) {
    // Player roll
    final playerModifier = character.getSkillModifier(playerSkill);
    final playerRoll = _diceRoller.rollD20Check(
      advantage: playerAdvantage,
      disadvantage: playerDisadvantage,
    );
    final playerTotal = playerRoll.result + playerModifier;
    
    // Opponent roll
    final opponentRoll = _diceRoller.rollD20Check(
      advantage: opponentAdvantage,
      disadvantage: opponentDisadvantage,
    );
    final opponentTotal = opponentRoll.result + opponentModifier;
    
    // Determine winner (player wins ties)
    final playerWins = playerTotal >= opponentTotal;
    
    return ContestedCheckOutcome(
      playerSkill: playerSkill,
      playerRoll: playerRoll,
      playerModifier: playerModifier,
      playerTotal: playerTotal,
      opponentName: opponentName ?? 'Opponent',
      opponentRoll: opponentRoll,
      opponentModifier: opponentModifier,
      opponentTotal: opponentTotal,
      playerWins: playerWins,
      margin: (playerTotal - opponentTotal).abs(),
    );
  }
}

/// Outcome of a skill check
class SkillCheckOutcome {
  final Skill? skill;
  final Ability? ability;
  final SkillCheckRollResult rollResult;
  final bool isSuccess;
  final int marginOfSuccess;
  final String? description;
  
  const SkillCheckOutcome({
    this.skill,
    this.ability,
    required this.rollResult,
    required this.isSuccess,
    required this.marginOfSuccess,
    this.description,
  });
  
  /// Get a narrative description of the outcome
  String get narrativeDescription {
    if (rollResult.isCriticalSuccess) {
      return 'Critical Success! A perfect execution!';
    }
    if (rollResult.isCriticalFailure) {
      return 'Critical Failure! Everything that could go wrong, did.';
    }
    if (isSuccess) {
      if (marginOfSuccess >= 10) {
        return 'Exceptional Success! You exceeded expectations.';
      }
      if (marginOfSuccess >= 5) {
        return 'Success! You accomplished your goal with skill.';
      }
      return 'Success! You barely managed to pull it off.';
    } else {
      if (marginOfSuccess <= -10) {
        return 'Catastrophic Failure! This went very badly.';
      }
      if (marginOfSuccess <= -5) {
        return 'Failure. You were clearly outmatched.';
      }
      return 'Failure. So close, yet not quite enough.';
    }
  }
  
  /// Check type name for display
  String get checkTypeName {
    if (skill != null) return '${skill!.displayName} Check';
    if (ability != null) return '${ability!.fullName} Check';
    return 'Check';
  }
}

/// Outcome of a contested check
class ContestedCheckOutcome {
  final Skill playerSkill;
  final D20RollResult playerRoll;
  final int playerModifier;
  final int playerTotal;
  final String opponentName;
  final D20RollResult opponentRoll;
  final int opponentModifier;
  final int opponentTotal;
  final bool playerWins;
  final int margin;
  
  const ContestedCheckOutcome({
    required this.playerSkill,
    required this.playerRoll,
    required this.playerModifier,
    required this.playerTotal,
    required this.opponentName,
    required this.opponentRoll,
    required this.opponentModifier,
    required this.opponentTotal,
    required this.playerWins,
    required this.margin,
  });
  
  String get resultDescription {
    if (playerWins) {
      if (margin >= 10) return 'Dominant victory!';
      if (margin >= 5) return 'Clear victory!';
      return 'Narrow victory!';
    } else {
      if (margin >= 10) return 'Overwhelming defeat.';
      if (margin >= 5) return 'Clear defeat.';
      return 'Narrow defeat.';
    }
  }
}


