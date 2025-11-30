import 'package:equatable/equatable.dart';
import '../../core/constants/game_constants.dart';

/// Represents a message in the story log
class StoryMessageModel extends Equatable {
  final String id;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final String? speakerName;
  final String? speakerAvatarAsset;
  final SkillCheckResult? skillCheckResult;
  final CombatResult? combatResult;
  final List<String>? itemsReceived;
  final int? experienceGained;
  final bool isImportant;

  const StoryMessageModel({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.speakerName,
    this.speakerAvatarAsset,
    this.skillCheckResult,
    this.combatResult,
    this.itemsReceived,
    this.experienceGained,
    this.isImportant = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'speakerName': speakerName,
      'speakerAvatarAsset': speakerAvatarAsset,
      'skillCheckResult': skillCheckResult?.toJson(),
      'combatResult': combatResult?.toJson(),
      'itemsReceived': itemsReceived,
      'experienceGained': experienceGained,
      'isImportant': isImportant,
    };
  }

  factory StoryMessageModel.fromJson(Map<String, dynamic> json) {
    return StoryMessageModel(
      id: json['id'] as String,
      type: MessageType.values.firstWhere((t) => t.name == json['type']),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      speakerName: json['speakerName'] as String?,
      speakerAvatarAsset: json['speakerAvatarAsset'] as String?,
      skillCheckResult: json['skillCheckResult'] != null
          ? SkillCheckResult.fromJson(json['skillCheckResult'] as Map<String, dynamic>)
          : null,
      combatResult: json['combatResult'] != null
          ? CombatResult.fromJson(json['combatResult'] as Map<String, dynamic>)
          : null,
      itemsReceived: (json['itemsReceived'] as List<dynamic>?)?.cast<String>(),
      experienceGained: json['experienceGained'] as int?,
      isImportant: json['isImportant'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id, type, content, timestamp, speakerName, speakerAvatarAsset,
    skillCheckResult, combatResult, itemsReceived, experienceGained, isImportant,
  ];
}

/// Message types for the story log
enum MessageType {
  narration('Narration'),
  playerAction('Player Action'),
  dialogue('Dialogue'),
  skillCheck('Skill Check'),
  combat('Combat'),
  system('System'),
  itemReceived('Item Received'),
  questUpdate('Quest Update'),
  levelUp('Level Up');

  final String displayName;
  const MessageType(this.displayName);
}

/// Result of a skill check
class SkillCheckResult extends Equatable {
  final Skill? skill;
  final Ability? ability;
  final int diceRoll;
  final int modifier;
  final int totalResult;
  final int difficultyClass;
  final bool isSuccess;
  final bool isCriticalSuccess;
  final bool isCriticalFailure;
  final bool hadAdvantage;
  final bool hadDisadvantage;

  const SkillCheckResult({
    this.skill,
    this.ability,
    required this.diceRoll,
    required this.modifier,
    required this.totalResult,
    required this.difficultyClass,
    required this.isSuccess,
    this.isCriticalSuccess = false,
    this.isCriticalFailure = false,
    this.hadAdvantage = false,
    this.hadDisadvantage = false,
  });

  /// Get display name for the check type
  String get checkTypeName {
    if (skill != null) return skill!.displayName;
    if (ability != null) return ability!.fullName;
    return 'Check';
  }

  Map<String, dynamic> toJson() {
    return {
      'skill': skill?.name,
      'ability': ability?.name,
      'diceRoll': diceRoll,
      'modifier': modifier,
      'totalResult': totalResult,
      'difficultyClass': difficultyClass,
      'isSuccess': isSuccess,
      'isCriticalSuccess': isCriticalSuccess,
      'isCriticalFailure': isCriticalFailure,
      'hadAdvantage': hadAdvantage,
      'hadDisadvantage': hadDisadvantage,
    };
  }

  factory SkillCheckResult.fromJson(Map<String, dynamic> json) {
    return SkillCheckResult(
      skill: json['skill'] != null
          ? Skill.values.firstWhere((s) => s.name == json['skill'])
          : null,
      ability: json['ability'] != null
          ? Ability.values.firstWhere((a) => a.name == json['ability'])
          : null,
      diceRoll: json['diceRoll'] as int,
      modifier: json['modifier'] as int,
      totalResult: json['totalResult'] as int,
      difficultyClass: json['difficultyClass'] as int,
      isSuccess: json['isSuccess'] as bool,
      isCriticalSuccess: json['isCriticalSuccess'] as bool? ?? false,
      isCriticalFailure: json['isCriticalFailure'] as bool? ?? false,
      hadAdvantage: json['hadAdvantage'] as bool? ?? false,
      hadDisadvantage: json['hadDisadvantage'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    skill, ability, diceRoll, modifier, totalResult, difficultyClass,
    isSuccess, isCriticalSuccess, isCriticalFailure, hadAdvantage, hadDisadvantage,
  ];
}

/// Result of a combat action
class CombatResult extends Equatable {
  final String attackerName;
  final String defenderName;
  final CombatActionType actionType;
  final int? attackRoll;
  final int? damageRoll;
  final int? totalDamage;
  final DamageType? damageType;
  final bool isHit;
  final bool isCriticalHit;
  final bool isMiss;
  final bool isCriticalMiss;
  final int? healingAmount;
  final String? specialEffectDescription;

  const CombatResult({
    required this.attackerName,
    required this.defenderName,
    required this.actionType,
    this.attackRoll,
    this.damageRoll,
    this.totalDamage,
    this.damageType,
    this.isHit = false,
    this.isCriticalHit = false,
    this.isMiss = false,
    this.isCriticalMiss = false,
    this.healingAmount,
    this.specialEffectDescription,
  });

  Map<String, dynamic> toJson() {
    return {
      'attackerName': attackerName,
      'defenderName': defenderName,
      'actionType': actionType.name,
      'attackRoll': attackRoll,
      'damageRoll': damageRoll,
      'totalDamage': totalDamage,
      'damageType': damageType?.name,
      'isHit': isHit,
      'isCriticalHit': isCriticalHit,
      'isMiss': isMiss,
      'isCriticalMiss': isCriticalMiss,
      'healingAmount': healingAmount,
      'specialEffectDescription': specialEffectDescription,
    };
  }

  factory CombatResult.fromJson(Map<String, dynamic> json) {
    return CombatResult(
      attackerName: json['attackerName'] as String,
      defenderName: json['defenderName'] as String,
      actionType: CombatActionType.values.firstWhere((t) => t.name == json['actionType']),
      attackRoll: json['attackRoll'] as int?,
      damageRoll: json['damageRoll'] as int?,
      totalDamage: json['totalDamage'] as int?,
      damageType: json['damageType'] != null
          ? DamageType.values.firstWhere((d) => d.name == json['damageType'])
          : null,
      isHit: json['isHit'] as bool? ?? false,
      isCriticalHit: json['isCriticalHit'] as bool? ?? false,
      isMiss: json['isMiss'] as bool? ?? false,
      isCriticalMiss: json['isCriticalMiss'] as bool? ?? false,
      healingAmount: json['healingAmount'] as int?,
      specialEffectDescription: json['specialEffectDescription'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    attackerName, defenderName, actionType, attackRoll, damageRoll,
    totalDamage, damageType, isHit, isCriticalHit, isMiss, isCriticalMiss,
    healingAmount, specialEffectDescription,
  ];
}

/// Combat action types
enum CombatActionType {
  meleeAttack('Melee Attack'),
  rangedAttack('Ranged Attack'),
  spellAttack('Spell Attack'),
  healing('Healing'),
  buff('Buff'),
  debuff('Debuff'),
  dodge('Dodge'),
  defend('Defend'),
  flee('Flee'),
  special('Special');

  final String displayName;
  const CombatActionType(this.displayName);
}


