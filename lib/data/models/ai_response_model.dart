import 'package:equatable/equatable.dart';
import '../../core/constants/game_constants.dart';

/// Represents the AI's response to a player action
/// This is the structured output from the AI story engine
class AIResponseModel extends Equatable {
  final String narration;
  final ProposedCheck? proposedCheck;
  final String? successOutcome;
  final String? failureOutcome;
  final List<ProposedReward>? proposedRewards;
  final SceneChange? sceneChange;
  final List<NPCDialogue>? npcDialogues;
  final CombatProposal? combatProposal;
  final CombatTrigger? combatTrigger;
  final List<String>? suggestedActions;
  final String? ambientDescription;
  final bool requiresPlayerChoice;
  final List<PlayerChoice>? playerChoices;

  const AIResponseModel({
    required this.narration,
    this.proposedCheck,
    this.successOutcome,
    this.failureOutcome,
    this.proposedRewards,
    this.sceneChange,
    this.npcDialogues,
    this.combatProposal,
    this.combatTrigger,
    this.suggestedActions,
    this.ambientDescription,
    this.requiresPlayerChoice = false,
    this.playerChoices,
  });
  
  /// Check if this response triggers combat
  bool get triggersCombat => combatTrigger != null && combatTrigger!.enemies.isNotEmpty;

