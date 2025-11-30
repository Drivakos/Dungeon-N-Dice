import 'dart:math';
import '../../core/constants/game_constants.dart';

/// Dice roller utility for D&D 5e mechanics
class DiceRoller {
  final Random _random;
  
  DiceRoller({Random? random}) : _random = random ?? Random();
  
  /// Roll a single die
  int rollDie(int sides) {
    return _random.nextInt(sides) + 1;
  }
  
  /// Roll multiple dice of the same type
  DiceRollResult rollDice(int count, int sides) {
    final rolls = List.generate(count, (_) => rollDie(sides));
    return DiceRollResult(
      rolls: rolls,
      total: rolls.fold(0, (sum, roll) => sum + roll),
      sides: sides,
    );
  }
  
  /// Roll a d20
  int rollD20() => rollDie(GameConstants.d20);
  
  /// Roll a d20 with advantage (roll twice, take higher)
  D20RollResult rollD20WithAdvantage() {
    final roll1 = rollD20();
    final roll2 = rollD20();
    return D20RollResult(
      result: roll1 > roll2 ? roll1 : roll2,
      roll1: roll1,
      roll2: roll2,
      hadAdvantage: true,
      hadDisadvantage: false,
    );
  }
  
  /// Roll a d20 with disadvantage (roll twice, take lower)
  D20RollResult rollD20WithDisadvantage() {
    final roll1 = rollD20();
    final roll2 = rollD20();
    return D20RollResult(
      result: roll1 < roll2 ? roll1 : roll2,
      roll1: roll1,
      roll2: roll2,
      hadAdvantage: false,
      hadDisadvantage: true,
    );
  }
  
  /// Roll a d20 with optional advantage/disadvantage
  D20RollResult rollD20Check({bool advantage = false, bool disadvantage = false}) {
    // If both advantage and disadvantage, they cancel out
    if (advantage && disadvantage) {
      final roll = rollD20();
      return D20RollResult(
        result: roll,
        roll1: roll,
        roll2: null,
        hadAdvantage: false,
        hadDisadvantage: false,
      );
    }
    
    if (advantage) return rollD20WithAdvantage();
    if (disadvantage) return rollD20WithDisadvantage();
    
    final roll = rollD20();
    return D20RollResult(
      result: roll,
      roll1: roll,
      roll2: null,
      hadAdvantage: false,
      hadDisadvantage: false,
    );
  }
  
  /// Parse and roll dice notation (e.g., "2d6+3", "1d8", "3d6-1")
  DiceNotationResult rollNotation(String notation) {
    final regex = RegExp(r'^(\d+)d(\d+)([+-]\d+)?$');
    final match = regex.firstMatch(notation.toLowerCase().replaceAll(' ', ''));
    
    if (match == null) {
      throw ArgumentError('Invalid dice notation: $notation');
    }
    
    final count = int.parse(match.group(1)!);
    final sides = int.parse(match.group(2)!);
    final modifierStr = match.group(3);
    final modifier = modifierStr != null ? int.parse(modifierStr) : 0;
    
    final rollResult = rollDice(count, sides);
    final total = rollResult.total + modifier;
    
    return DiceNotationResult(
      notation: notation,
      rolls: rollResult.rolls,
      modifier: modifier,
      total: total,
      sides: sides,
    );
  }
  
  /// Roll for initiative
  int rollInitiative(int dexterityModifier) {
    return rollD20() + dexterityModifier;
  }
  
