import 'package:uuid/uuid.dart';

import '../../core/constants/game_constants.dart';
import '../../data/models/character_model.dart';
import '../../data/models/monster_model.dart';
import '../../data/models/item_model.dart';
import '../../data/models/quest_model.dart';
import '../../data/models/game_state_model.dart';
import '../../data/models/story_message_model.dart';
import '../../data/models/ai_response_model.dart';
import 'dice_roller.dart';
import 'combat_engine.dart';
import 'skill_check_engine.dart';

/// The Game Master orchestrates all game mechanics
/// It validates AI proposals and applies game rules
class GameMaster {
  final DiceRoller diceRoller;
  final CombatEngine combatEngine;
  final SkillCheckEngine skillCheckEngine;
  final Uuid _uuid;
  
  GameMaster({
    DiceRoller? diceRoller,
    CombatEngine? combatEngine,
    SkillCheckEngine? skillCheckEngine,
  }) : diceRoller = diceRoller ?? DiceRoller(),
       combatEngine = combatEngine ?? CombatEngine(),
       skillCheckEngine = skillCheckEngine ?? SkillCheckEngine(),
       _uuid = const Uuid();
  
  /// Process an AI response and apply validated game mechanics
  GameMasterResponse processAIResponse({
    required GameStateModel gameState,
    required AIResponseModel aiResponse,
    required String playerAction,
    bool skipPlayerMessage = false,
  }) {
    final messages = <StoryMessageModel>[];
    var updatedState = gameState;
    
    // Add player action to story log (skip if already added by caller)
    if (!skipPlayerMessage) {
      messages.add(StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.playerAction,
        content: playerAction,
        timestamp: DateTime.now(),
      ));
    }
    
    // Add AI narration
    messages.add(StoryMessageModel(
      id: _uuid.v4(),
      type: MessageType.narration,
      content: aiResponse.narration,
      timestamp: DateTime.now(),
    ));
    
    // Process NPC dialogues
    if (aiResponse.npcDialogues != null) {
      for (final dialogue in aiResponse.npcDialogues!) {
        messages.add(StoryMessageModel(
          id: _uuid.v4(),
          type: MessageType.dialogue,
          content: dialogue.dialogue,
          timestamp: DateTime.now(),
          speakerName: dialogue.npcName,
        ));
      }
    }
    
