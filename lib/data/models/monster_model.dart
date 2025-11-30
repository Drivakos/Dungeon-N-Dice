import 'package:equatable/equatable.dart';
import '../../core/constants/game_constants.dart';
import 'character_model.dart';

/// Represents a monster/enemy in combat
class MonsterModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final MonsterType type;
  final String size;
  final String alignment;
  final int armorClass;
  final int currentHitPoints;
  final int maxHitPoints;
  final int speed;
  final AbilityScores abilityScores;
  final double challengeRating;
  final int experienceValue;
  final List<MonsterAction> actions;
  final List<String> resistances;
  final List<String> immunities;
  final List<String> vulnerabilities;
  final List<Condition> conditionImmunities;
  final Map<Skill, int> skillBonuses;
  final List<String> senses;
  final List<String> languages;
  final List<String> specialAbilities;
  final bool isHostile;
  final String? lairDescription;

  const MonsterModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.size = 'Medium',
    this.alignment = 'Unaligned',
    required this.armorClass,
    required this.currentHitPoints,
    required this.maxHitPoints,
    this.speed = GameConstants.defaultSpeed,
    required this.abilityScores,
    required this.challengeRating,
    required this.experienceValue,
    this.actions = const [],
    this.resistances = const [],
    this.immunities = const [],
    this.vulnerabilities = const [],
    this.conditionImmunities = const [],
    this.skillBonuses = const {},
    this.senses = const [],
    this.languages = const [],
    this.specialAbilities = const [],
    this.isHostile = true,
    this.lairDescription,
  });

  /// Check if monster is alive
  bool get isAlive => currentHitPoints > 0;

  /// Get proficiency bonus based on CR
  int get proficiencyBonus {
    if (challengeRating < 5) return 2;
    if (challengeRating < 9) return 3;
    if (challengeRating < 13) return 4;
    if (challengeRating < 17) return 5;
    if (challengeRating < 21) return 6;
    if (challengeRating < 25) return 7;
    if (challengeRating < 29) return 8;
    return 9;
  }

  /// Get ability modifier
  int getAbilityModifier(Ability ability) {
    return GameConstants.getModifier(abilityScores.getScore(ability));
  }

  /// Get initiative modifier
  int get initiativeModifier => getAbilityModifier(Ability.dexterity);

  MonsterModel copyWith({
    String? id,
    String? name,
    String? description,
    MonsterType? type,
    String? size,
    String? alignment,
    int? armorClass,
    int? currentHitPoints,
    int? maxHitPoints,
    int? speed,
    AbilityScores? abilityScores,
    double? challengeRating,
    int? experienceValue,
    List<MonsterAction>? actions,
    List<String>? resistances,
    List<String>? immunities,
    List<String>? vulnerabilities,
    List<Condition>? conditionImmunities,
    Map<Skill, int>? skillBonuses,
    List<String>? senses,
    List<String>? languages,
    List<String>? specialAbilities,
    bool? isHostile,
    String? lairDescription,
  }) {
    return MonsterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      size: size ?? this.size,
      alignment: alignment ?? this.alignment,
      armorClass: armorClass ?? this.armorClass,
      currentHitPoints: currentHitPoints ?? this.currentHitPoints,
      maxHitPoints: maxHitPoints ?? this.maxHitPoints,
      speed: speed ?? this.speed,
      abilityScores: abilityScores ?? this.abilityScores,
      challengeRating: challengeRating ?? this.challengeRating,
      experienceValue: experienceValue ?? this.experienceValue,
      actions: actions ?? this.actions,
      resistances: resistances ?? this.resistances,
      immunities: immunities ?? this.immunities,
      vulnerabilities: vulnerabilities ?? this.vulnerabilities,
      conditionImmunities: conditionImmunities ?? this.conditionImmunities,
      skillBonuses: skillBonuses ?? this.skillBonuses,
      senses: senses ?? this.senses,
      languages: languages ?? this.languages,
      specialAbilities: specialAbilities ?? this.specialAbilities,
      isHostile: isHostile ?? this.isHostile,
      lairDescription: lairDescription ?? this.lairDescription,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'size': size,
      'alignment': alignment,
      'armorClass': armorClass,
      'currentHitPoints': currentHitPoints,
      'maxHitPoints': maxHitPoints,
      'speed': speed,
      'abilityScores': abilityScores.toJson(),
      'challengeRating': challengeRating,
      'experienceValue': experienceValue,
      'actions': actions.map((a) => a.toJson()).toList(),
      'resistances': resistances,
      'immunities': immunities,
      'vulnerabilities': vulnerabilities,
      'conditionImmunities': conditionImmunities.map((c) => c.name).toList(),
      'skillBonuses': skillBonuses.map((k, v) => MapEntry(k.name, v)),
      'senses': senses,
      'languages': languages,
      'specialAbilities': specialAbilities,
      'isHostile': isHostile,
      'lairDescription': lairDescription,
    };
  }

  factory MonsterModel.fromJson(Map<String, dynamic> json) {
    return MonsterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: MonsterType.values.firstWhere((t) => t.name == json['type']),
      size: json['size'] as String? ?? 'Medium',
      alignment: json['alignment'] as String? ?? 'Unaligned',
      armorClass: json['armorClass'] as int,
      currentHitPoints: json['currentHitPoints'] as int,
      maxHitPoints: json['maxHitPoints'] as int,
      speed: json['speed'] as int? ?? GameConstants.defaultSpeed,
      abilityScores: AbilityScores.fromJson(json['abilityScores'] as Map<String, dynamic>),
      challengeRating: (json['challengeRating'] as num).toDouble(),
      experienceValue: json['experienceValue'] as int,
      actions: (json['actions'] as List<dynamic>?)
          ?.map((a) => MonsterAction.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
      resistances: (json['resistances'] as List<dynamic>?)?.cast<String>() ?? [],
      immunities: (json['immunities'] as List<dynamic>?)?.cast<String>() ?? [],
      vulnerabilities: (json['vulnerabilities'] as List<dynamic>?)?.cast<String>() ?? [],
      conditionImmunities: (json['conditionImmunities'] as List<dynamic>?)
          ?.map((c) => Condition.values.firstWhere((co) => co.name == c))
          .toList() ?? [],
      skillBonuses: (json['skillBonuses'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(Skill.values.firstWhere((s) => s.name == k), v as int),
      ) ?? {},
      senses: (json['senses'] as List<dynamic>?)?.cast<String>() ?? [],
      languages: (json['languages'] as List<dynamic>?)?.cast<String>() ?? [],
      specialAbilities: (json['specialAbilities'] as List<dynamic>?)?.cast<String>() ?? [],
      isHostile: json['isHostile'] as bool? ?? true,
      lairDescription: json['lairDescription'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id, name, description, type, size, alignment, armorClass,
    currentHitPoints, maxHitPoints, speed, abilityScores, challengeRating,
    experienceValue, actions, resistances, immunities, vulnerabilities,
    conditionImmunities, skillBonuses, senses, languages, specialAbilities,
    isHostile, lairDescription,
  ];
}

/// Monster types
enum MonsterType {
  aberration('Aberration'),
  beast('Beast'),
  celestial('Celestial'),
  construct('Construct'),
  dragon('Dragon'),
  elemental('Elemental'),
  fey('Fey'),
  fiend('Fiend'),
  giant('Giant'),
  humanoid('Humanoid'),
  monstrosity('Monstrosity'),
  ooze('Ooze'),
  plant('Plant'),
  undead('Undead');

  final String displayName;
  const MonsterType(this.displayName);
}

/// Represents a monster action (attack, ability, etc.)
class MonsterAction extends Equatable {
  final String name;
  final String description;
  final ActionType actionType;
  final int? attackBonus;
  final String? reach;
  final String? range;
  final String? damage;
  final DamageType? damageType;
  final int? saveDC;
  final Ability? saveAbility;
  final int? rechargeOn; // 5-6 means recharges on 5 or 6

  const MonsterAction({
    required this.name,
    required this.description,
    this.actionType = ActionType.action,
    this.attackBonus,
    this.reach,
    this.range,
    this.damage,
    this.damageType,
    this.saveDC,
    this.saveAbility,
    this.rechargeOn,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'actionType': actionType.name,
      'attackBonus': attackBonus,
      'reach': reach,
      'range': range,
      'damage': damage,
      'damageType': damageType?.name,
      'saveDC': saveDC,
      'saveAbility': saveAbility?.name,
      'rechargeOn': rechargeOn,
    };
  }

  factory MonsterAction.fromJson(Map<String, dynamic> json) {
    return MonsterAction(
      name: json['name'] as String,
      description: json['description'] as String,
      actionType: ActionType.values.firstWhere(
        (t) => t.name == json['actionType'],
        orElse: () => ActionType.action,
      ),
      attackBonus: json['attackBonus'] as int?,
      reach: json['reach'] as String?,
      range: json['range'] as String?,
      damage: json['damage'] as String?,
      damageType: json['damageType'] != null
          ? DamageType.values.firstWhere((d) => d.name == json['damageType'])
          : null,
      saveDC: json['saveDC'] as int?,
      saveAbility: json['saveAbility'] != null
          ? Ability.values.firstWhere((a) => a.name == json['saveAbility'])
          : null,
      rechargeOn: json['rechargeOn'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    name, description, actionType, attackBonus, reach, range,
    damage, damageType, saveDC, saveAbility, rechargeOn,
  ];
}

/// Action types for monster abilities
enum ActionType {
  action('Action'),
  bonusAction('Bonus Action'),
  reaction('Reaction'),
  legendaryAction('Legendary Action'),
  lairAction('Lair Action');

  final String displayName;
  const ActionType(this.displayName);
}