  /// Roll a skill check
  SkillCheckRollResult rollSkillCheck({
    required int modifier,
    required int difficultyClass,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    final d20Roll = rollD20Check(advantage: advantage, disadvantage: disadvantage);
    final total = d20Roll.result + modifier;
    final isNatural20 = d20Roll.result == GameConstants.criticalHitThreshold;
    final isNatural1 = d20Roll.result == GameConstants.criticalFailThreshold;
    
    return SkillCheckRollResult(
      d20Roll: d20Roll,
      modifier: modifier,
      total: total,
      difficultyClass: difficultyClass,
      isSuccess: total >= difficultyClass,
      isCriticalSuccess: isNatural20,
      isCriticalFailure: isNatural1,
    );
  }
  
  /// Roll an attack
  AttackRollResult rollAttack({
    required int attackBonus,
    required int targetAC,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    final d20Roll = rollD20Check(advantage: advantage, disadvantage: disadvantage);
    final total = d20Roll.result + attackBonus;
    final isNatural20 = d20Roll.result == GameConstants.criticalHitThreshold;
    final isNatural1 = d20Roll.result == GameConstants.criticalFailThreshold;
    
    // Natural 20 always hits, natural 1 always misses
    final isHit = isNatural20 || (!isNatural1 && total >= targetAC);
    
    return AttackRollResult(
      d20Roll: d20Roll,
      attackBonus: attackBonus,
      total: total,
      targetAC: targetAC,
      isHit: isHit,
      isCriticalHit: isNatural20,
      isCriticalMiss: isNatural1,
    );
  }
  
  /// Roll damage
  DamageRollResult rollDamage({
    required String damageNotation,
    bool isCritical = false,
  }) {
    // For critical hits, double the dice
    String notation = damageNotation;
    if (isCritical) {
      final regex = RegExp(r'^(\d+)d(\d+)([+-]\d+)?$');
      final match = regex.firstMatch(notation.toLowerCase().replaceAll(' ', ''));
      if (match != null) {
        final count = int.parse(match.group(1)!) * 2;
        final sides = match.group(2)!;
        final modifier = match.group(3) ?? '';
        notation = '${count}d$sides$modifier';
      }
    }
    
    final rollResult = rollNotation(notation);
    
    return DamageRollResult(
      originalNotation: damageNotation,
      rolledNotation: notation,
      rolls: rollResult.rolls,
      modifier: rollResult.modifier,
      total: rollResult.total,
      isCritical: isCritical,
    );
  }
  
  /// Roll a saving throw
  SavingThrowResult rollSavingThrow({
    required int modifier,
    required int difficultyClass,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    final d20Roll = rollD20Check(advantage: advantage, disadvantage: disadvantage);
    final total = d20Roll.result + modifier;
    final isNatural20 = d20Roll.result == GameConstants.criticalHitThreshold;
    final isNatural1 = d20Roll.result == GameConstants.criticalFailThreshold;
    
    return SavingThrowResult(
      d20Roll: d20Roll,
      modifier: modifier,
      total: total,
      difficultyClass: difficultyClass,
      isSuccess: total >= difficultyClass,
      isAutoSuccess: isNatural20,
      isAutoFailure: isNatural1,
    );
  }
  
  /// Roll ability scores using 4d6 drop lowest
  AbilityScoreRollResult rollAbilityScore() {
    final rolls = List.generate(4, (_) => rollDie(6));
    rolls.sort((a, b) => b.compareTo(a)); // Sort descending
    final keptRolls = rolls.take(3).toList();
    final droppedRoll = rolls.last;
    final total = keptRolls.fold(0, (sum, roll) => sum + roll);
    
    return AbilityScoreRollResult(
      allRolls: rolls,
      keptRolls: keptRolls,
      droppedRoll: droppedRoll,
      total: total,
    );
  }
  
  /// Roll a complete set of ability scores
  List<AbilityScoreRollResult> rollAbilityScoreSet() {
    return List.generate(6, (_) => rollAbilityScore());
  }
}

/// Result of rolling multiple dice
class DiceRollResult {
  final List<int> rolls;
  final int total;
  final int sides;
  
  const DiceRollResult({
    required this.rolls,
    required this.total,
    required this.sides,
  });
  
  @override
  String toString() => '${rolls.length}d$sides: $rolls = $total';
}

/// Result of a d20 roll with potential advantage/disadvantage
class D20RollResult {
  final int result;
  final int roll1;
  final int? roll2;
  final bool hadAdvantage;
  final bool hadDisadvantage;
  
  const D20RollResult({
    required this.result,
    required this.roll1,
    this.roll2,
    required this.hadAdvantage,
    required this.hadDisadvantage,
  });
  
  bool get isNatural20 => result == 20;
  bool get isNatural1 => result == 1;
  
  @override
  String toString() {
    if (hadAdvantage) return 'd20 (adv): $roll1, $roll2 → $result';
    if (hadDisadvantage) return 'd20 (dis): $roll1, $roll2 → $result';
    return 'd20: $result';
  }
}

/// Result of rolling dice notation
class DiceNotationResult {
  final String notation;
  final List<int> rolls;
  final int modifier;
  final int total;
  final int sides;
  
  const DiceNotationResult({
    required this.notation,
    required this.rolls,
    required this.modifier,
    required this.total,
    required this.sides,
  });
  
  @override
  String toString() {
    final modStr = modifier > 0 ? '+$modifier' : modifier < 0 ? '$modifier' : '';
    return '$notation: $rolls$modStr = $total';
  }
}

/// Result of a skill check roll
class SkillCheckRollResult {
  final D20RollResult d20Roll;
  final int modifier;
  final int total;
  final int difficultyClass;
  final bool isSuccess;
  final bool isCriticalSuccess;
  final bool isCriticalFailure;
  
  const SkillCheckRollResult({
    required this.d20Roll,
    required this.modifier,
    required this.total,
    required this.difficultyClass,
    required this.isSuccess,
    required this.isCriticalSuccess,
    required this.isCriticalFailure,
  });
  
  @override
  String toString() {
    final modStr = modifier >= 0 ? '+$modifier' : '$modifier';
    final resultStr = isSuccess ? 'SUCCESS' : 'FAILURE';
    return 'Skill Check: ${d20Roll.result}$modStr = $total vs DC $difficultyClass → $resultStr';
  }
}

/// Result of an attack roll
class AttackRollResult {
  final D20RollResult d20Roll;
  final int attackBonus;
  final int total;
  final int targetAC;
  final bool isHit;
  final bool isCriticalHit;
  final bool isCriticalMiss;
  
  const AttackRollResult({
    required this.d20Roll,
    required this.attackBonus,
    required this.total,
    required this.targetAC,
    required this.isHit,
    required this.isCriticalHit,
    required this.isCriticalMiss,
  });
  
  @override
  String toString() {
    final modStr = attackBonus >= 0 ? '+$attackBonus' : '$attackBonus';
    final resultStr = isCriticalHit ? 'CRITICAL HIT!' : 
                      isCriticalMiss ? 'CRITICAL MISS!' :
                      isHit ? 'HIT' : 'MISS';
    return 'Attack: ${d20Roll.result}$modStr = $total vs AC $targetAC → $resultStr';
  }
}

/// Result of a damage roll
class DamageRollResult {
  final String originalNotation;
  final String rolledNotation;
  final List<int> rolls;
  final int modifier;
  final int total;
  final bool isCritical;
  
  const DamageRollResult({
    required this.originalNotation,
    required this.rolledNotation,
    required this.rolls,
    required this.modifier,
    required this.total,
    required this.isCritical,
  });
  
  @override
  String toString() {
    final critStr = isCritical ? ' (CRITICAL)' : '';
    return 'Damage$critStr: $rolls + $modifier = $total';
  }
}

/// Result of a saving throw
class SavingThrowResult {
  final D20RollResult d20Roll;
  final int modifier;
  final int total;
  final int difficultyClass;
  final bool isSuccess;
  final bool isAutoSuccess;
  final bool isAutoFailure;
  
  const SavingThrowResult({
    required this.d20Roll,
    required this.modifier,
    required this.total,
    required this.difficultyClass,
    required this.isSuccess,
    required this.isAutoSuccess,
    required this.isAutoFailure,
  });
  
  @override
  String toString() {
    final modStr = modifier >= 0 ? '+$modifier' : '$modifier';
    final resultStr = isSuccess ? 'SUCCESS' : 'FAILURE';
    return 'Saving Throw: ${d20Roll.result}$modStr = $total vs DC $difficultyClass → $resultStr';
  }
}

/// Result of rolling ability score (4d6 drop lowest)
class AbilityScoreRollResult {
  final List<int> allRolls;
  final List<int> keptRolls;
  final int droppedRoll;
  final int total;
  
  const AbilityScoreRollResult({
    required this.allRolls,
    required this.keptRolls,
    required this.droppedRoll,
    required this.total,
  });
  
  @override
  String toString() => '4d6 drop lowest: $allRolls → kept $keptRolls = $total';
}


