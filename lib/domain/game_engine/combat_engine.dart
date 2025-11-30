import '../../core/constants/game_constants.dart';
import '../../data/models/character_model.dart';
import '../../data/models/monster_model.dart';
import 'dice_roller.dart';

/// Combat engine for handling D&D 5e combat mechanics
class CombatEngine {
  final DiceRoller _diceRoller;
  
  CombatEngine({DiceRoller? diceRoller}) : _diceRoller = diceRoller ?? DiceRoller();
  
  /// Roll initiative for all combatants
  List<InitiativeEntry> rollInitiative(
    CharacterModel player,
    List<MonsterModel> monsters,
  ) {
    final entries = <InitiativeEntry>[];
    
    // Player initiative
    final playerInit = _diceRoller.rollInitiative(player.initiativeModifier);
    entries.add(InitiativeEntry(
      id: player.id,
      name: player.name,
      initiative: playerInit,
      isPlayer: true,
      dexterity: player.abilityScores.dexterity,
    ));
    
    // Monster initiatives
    for (final monster in monsters) {
      final monsterInit = _diceRoller.rollInitiative(monster.initiativeModifier);
      entries.add(InitiativeEntry(
        id: monster.id,
        name: monster.name,
        initiative: monsterInit,
        isPlayer: false,
        dexterity: monster.abilityScores.dexterity,
      ));
    }
    
    // Sort by initiative (highest first), then by dexterity for ties
    entries.sort((a, b) {
      final initCompare = b.initiative.compareTo(a.initiative);
      if (initCompare != 0) return initCompare;
      return b.dexterity.compareTo(a.dexterity);
    });
    
    return entries;
  }
  