  factory AIResponseModel.fromJson(Map<String, dynamic> json) {
    return AIResponseModel(
      narration: json['narration'] as String,
      proposedCheck: json['proposedCheck'] != null
          ? ProposedCheck.fromJson(json['proposedCheck'] as Map<String, dynamic>)
          : null,
      successOutcome: json['successOutcome'] as String?,
      failureOutcome: json['failureOutcome'] as String?,
      proposedRewards: (json['proposedRewards'] as List<dynamic>?)
          ?.map((r) => ProposedReward.fromJson(r as Map<String, dynamic>))
          .toList(),
      sceneChange: json['sceneChange'] != null
          ? SceneChange.fromJson(json['sceneChange'] as Map<String, dynamic>)
          : null,
      npcDialogues: (json['npcDialogues'] as List<dynamic>?)
          ?.map((d) => NPCDialogue.fromJson(d as Map<String, dynamic>))
          .toList(),
      combatProposal: json['combatProposal'] != null
          ? CombatProposal.fromJson(json['combatProposal'] as Map<String, dynamic>)
          : null,
      combatTrigger: json['combatTrigger'] != null
          ? CombatTrigger.fromJson(json['combatTrigger'] as Map<String, dynamic>)
          : null,
      suggestedActions: (json['suggestedActions'] as List<dynamic>?)?.cast<String>(),
      ambientDescription: json['ambientDescription'] as String?,
      requiresPlayerChoice: json['requiresPlayerChoice'] as bool? ?? false,
      playerChoices: (json['playerChoices'] as List<dynamic>?)
          ?.map((c) => PlayerChoice.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'narration': narration,
      'proposedCheck': proposedCheck?.toJson(),
      'successOutcome': successOutcome,
      'failureOutcome': failureOutcome,
      'proposedRewards': proposedRewards?.map((r) => r.toJson()).toList(),
      'sceneChange': sceneChange?.toJson(),
      'npcDialogues': npcDialogues?.map((d) => d.toJson()).toList(),
      'combatProposal': combatProposal?.toJson(),
      'combatTrigger': combatTrigger?.toJson(),
      'suggestedActions': suggestedActions,
      'ambientDescription': ambientDescription,
      'requiresPlayerChoice': requiresPlayerChoice,
      'playerChoices': playerChoices?.map((c) => c.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
    narration, proposedCheck, successOutcome, failureOutcome,
    proposedRewards, sceneChange, npcDialogues, combatProposal,
    combatTrigger, suggestedActions, ambientDescription, requiresPlayerChoice, playerChoices,
  ];
}

/// Combat trigger from AI - indicates combat should start
class CombatTrigger extends Equatable {
  final List<EnemyInfo> enemies;
  final bool isAmbush;
  final String? reason;
  
  const CombatTrigger({
    required this.enemies,
    this.isAmbush = false,
    this.reason,
  });
  
  factory CombatTrigger.fromJson(Map<String, dynamic> json) {
    return CombatTrigger(
      enemies: (json['enemies'] as List<dynamic>?)
          ?.map((e) => EnemyInfo.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      isAmbush: json['ambush'] as bool? ?? json['isAmbush'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'enemies': enemies.map((e) => e.toJson()).toList(),
    'isAmbush': isAmbush,
    'reason': reason,
  };
  
  @override
  List<Object?> get props => [enemies, isAmbush, reason];
}

/// Enemy info from AI combat trigger
class EnemyInfo extends Equatable {
  final String name;
  final String? type;
  final double challengeRating;
  final int count;
  
  const EnemyInfo({
    required this.name,
    this.type,
    this.challengeRating = 0.25,
    this.count = 1,
  });
  
  factory EnemyInfo.fromJson(Map<String, dynamic> json) {
    return EnemyInfo(
      name: json['name'] as String? ?? 'Unknown Enemy',
      type: json['type'] as String?,
      challengeRating: (json['cr'] as num?)?.toDouble() ?? 
          (json['challengeRating'] as num?)?.toDouble() ?? 0.25,
      count: json['count'] as int? ?? 1,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'cr': challengeRating,
    'count': count,
  };
  
  @override
  List<Object?> get props => [name, type, challengeRating, count];
}

/// Proposed skill check from AI
class ProposedCheck extends Equatable {
  final CheckType checkType;
  final Ability? ability;
  final Skill? skill;
  final int difficultyClass;
  final String? description;
  final bool canUseAdvantage;
  final bool hasDisadvantage;

  const ProposedCheck({
    required this.checkType,
    this.ability,
    this.skill,
    required this.difficultyClass,
    this.description,
    this.canUseAdvantage = false,
    this.hasDisadvantage = false,
  });

  factory ProposedCheck.fromJson(Map<String, dynamic> json) {
    return ProposedCheck(
      checkType: CheckType.values.firstWhere(
        (t) => t.name == json['checkType'],
        orElse: () => CheckType.ability,
      ),
      ability: json['ability'] != null
          ? Ability.values.firstWhere((a) => a.abbreviation == json['ability'] || a.name == json['ability'])
          : null,
      skill: json['skill'] != null
          ? Skill.values.firstWhere((s) => s.displayName == json['skill'] || s.name == json['skill'])
          : null,
      difficultyClass: json['dc'] as int? ?? json['difficultyClass'] as int,
      description: json['description'] as String?,
      canUseAdvantage: json['canUseAdvantage'] as bool? ?? false,
      hasDisadvantage: json['hasDisadvantage'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkType': checkType.name,
      'ability': ability?.abbreviation,
      'skill': skill?.displayName,
      'difficultyClass': difficultyClass,
      'description': description,
      'canUseAdvantage': canUseAdvantage,
      'hasDisadvantage': hasDisadvantage,
    };
  }

  @override
  List<Object?> get props => [
    checkType, ability, skill, difficultyClass, description,
    canUseAdvantage, hasDisadvantage,
  ];
}

/// Types of checks
enum CheckType {
  ability('Ability Check'),
  skill('Skill Check'),
  savingThrow('Saving Throw'),
  attack('Attack Roll'),
  contest('Contest');

  final String displayName;
  const CheckType(this.displayName);
}

/// Proposed reward from AI (to be validated by game engine)
class ProposedReward extends Equatable {
  final RewardType type;
  final String? itemName;
  final int? quantity;
  final int? goldAmount;
  final int? experiencePoints;
  final String? description;

  const ProposedReward({
    required this.type,
    this.itemName,
    this.quantity,
    this.goldAmount,
    this.experiencePoints,
    this.description,
  });

  factory ProposedReward.fromJson(Map<String, dynamic> json) {
    return ProposedReward(
      type: RewardType.values.firstWhere((t) => t.name == json['type']),
      itemName: json['itemName'] as String?,
      quantity: json['quantity'] as int?,
      goldAmount: json['goldAmount'] as int?,
      experiencePoints: json['experiencePoints'] as int?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'itemName': itemName,
      'quantity': quantity,
      'goldAmount': goldAmount,
      'experiencePoints': experiencePoints,
      'description': description,
    };
  }

  @override
  List<Object?> get props => [type, itemName, quantity, goldAmount, experiencePoints, description];
}

/// Reward types
enum RewardType {
  item('Item'),
  gold('Gold'),
  experience('Experience'),
  reputation('Reputation');

  final String displayName;
  const RewardType(this.displayName);
}

/// Scene change proposed by AI
class SceneChange extends Equatable {
  final String newSceneName;
  final String newSceneDescription;
  final String? transitionDescription;

  const SceneChange({
    required this.newSceneName,
    required this.newSceneDescription,
    this.transitionDescription,
  });

  factory SceneChange.fromJson(Map<String, dynamic> json) {
    return SceneChange(
      newSceneName: json['newSceneName'] as String,
      newSceneDescription: json['newSceneDescription'] as String,
      transitionDescription: json['transitionDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'newSceneName': newSceneName,
      'newSceneDescription': newSceneDescription,
      'transitionDescription': transitionDescription,
    };
  }

  @override
  List<Object?> get props => [newSceneName, newSceneDescription, transitionDescription];
}

/// NPC dialogue from AI
class NPCDialogue extends Equatable {
  final String npcName;
  final String dialogue;
  final String? emotion;
  final String? action;

  const NPCDialogue({
    required this.npcName,
    required this.dialogue,
    this.emotion,
    this.action,
  });

  factory NPCDialogue.fromJson(Map<String, dynamic> json) {
    return NPCDialogue(
      npcName: json['npcName'] as String,
      dialogue: json['dialogue'] as String,
      emotion: json['emotion'] as String?,
      action: json['action'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'npcName': npcName,
      'dialogue': dialogue,
      'emotion': emotion,
      'action': action,
    };
  }

  @override
  List<Object?> get props => [npcName, dialogue, emotion, action];
}

/// Combat proposal from AI
class CombatProposal extends Equatable {
  final String monsterName;
  final String? monsterDescription;
  final String attackDescription;
  final Ability? attackAbility;
  final int? suggestedDC;
  final String? damageDescription;

  const CombatProposal({
    required this.monsterName,
    this.monsterDescription,
    required this.attackDescription,
    this.attackAbility,
    this.suggestedDC,
    this.damageDescription,
  });

  factory CombatProposal.fromJson(Map<String, dynamic> json) {
    return CombatProposal(
      monsterName: json['monsterName'] as String,
      monsterDescription: json['monsterDescription'] as String?,
      attackDescription: json['attackDescription'] as String,
      attackAbility: json['attackAbility'] != null
          ? Ability.values.firstWhere((a) => a.abbreviation == json['attackAbility'])
          : null,
      suggestedDC: json['suggestedDC'] as int?,
      damageDescription: json['damageDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monsterName': monsterName,
      'monsterDescription': monsterDescription,
      'attackDescription': attackDescription,
      'attackAbility': attackAbility?.abbreviation,
      'suggestedDC': suggestedDC,
      'damageDescription': damageDescription,
    };
  }

  @override
  List<Object?> get props => [
    monsterName, monsterDescription, attackDescription,
    attackAbility, suggestedDC, damageDescription,
  ];
}

/// Player choice option
class PlayerChoice extends Equatable {
  final String id;
  final String text;
  final String? consequence;
  final bool isAvailable;
  final String? requirementDescription;

  const PlayerChoice({
    required this.id,
    required this.text,
    this.consequence,
    this.isAvailable = true,
    this.requirementDescription,
  });

  factory PlayerChoice.fromJson(Map<String, dynamic> json) {
    return PlayerChoice(
      id: json['id'] as String,
      text: json['text'] as String,
      consequence: json['consequence'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      requirementDescription: json['requirementDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'consequence': consequence,
      'isAvailable': isAvailable,
      'requirementDescription': requirementDescription,
    };
  }

  @override
  List<Object?> get props => [id, text, consequence, isAvailable, requirementDescription];
}