    // Process skill check if proposed
    SkillCheckOutcome? checkOutcome;
    if (aiResponse.proposedCheck != null) {
      checkOutcome = skillCheckEngine.performSkillCheck(
        character: gameState.character,
        proposal: aiResponse.proposedCheck!,
      );
      
      // Add skill check result message
      messages.add(StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.skillCheck,
        content: checkOutcome.isSuccess 
            ? aiResponse.successOutcome ?? 'You succeed!'
            : aiResponse.failureOutcome ?? 'You fail.',
        timestamp: DateTime.now(),
        skillCheckResult: skillCheckEngine.toStoryResult(checkOutcome),
      ));
    }
    
    // Process rewards if check succeeded (or no check required)
    if (aiResponse.proposedRewards != null && 
        (checkOutcome == null || checkOutcome.isSuccess)) {
      final rewardResult = _processRewards(
        gameState: updatedState,
        proposedRewards: aiResponse.proposedRewards!,
      );
      updatedState = rewardResult.updatedState;
      messages.addAll(rewardResult.messages);
    }
    
    // Process scene change
    if (aiResponse.sceneChange != null) {
      updatedState = _processSceneChange(
        gameState: updatedState,
        sceneChange: aiResponse.sceneChange!,
      );
    }
    
    // Update story log
    final updatedStoryLog = [...updatedState.storyLog, ...messages];
    updatedState = updatedState.copyWith(
      storyLog: updatedStoryLog,
      lastPlayedAt: DateTime.now(),
    );
    
    return GameMasterResponse(
      updatedState: updatedState,
      messages: messages,
      skillCheckOutcome: checkOutcome,
      requiresPlayerChoice: aiResponse.requiresPlayerChoice,
      playerChoices: aiResponse.playerChoices,
      suggestedActions: aiResponse.suggestedActions,
    );
  }
  
  /// Process and validate rewards
  _RewardProcessResult _processRewards({
    required GameStateModel gameState,
    required List<ProposedReward> proposedRewards,
  }) {
    final messages = <StoryMessageModel>[];
    var state = gameState;
    
    for (final reward in proposedRewards) {
      switch (reward.type) {
        case RewardType.experience:
          if (reward.experiencePoints != null) {
            // Validate XP (cap at reasonable amount based on level)
            final maxXP = _getMaxRewardXP(state.character.level);
            final validatedXP = reward.experiencePoints!.clamp(0, maxXP);
            
            if (validatedXP > 0) {
              final levelUpResult = combatEngine.checkLevelUp(
                state.character,
                validatedXP,
              );
              
              state = state.copyWith(
                character: state.character.copyWith(
                  experiencePoints: levelUpResult.newXP,
                  level: levelUpResult.newLevel,
                  maxHitPoints: levelUpResult.didLevelUp 
                      ? state.character.maxHitPoints + levelUpResult.hpIncrease
                      : null,
                  currentHitPoints: levelUpResult.didLevelUp
                      ? state.character.currentHitPoints + levelUpResult.hpIncrease
                      : null,
                  updatedAt: DateTime.now(),
                ),
              );
              
              messages.add(StoryMessageModel(
                id: _uuid.v4(),
                type: MessageType.system,
                content: 'Gained $validatedXP experience points!',
                timestamp: DateTime.now(),
                experienceGained: validatedXP,
              ));
              
              if (levelUpResult.didLevelUp) {
                messages.add(StoryMessageModel(
                  id: _uuid.v4(),
                  type: MessageType.levelUp,
                  content: 'Level Up! You are now level ${levelUpResult.newLevel}!',
                  timestamp: DateTime.now(),
                  isImportant: true,
                ));
              }
            }
          }
          break;
          
        case RewardType.gold:
          if (reward.goldAmount != null) {
            // Validate gold (cap at reasonable amount)
            final maxGold = _getMaxRewardGold(state.character.level);
            final validatedGold = reward.goldAmount!.clamp(0, maxGold);
            
            if (validatedGold > 0) {
              state = state.copyWith(gold: state.gold + validatedGold);
              
              messages.add(StoryMessageModel(
                id: _uuid.v4(),
                type: MessageType.system,
                content: 'Found $validatedGold gold!',
                timestamp: DateTime.now(),
              ));
            }
          }
          break;
          
        case RewardType.item:
          // Items need to be validated against item database
          // For now, just log the proposed item
          if (reward.itemName != null) {
            messages.add(StoryMessageModel(
              id: _uuid.v4(),
              type: MessageType.itemReceived,
              content: 'Found: ${reward.itemName}',
              timestamp: DateTime.now(),
              itemsReceived: [reward.itemName!],
            ));
          }
          break;
          
        case RewardType.reputation:
          // Handle reputation changes
          break;
      }
    }
    
    return _RewardProcessResult(
      updatedState: state,
      messages: messages,
    );
  }
  
  /// Process scene change
  GameStateModel _processSceneChange({
    required GameStateModel gameState,
    required SceneChange sceneChange,
  }) {
    final newScene = SceneModel(
      id: _uuid.v4(),
      name: sceneChange.newSceneName,
      description: sceneChange.newSceneDescription,
    );
    
    return gameState.copyWith(currentScene: newScene);
  }
  
  /// Get maximum XP reward based on level
  int _getMaxRewardXP(int level) {
    // Scale max XP with level
    return 100 + (level * 50);
  }
  
  /// Get maximum gold reward based on level
  int _getMaxRewardGold(int level) {
    // Scale max gold with level
    return 50 + (level * 25);
  }
  
  /// Start combat encounter
  CombatEncounter startCombat({
    required GameStateModel gameState,
    required List<MonsterModel> monsters,
  }) {
    final initiative = combatEngine.rollInitiative(
      gameState.character,
      monsters,
    );
    
    return CombatEncounter(
      id: _uuid.v4(),
      initiativeOrder: initiative,
      currentTurnIndex: 0,
      roundNumber: 1,
      monsters: monsters,
      isActive: true,
    );
  }
  
  /// Process player combat action
  CombatTurnResult processPlayerCombatAction({
    required GameStateModel gameState,
    required CombatEncounter encounter,
    required CombatAction action,
  }) {
    final messages = <StoryMessageModel>[];
    var updatedEncounter = encounter;
    var updatedState = gameState;
    
    switch (action.type) {
      case CombatActionType.meleeAttack:
      case CombatActionType.rangedAttack:
        if (action.targetMonsterId != null) {
          final targetIndex = encounter.monsters.indexWhere(
            (m) => m.id == action.targetMonsterId,
          );
          
          if (targetIndex != -1) {
            final target = encounter.monsters[targetIndex];
            final attackResult = combatEngine.playerAttack(
              player: gameState.character,
              target: target,
              attackBonus: action.attackBonus ?? gameState.character.proficiencyBonus,
              damageNotation: action.damageNotation ?? '1d8',
              damageType: action.damageType ?? DamageType.slashing,
              advantage: action.hasAdvantage,
              disadvantage: action.hasDisadvantage,
            );
            
            // Update monster HP
            final updatedMonsters = List<MonsterModel>.from(encounter.monsters);
            updatedMonsters[targetIndex] = target.copyWith(
              currentHitPoints: attackResult.targetNewHP,
            );
            
            updatedEncounter = CombatEncounter(
              id: encounter.id,
              initiativeOrder: encounter.initiativeOrder,
              currentTurnIndex: encounter.currentTurnIndex,
              roundNumber: encounter.roundNumber,
              monsters: updatedMonsters,
              isActive: !updatedMonsters.every((m) => !m.isAlive),
            );
            
            // Create combat message
            messages.add(StoryMessageModel(
              id: _uuid.v4(),
              type: MessageType.combat,
              content: _generateAttackNarration(
                attackerName: gameState.character.name,
                targetName: target.name,
                result: attackResult,
              ),
              timestamp: DateTime.now(),
              combatResult: CombatResult(
                attackerName: gameState.character.name,
                defenderName: target.name,
                actionType: action.type,
                attackRoll: attackResult.attackRoll.total,
                damageRoll: attackResult.damageRoll?.total,
                totalDamage: attackResult.finalDamage,
                damageType: attackResult.damageType,
                isHit: attackResult.isHit,
                isCriticalHit: attackResult.isCritical,
                isMiss: !attackResult.isHit,
                isCriticalMiss: attackResult.attackRoll.isCriticalMiss,
              ),
            ));
            
            // Check if monster died
            if (attackResult.targetKilled) {
              messages.add(StoryMessageModel(
                id: _uuid.v4(),
                type: MessageType.system,
                content: '${target.name} has been defeated!',
                timestamp: DateTime.now(),
                isImportant: true,
              ));
            }
          }
        }
        break;
        
      case CombatActionType.dodge:
        messages.add(StoryMessageModel(
          id: _uuid.v4(),
          type: MessageType.combat,
          content: '${gameState.character.name} takes the Dodge action.',
          timestamp: DateTime.now(),
        ));
        break;
        
      case CombatActionType.flee:
        // Attempt to flee combat
        final fleeCheck = skillCheckEngine.performAbilityCheck(
          character: gameState.character,
          ability: Ability.dexterity,
          difficultyClass: 10,
        );
        
        if (fleeCheck.isSuccess) {
          updatedEncounter = CombatEncounter(
            id: encounter.id,
            initiativeOrder: encounter.initiativeOrder,
            currentTurnIndex: encounter.currentTurnIndex,
            roundNumber: encounter.roundNumber,
            monsters: encounter.monsters,
            isActive: false,
          );
          
          messages.add(StoryMessageModel(
            id: _uuid.v4(),
            type: MessageType.combat,
            content: 'You successfully flee from combat!',
            timestamp: DateTime.now(),
          ));
        } else {
          messages.add(StoryMessageModel(
            id: _uuid.v4(),
            type: MessageType.combat,
            content: 'You failed to escape!',
            timestamp: DateTime.now(),
          ));
        }
        break;
        
      default:
        break;
    }
    
    return CombatTurnResult(
      updatedEncounter: updatedEncounter,
      updatedState: updatedState,
      messages: messages,
      combatEnded: !updatedEncounter.isActive,
      playerVictory: updatedEncounter.monsters.every((m) => !m.isAlive),
    );
  }
  
  /// Generate attack narration
  String _generateAttackNarration({
    required String attackerName,
    required String targetName,
    required PlayerAttackResult result,
  }) {
    if (result.attackRoll.isCriticalHit) {
      return '$attackerName lands a critical hit on $targetName for ${result.finalDamage} damage!';
    }
    if (result.attackRoll.isCriticalMiss) {
      return '$attackerName swings wildly and misses completely!';
    }
    if (result.isHit) {
      return '$attackerName hits $targetName for ${result.finalDamage} damage.';
    }
    return '$attackerName\'s attack misses $targetName.';
  }
  
  /// Apply damage to player
  GameStateModel applyDamageToPlayer({
    required GameStateModel gameState,
    required int damage,
    required DamageType damageType,
  }) {
    var newHP = gameState.character.currentHitPoints;
    var tempHP = gameState.character.temporaryHitPoints;
    
    // Apply to temp HP first
    if (tempHP > 0) {
      if (tempHP >= damage) {
        tempHP -= damage;
        damage = 0;
      } else {
        damage -= tempHP;
        tempHP = 0;
      }
    }
    
    newHP = (newHP - damage).clamp(0, gameState.character.maxHitPoints);
    
    return gameState.copyWith(
      character: gameState.character.copyWith(
        currentHitPoints: newHP,
        temporaryHitPoints: tempHP,
        updatedAt: DateTime.now(),
      ),
    );
  }
  
  /// Heal player
  GameStateModel healPlayer({
    required GameStateModel gameState,
    required String healingNotation,
  }) {
    final healResult = combatEngine.applyHealing(
      target: gameState.character,
      healingNotation: healingNotation,
    );
    
    return gameState.copyWith(
      character: gameState.character.copyWith(
        currentHitPoints: healResult.newHP,
        updatedAt: DateTime.now(),
      ),
    );
  }
  
  /// Add item to inventory
  GameStateModel addItemToInventory({
    required GameStateModel gameState,
    required ItemModel item,
  }) {
    if (gameState.inventory.isFull) {
      return gameState; // Inventory full
    }
    
    final updatedItems = [...gameState.inventory.items, item];
    
    return gameState.copyWith(
      inventory: gameState.inventory.copyWith(items: updatedItems),
    );
  }
  
  /// Remove item from inventory
  GameStateModel removeItemFromInventory({
    required GameStateModel gameState,
    required String itemId,
  }) {
    final updatedItems = gameState.inventory.items
        .where((i) => i.id != itemId)
        .toList();
    
    return gameState.copyWith(
      inventory: gameState.inventory.copyWith(items: updatedItems),
    );
  }
  
  /// Update quest progress
  GameStateModel updateQuestProgress({
    required GameStateModel gameState,
    required String questId,
    required String objectiveId,
    required int progressDelta,
  }) {
    final questIndex = gameState.quests.indexWhere((q) => q.id == questId);
    if (questIndex == -1) return gameState;
    
    final quest = gameState.quests[questIndex];
    final objectiveIndex = quest.objectives.indexWhere((o) => o.id == objectiveId);
    if (objectiveIndex == -1) return gameState;
    
    final objective = quest.objectives[objectiveIndex];
    final newProgress = (objective.currentProgress + progressDelta)
        .clamp(0, objective.targetProgress);
    
    final updatedObjectives = List<QuestObjective>.from(quest.objectives);
    updatedObjectives[objectiveIndex] = objective.copyWith(
      currentProgress: newProgress,
    );
    
    final updatedQuest = quest.copyWith(
      objectives: updatedObjectives,
      status: updatedObjectives.every((o) => o.isComplete)
          ? QuestStatus.completed
          : quest.status,
      completedAt: updatedObjectives.every((o) => o.isComplete)
          ? DateTime.now()
          : null,
    );
    
    final updatedQuests = List<QuestModel>.from(gameState.quests);
    updatedQuests[questIndex] = updatedQuest;
    
    return gameState.copyWith(quests: updatedQuests);
  }
}

