import 'package:equatable/equatable.dart';
import '../../core/constants/game_constants.dart';

/// Represents the player's character with all D&D 5e stats
class CharacterModel extends Equatable {
  final String id;
  final String name;
  final CharacterRace race;
  final CharacterClass characterClass;
  final int level;
  final int experiencePoints;
  final AbilityScores abilityScores;
  final int currentHitPoints;
  final int maxHitPoints;
  final int temporaryHitPoints;
  final int armorClass;
  final int speed;
  final Set<Skill> proficientSkills;
  final Set<Skill> expertiseSkills;
  final List<String> equippedItems;
  final String? backgroundStory;
  final List<Condition> conditions;
  final int hitDiceRemaining;
  final int deathSaveSuccesses;
  final int deathSaveFailures;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CharacterModel({
    required this.id,
    required this.name,
    required this.race,
    required this.characterClass,
    this.level = 1,
    this.experiencePoints = 0,
    required this.abilityScores,
    required this.currentHitPoints,
    required this.maxHitPoints,
    this.temporaryHitPoints = 0,
    required this.armorClass,
    this.speed = GameConstants.defaultSpeed,
    this.proficientSkills = const {},
    this.expertiseSkills = const {},
    this.equippedItems = const [],
    this.backgroundStory,
    this.conditions = const [],
    required this.hitDiceRemaining,
    this.deathSaveSuccesses = 0,
    this.deathSaveFailures = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get proficiency bonus based on level
  int get proficiencyBonus => GameConstants.proficiencyBonus[level - 1];

  /// Get hit dice type based on class
  int get hitDiceType => GameConstants.hitDiceByClass[characterClass.name] ?? GameConstants.d8;

  /// Check if character is alive
  bool get isAlive => currentHitPoints > 0 || deathSaveFailures < 3;

  /// Check if character is unconscious
  bool get isUnconscious => currentHitPoints <= 0 && isAlive;

  /// Get modifier for an ability
  int getAbilityModifier(Ability ability) {
    return GameConstants.getModifier(abilityScores.getScore(ability));
  }

  /// Get skill modifier including proficiency
  int getSkillModifier(Skill skill) {
    int modifier = getAbilityModifier(skill.ability);
    
    if (expertiseSkills.contains(skill)) {
      modifier += proficiencyBonus * 2;
    } else if (proficientSkills.contains(skill)) {
      modifier += proficiencyBonus;
    }
    
    return modifier;
  }

  /// Get initiative modifier
  int get initiativeModifier => getAbilityModifier(Ability.dexterity);

  /// Get passive perception
  int get passivePerception => 10 + getSkillModifier(Skill.perception);

  /// Calculate XP needed for next level
  int get xpToNextLevel {
    if (level >= GameConstants.maxLevel) return 0;
    return GameConstants.xpThresholds[level] - experiencePoints;
  }

  /// Calculate carry capacity
  int get carryCapacity => 
      abilityScores.strength * GameConstants.carryCapacityMultiplier;

  CharacterModel copyWith({
    String? id,
    String? name,
    CharacterRace? race,
    CharacterClass? characterClass,
    int? level,
    int? experiencePoints,
    AbilityScores? abilityScores,
    int? currentHitPoints,
    int? maxHitPoints,
    int? temporaryHitPoints,
    int? armorClass,
    int? speed,
    Set<Skill>? proficientSkills,
    Set<Skill>? expertiseSkills,
    List<String>? equippedItems,
    String? backgroundStory,
    List<Condition>? conditions,
    int? hitDiceRemaining,
    int? deathSaveSuccesses,
    int? deathSaveFailures,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CharacterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      race: race ?? this.race,
      characterClass: characterClass ?? this.characterClass,
      level: level ?? this.level,
      experiencePoints: experiencePoints ?? this.experiencePoints,
      abilityScores: abilityScores ?? this.abilityScores,
      currentHitPoints: currentHitPoints ?? this.currentHitPoints,
      maxHitPoints: maxHitPoints ?? this.maxHitPoints,
      temporaryHitPoints: temporaryHitPoints ?? this.temporaryHitPoints,
      armorClass: armorClass ?? this.armorClass,
      speed: speed ?? this.speed,
      proficientSkills: proficientSkills ?? this.proficientSkills,
      expertiseSkills: expertiseSkills ?? this.expertiseSkills,
      equippedItems: equippedItems ?? this.equippedItems,
      backgroundStory: backgroundStory ?? this.backgroundStory,
      conditions: conditions ?? this.conditions,
      hitDiceRemaining: hitDiceRemaining ?? this.hitDiceRemaining,
      deathSaveSuccesses: deathSaveSuccesses ?? this.deathSaveSuccesses,
      deathSaveFailures: deathSaveFailures ?? this.deathSaveFailures,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'race': race.name,
      'characterClass': characterClass.name,
      'level': level,
      'experiencePoints': experiencePoints,
      'abilityScores': abilityScores.toJson(),
      'currentHitPoints': currentHitPoints,
      'maxHitPoints': maxHitPoints,
      'temporaryHitPoints': temporaryHitPoints,
      'armorClass': armorClass,
      'speed': speed,
      'proficientSkills': proficientSkills.map((s) => s.name).toList(),
      'expertiseSkills': expertiseSkills.map((s) => s.name).toList(),
      'equippedItems': equippedItems,
      'backgroundStory': backgroundStory,
      'conditions': conditions.map((c) => c.name).toList(),
      'hitDiceRemaining': hitDiceRemaining,
      'deathSaveSuccesses': deathSaveSuccesses,
      'deathSaveFailures': deathSaveFailures,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      race: CharacterRace.values.firstWhere((r) => r.name == json['race']),
      characterClass: CharacterClass.values.firstWhere((c) => c.name == json['characterClass']),
      level: json['level'] as int,
      experiencePoints: json['experiencePoints'] as int,
      abilityScores: AbilityScores.fromJson(json['abilityScores'] as Map<String, dynamic>),
      currentHitPoints: json['currentHitPoints'] as int,
      maxHitPoints: json['maxHitPoints'] as int,
      temporaryHitPoints: json['temporaryHitPoints'] as int? ?? 0,
      armorClass: json['armorClass'] as int,
      speed: json['speed'] as int? ?? GameConstants.defaultSpeed,
      proficientSkills: (json['proficientSkills'] as List<dynamic>?)
          ?.map((s) => Skill.values.firstWhere((sk) => sk.name == s))
          .toSet() ?? {},
      expertiseSkills: (json['expertiseSkills'] as List<dynamic>?)
          ?.map((s) => Skill.values.firstWhere((sk) => sk.name == s))
          .toSet() ?? {},
      equippedItems: (json['equippedItems'] as List<dynamic>?)?.cast<String>() ?? [],
      backgroundStory: json['backgroundStory'] as String?,
      conditions: (json['conditions'] as List<dynamic>?)
          ?.map((c) => Condition.values.firstWhere((co) => co.name == c))
          .toList() ?? [],
      hitDiceRemaining: json['hitDiceRemaining'] as int,
      deathSaveSuccesses: json['deathSaveSuccesses'] as int? ?? 0,
      deathSaveFailures: json['deathSaveFailures'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id, name, race, characterClass, level, experiencePoints,
    abilityScores, currentHitPoints, maxHitPoints, temporaryHitPoints,
    armorClass, speed, proficientSkills, expertiseSkills, equippedItems,
    backgroundStory, conditions, hitDiceRemaining, deathSaveSuccesses,
    deathSaveFailures, createdAt, updatedAt,
  ];
}

/// Represents the six ability scores
class AbilityScores extends Equatable {
  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;

  const AbilityScores({
    required this.strength,
    required this.dexterity,
    required this.constitution,
    required this.intelligence,
    required this.wisdom,
    required this.charisma,
  });

  /// Get score by ability enum
  int getScore(Ability ability) {
    switch (ability) {
      case Ability.strength:
        return strength;
      case Ability.dexterity:
        return dexterity;
      case Ability.constitution:
        return constitution;
      case Ability.intelligence:
        return intelligence;
      case Ability.wisdom:
        return wisdom;
      case Ability.charisma:
        return charisma;
    }
  }

  /// Get modifier by ability enum
  int getModifier(Ability ability) {
    return GameConstants.getModifier(getScore(ability));
  }

  /// Default starting scores
  factory AbilityScores.standard() {
    return const AbilityScores(
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    );
  }

  AbilityScores copyWith({
    int? strength,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
  }) {
    return AbilityScores(
      strength: strength ?? this.strength,
      dexterity: dexterity ?? this.dexterity,
      constitution: constitution ?? this.constitution,
      intelligence: intelligence ?? this.intelligence,
      wisdom: wisdom ?? this.wisdom,
      charisma: charisma ?? this.charisma,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strength': strength,
      'dexterity': dexterity,
      'constitution': constitution,
      'intelligence': intelligence,
      'wisdom': wisdom,
      'charisma': charisma,
    };
  }

  factory AbilityScores.fromJson(Map<String, dynamic> json) {
    return AbilityScores(
      strength: json['strength'] as int,
      dexterity: json['dexterity'] as int,
      constitution: json['constitution'] as int,
      intelligence: json['intelligence'] as int,
      wisdom: json['wisdom'] as int,
      charisma: json['charisma'] as int,
    );
  }

  @override
  List<Object?> get props => [strength, dexterity, constitution, intelligence, wisdom, charisma];
}