  /// Process a player attack against a monster
  PlayerAttackResult playerAttack({
    required CharacterModel player,
    required MonsterModel target,
    required int attackBonus,
    required String damageNotation,
    required DamageType damageType,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    // Roll attack
    final attackResult = _diceRoller.rollAttack(
      attackBonus: attackBonus,
      targetAC: target.armorClass,
      advantage: advantage,
      disadvantage: disadvantage,
    );
    
    if (!attackResult.isHit) {
      return PlayerAttackResult(
        attackRoll: attackResult,
        damageRoll: null,
        finalDamage: 0,
        targetNewHP: target.currentHitPoints,
        targetKilled: false,
        damageType: damageType,
      );
    }
    
    // Roll damage
    final damageResult = _diceRoller.rollDamage(
      damageNotation: damageNotation,
      isCritical: attackResult.isCriticalHit,
    );
    
    // Apply resistances/immunities/vulnerabilities
    int finalDamage = damageResult.total;
    final damageTypeName = damageType.displayName.toLowerCase();
    
    if (target.immunities.contains(damageTypeName)) {
      finalDamage = 0;
    } else if (target.resistances.contains(damageTypeName)) {
      finalDamage = (finalDamage / 2).floor();
    } else if (target.vulnerabilities.contains(damageTypeName)) {
      finalDamage = finalDamage * 2;
    }
    
    final newHP = (target.currentHitPoints - finalDamage).clamp(0, target.maxHitPoints);
    
    return PlayerAttackResult(
      attackRoll: attackResult,
      damageRoll: damageResult,
      finalDamage: finalDamage,
      targetNewHP: newHP,
      targetKilled: newHP <= 0,
      damageType: damageType,
    );
  }
  
  /// Process a monster attack against the player
  MonsterAttackResult monsterAttack({
    required MonsterModel attacker,
    required CharacterModel player,
    required MonsterAction action,
    double difficultyMultiplier = 1.0,
  }) {
    // Get attack bonus
    final attackBonus = action.attackBonus ?? attacker.proficiencyBonus + 
        attacker.getAbilityModifier(Ability.strength);
    
    // Roll attack
    final attackResult = _diceRoller.rollAttack(
      attackBonus: attackBonus,
      targetAC: player.armorClass,
    );
    
    if (!attackResult.isHit) {
      return MonsterAttackResult(
        attackerName: attacker.name,
        actionName: action.name,
        attackRoll: attackResult,
        damageRoll: null,
        finalDamage: 0,
        playerNewHP: player.currentHitPoints,
        playerKnocked: false,
        damageType: action.damageType,
      );
    }
    
    // Roll damage
    final damageNotation = action.damage ?? '1d6';
    final damageResult = _diceRoller.rollDamage(
      damageNotation: damageNotation,
      isCritical: attackResult.isCriticalHit,
    );
    
    // Apply difficulty multiplier
    int finalDamage = (damageResult.total * difficultyMultiplier).round();
    
    // Check player's temporary HP first
    int tempHPRemaining = player.temporaryHitPoints;
    if (tempHPRemaining > 0) {
      if (tempHPRemaining >= finalDamage) {
        tempHPRemaining -= finalDamage;
        finalDamage = 0;
      } else {
        finalDamage -= tempHPRemaining;
        tempHPRemaining = 0;
      }
    }
    
    final newHP = (player.currentHitPoints - finalDamage).clamp(0, player.maxHitPoints);
    
    return MonsterAttackResult(
      attackerName: attacker.name,
      actionName: action.name,
      attackRoll: attackResult,
      damageRoll: damageResult,
      finalDamage: finalDamage,
      playerNewHP: newHP,
      playerKnocked: newHP <= 0,
      damageType: action.damageType,
      tempHPRemaining: tempHPRemaining,
    );
  }
  
  /// Process healing
  HealingResult applyHealing({
    required CharacterModel target,
    required String healingNotation,
  }) {
    final healingRoll = _diceRoller.rollNotation(healingNotation);
    final newHP = (target.currentHitPoints + healingRoll.total)
        .clamp(0, target.maxHitPoints);
    final actualHealing = newHP - target.currentHitPoints;
    
    return HealingResult(
      healingRoll: healingRoll,
      actualHealing: actualHealing,
      newHP: newHP,
      wasAtFullHP: target.currentHitPoints == target.maxHitPoints,
    );
  }
  
  /// Roll a death saving throw
  DeathSaveResult rollDeathSave({
    required int currentSuccesses,
    required int currentFailures,
  }) {
    final roll = _diceRoller.rollD20();
    
    bool stabilized = false;
    bool died = false;
    int newSuccesses = currentSuccesses;
    int newFailures = currentFailures;
    
    if (roll == 20) {
      // Natural 20: regain 1 HP
      return DeathSaveResult(
        roll: roll,
        isSuccess: true,
        isNatural20: true,
        isNatural1: false,
        newSuccesses: 0,
        newFailures: 0,
        stabilized: false,
        died: false,
        regainedHP: true,
      );
    } else if (roll == 1) {
      // Natural 1: two failures
      newFailures += 2;
    } else if (roll >= 10) {
      // Success
      newSuccesses += 1;
    } else {
      // Failure
      newFailures += 1;
    }
    
    if (newSuccesses >= 3) {
      stabilized = true;
      newSuccesses = 0;
      newFailures = 0;
    } else if (newFailures >= 3) {
      died = true;
    }
    
    return DeathSaveResult(
      roll: roll,
      isSuccess: roll >= 10,
      isNatural20: roll == 20,
      isNatural1: roll == 1,
      newSuccesses: newSuccesses,
      newFailures: newFailures,
      stabilized: stabilized,
      died: died,
      regainedHP: false,
    );
  }
  
  /// Calculate experience points for defeating monsters
  int calculateExperienceReward(List<MonsterModel> defeatedMonsters) {
    return defeatedMonsters.fold(0, (sum, m) => sum + m.experienceValue);
  }
  
  /// Check if player levels up
  LevelUpResult checkLevelUp(CharacterModel character, int xpGained) {
    final newXP = character.experiencePoints + xpGained;
    int newLevel = character.level;
    
    // Find new level based on XP thresholds
    for (int i = GameConstants.xpThresholds.length - 1; i >= 0; i--) {
      if (newXP >= GameConstants.xpThresholds[i]) {
        newLevel = i + 1;
        break;
      }
    }
    
    final levelsGained = newLevel - character.level;
    
    if (levelsGained > 0) {
      // Calculate HP increase
      final hitDice = GameConstants.hitDiceByClass[character.characterClass.name] ?? GameConstants.d8;
      final conMod = character.getAbilityModifier(Ability.constitution);
      int hpIncrease = 0;
      
      for (int i = 0; i < levelsGained; i++) {
        // Average HP per level (rounded up) + CON modifier
        hpIncrease += ((hitDice / 2).ceil() + 1) + conMod;
      }
      
      return LevelUpResult(
        didLevelUp: true,
        oldLevel: character.level,
        newLevel: newLevel,
        newXP: newXP,
        hpIncrease: hpIncrease,
        newProficiencyBonus: GameConstants.proficiencyBonus[newLevel - 1],
      );
    }
    
    return LevelUpResult(
      didLevelUp: false,
      oldLevel: character.level,
      newLevel: character.level,
      newXP: newXP,
      hpIncrease: 0,
      newProficiencyBonus: character.proficiencyBonus,
    );
  }
}

/// Initiative entry for combat order
class InitiativeEntry {
  final String id;
  final String name;
  final int initiative;
  final bool isPlayer;
  final int dexterity;
  