/// Response from the Game Master after processing
class GameMasterResponse {
  final GameStateModel updatedState;
  final List<StoryMessageModel> messages;
  final SkillCheckOutcome? skillCheckOutcome;
  final bool requiresPlayerChoice;
  final List<PlayerChoice>? playerChoices;
  final List<String>? suggestedActions;
  
  const GameMasterResponse({
    required this.updatedState,
    required this.messages,
    this.skillCheckOutcome,
    this.requiresPlayerChoice = false,
    this.playerChoices,
    this.suggestedActions,
  });
}

/// Internal class for reward processing
class _RewardProcessResult {
  final GameStateModel updatedState;
  final List<StoryMessageModel> messages;
  
  const _RewardProcessResult({
    required this.updatedState,
    required this.messages,
  });
}

/// Combat encounter state
class CombatEncounter {
  final String id;
  final List<InitiativeEntry> initiativeOrder;
  final int currentTurnIndex;
  final int roundNumber;
  final List<MonsterModel> monsters;
  final bool isActive;
  
  const CombatEncounter({
    required this.id,
    required this.initiativeOrder,
    required this.currentTurnIndex,
    required this.roundNumber,
    required this.monsters,
    required this.isActive,
  });
  
  InitiativeEntry get currentTurn => initiativeOrder[currentTurnIndex];
  
  bool get isPlayerTurn => currentTurn.isPlayer;
  
  List<MonsterModel> get aliveMonsters => monsters.where((m) => m.isAlive).toList();
}

/// Combat action from player
class CombatAction {
  final CombatActionType type;
  final String? targetMonsterId;
  final int? attackBonus;
  final String? damageNotation;
  final DamageType? damageType;
  final bool hasAdvantage;
  final bool hasDisadvantage;
  
  const CombatAction({
    required this.type,
    this.targetMonsterId,
    this.attackBonus,
    this.damageNotation,
    this.damageType,
    this.hasAdvantage = false,
    this.hasDisadvantage = false,
  });
}

/// Result of a combat turn
class CombatTurnResult {
  final CombatEncounter updatedEncounter;
  final GameStateModel updatedState;
  final List<StoryMessageModel> messages;
  final bool combatEnded;
  final bool playerVictory;
  
  const CombatTurnResult({
    required this.updatedEncounter,
    required this.updatedState,
    required this.messages,
    required this.combatEnded,
    required this.playerVictory,
  });
}