  const InitiativeEntry({
    required this.id,
    required this.name,
    required this.initiative,
    required this.isPlayer,
    required this.dexterity,
  });
}

/// Result of a player attack
class PlayerAttackResult {
  final AttackRollResult attackRoll;
  final DamageRollResult? damageRoll;
  final int finalDamage;
  final int targetNewHP;
  final bool targetKilled;
  final DamageType damageType;
  
  const PlayerAttackResult({
    required this.attackRoll,
    this.damageRoll,
    required this.finalDamage,
    required this.targetNewHP,
    required this.targetKilled,
    required this.damageType,
  });
  
  bool get isHit => attackRoll.isHit;
  bool get isCritical => attackRoll.isCriticalHit;
}

/// Result of a monster attack
class MonsterAttackResult {
  final String attackerName;
  final String actionName;
  final AttackRollResult attackRoll;
  final DamageRollResult? damageRoll;
  final int finalDamage;
  final int playerNewHP;
  final bool playerKnocked;
  final DamageType? damageType;
  final int? tempHPRemaining;
  
  const MonsterAttackResult({
    required this.attackerName,
    required this.actionName,
    required this.attackRoll,
    this.damageRoll,
    required this.finalDamage,
    required this.playerNewHP,
    required this.playerKnocked,
    this.damageType,
    this.tempHPRemaining,
  });
  
  bool get isHit => attackRoll.isHit;
  bool get isCritical => attackRoll.isCriticalHit;
}

/// Result of healing
class HealingResult {
  final DiceNotationResult healingRoll;
  final int actualHealing;
  final int newHP;
  final bool wasAtFullHP;
  
  const HealingResult({
    required this.healingRoll,
    required this.actualHealing,
    required this.newHP,
    required this.wasAtFullHP,
  });
}

/// Result of a death saving throw
class DeathSaveResult {
  final int roll;
  final bool isSuccess;
  final bool isNatural20;
  final bool isNatural1;
  final int newSuccesses;
  final int newFailures;
  final bool stabilized;
  final bool died;
  final bool regainedHP;
  
  const DeathSaveResult({
    required this.roll,
    required this.isSuccess,
    required this.isNatural20,
    required this.isNatural1,
    required this.newSuccesses,
    required this.newFailures,
    required this.stabilized,
    required this.died,
    required this.regainedHP,
  });
}

/// Result of level up check
class LevelUpResult {
  final bool didLevelUp;
  final int oldLevel;
  final int newLevel;
  final int newXP;
  final int hpIncrease;
  final int newProficiencyBonus;
  
  const LevelUpResult({
    required this.didLevelUp,
    required this.oldLevel,
    required this.newLevel,
    required this.newXP,
    required this.hpIncrease,
    required this.newProficiencyBonus,
  });
  
  int get levelsGained => newLevel - oldLevel;
}


