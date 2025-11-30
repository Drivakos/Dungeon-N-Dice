import 'package:uuid/uuid.dart';

import '../../core/constants/game_constants.dart';
import '../../data/models/character_model.dart';
import '../../data/models/monster_model.dart';
import '../../data/models/item_model.dart';
import '../../data/models/quest_model.dart';
import '../../data/models/game_state_model.dart';
import '../../data/models/story_message_model.dart';
import '../../data/models/ai_response_model.dart';
import '../../data/services/game_action_service.dart';
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
  
  /// Process game actions from AI response
  /// 
  /// Validates and executes a list of game actions (inventory, gold, HP, etc.)
  /// Returns the updated game state and any messages to display
  GameActionsResult processGameActions({
    required GameStateModel gameState,
    required List<GameAction> actions,
  }) {
    final messages = <StoryMessageModel>[];
    var state = gameState;
    
    for (final action in actions) {
      // Validate the action first
      final validation = GameActionValidator.validate(action, state);
      if (!validation.isValid) {
        // Log validation failure but continue with other actions
        messages.add(StoryMessageModel(
          id: _uuid.v4(),
          type: MessageType.system,
          content: 'Action failed: ${validation.error}',
          timestamp: DateTime.now(),
        ));
        continue;
      }
      
      // Execute the action
      final result = _executeGameAction(state, action);
      state = result.state;
      if (result.message != null) {
        messages.add(result.message!);
      }
    }
    
    return GameActionsResult(
      updatedState: state,
      messages: messages,
    );
  }
  
  /// Execute a single game action
  _ActionExecutionResult _executeGameAction(GameStateModel state, GameAction action) {
    switch (action.type) {
      case GameActionType.addItem:
        return _executeAddItem(state, action);
      case GameActionType.removeItem:
        return _executeRemoveItem(state, action);
      case GameActionType.useItem:
        return _executeUseItem(state, action);
      case GameActionType.heal:
        return _executeHeal(state, action);
      case GameActionType.damage:
        return _executeDamage(state, action);
      case GameActionType.addGold:
        return _executeAddGold(state, action);
      case GameActionType.spendGold:
        return _executeSpendGold(state, action);
      case GameActionType.addXP:
        return _executeAddXP(state, action);
      case GameActionType.changeLocation:
        return _executeChangeLocation(state, action);
      case GameActionType.equipItem:
        return _executeEquipItem(state, action);
      case GameActionType.unequipItem:
        return _executeUnequipItem(state, action);
      case GameActionType.updateQuest:
        return _executeUpdateQuest(state, action);
      case GameActionType.rest:
        return _executeRest(state, action);
      default:
        return _ActionExecutionResult(state: state);
    }
  }
  
  _ActionExecutionResult _executeAddItem(GameStateModel state, GameAction action) {
    final itemName = action.params['itemName'] as String? ?? 'Unknown Item';
    final quantity = action.params['quantity'] as int? ?? 1;
    final rarityStr = action.params['rarity'] as String?;
    final description = action.params['description'] as String?;
    
    // Determine rarity
    ItemRarity rarity = ItemRarity.common;
    if (rarityStr != null) {
      rarity = ItemRarity.values.firstWhere(
        (r) => r.name == rarityStr,
        orElse: () => ItemRarity.common,
      );
    }
    
    // Create item(s)
    var updatedState = state;
    final addedItems = <String>[];
    
    for (var i = 0; i < quantity; i++) {
      if (updatedState.inventory.isFull) break;
      
      final item = ItemModel(
        id: _uuid.v4(),
        name: itemName,
        description: description ?? 'A $itemName',
        type: _inferItemType(itemName),
        rarity: rarity,
        weight: 1.0,
        value: _estimateItemValue(rarity),
      );
      
      updatedState = addItemToInventory(gameState: updatedState, item: item);
      addedItems.add(itemName);
    }
    
    final message = addedItems.isNotEmpty
        ? StoryMessageModel(
            id: _uuid.v4(),
            type: MessageType.itemReceived,
            content: quantity > 1 
                ? 'Added $quantity x $itemName to inventory'
                : 'Added $itemName to inventory',
            timestamp: DateTime.now(),
            itemsReceived: addedItems,
          )
        : StoryMessageModel(
            id: _uuid.v4(),
            type: MessageType.system,
            content: 'Inventory full - could not add $itemName',
            timestamp: DateTime.now(),
          );
    
    return _ActionExecutionResult(state: updatedState, message: message);
  }
  
  _ActionExecutionResult _executeRemoveItem(GameStateModel state, GameAction action) {
    final itemName = action.params['itemName'] as String?;
    if (itemName == null) {
      return _ActionExecutionResult(state: state);
    }
    
    final quantity = action.params['quantity'] as int? ?? 1;
    var updatedState = state;
    var removed = 0;
    
    for (var i = 0; i < quantity; i++) {
      final item = updatedState.inventory.items.firstWhere(
      (i) => i.name.toLowerCase() == itemName.toLowerCase(),
      orElse: () => ItemModel(
        id: '',
        name: '',
        description: '',
        type: ItemType.misc,
        rarity: ItemRarity.common,
        weight: 0,
        value: 0,
      ),
    );
    
    if (item.id.isNotEmpty) {
      updatedState = removeItemFromInventory(gameState: updatedState, itemId: item.id);
        removed++;
      }
    }
    
    final message = removed > 0
        ? StoryMessageModel(
            id: _uuid.v4(),
            type: MessageType.system,
            content: removed > 1 
                ? 'Removed $removed x $itemName from inventory'
                : 'Removed $itemName from inventory',
            timestamp: DateTime.now(),
          )
        : null;
    
    return _ActionExecutionResult(state: updatedState, message: message);
  }
  
  _ActionExecutionResult _executeUseItem(GameStateModel state, GameAction action) {
    final itemName = action.params['itemName'] as String?;
    if (itemName == null) {
      return _ActionExecutionResult(state: state);
    }
    
    // Find the item
    final item = state.inventory.items.firstWhere(
      (i) => i.name.toLowerCase() == itemName.toLowerCase(),
      orElse: () => ItemModel(
        id: '',
        name: '',
        description: '',
        type: ItemType.misc,
        rarity: ItemRarity.common,
        weight: 0,
        value: 0,
      ),
    );
    
    if (item.id.isEmpty) {
      return _ActionExecutionResult(
        state: state,
        message: StoryMessageModel(
          id: _uuid.v4(),
          type: MessageType.system,
          content: 'Could not find $itemName in inventory',
          timestamp: DateTime.now(),
        ),
      );
    }
    
    // Remove consumable items after use
    var updatedState = state;
    if (item.type == ItemType.consumable || item.type == ItemType.potion) {
      updatedState = removeItemFromInventory(gameState: updatedState, itemId: item.id);
    }
    
    return _ActionExecutionResult(
      state: updatedState,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.system,
        content: 'Used $itemName',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  _ActionExecutionResult _executeHeal(GameStateModel state, GameAction action) {
    final amountStr = action.params['amount']?.toString() ?? '1d8';
    final source = action.params['source'] as String?;
    
    // Parse healing amount (could be dice notation or flat number)
    int healAmount;
    String rollDescription = '';
    
    if (amountStr.contains('d')) {
      // Dice notation like "2d4+2"
      try {
        final roll = diceRoller.rollNotation(amountStr);
        healAmount = roll.total;
        rollDescription = ' (rolled $healAmount)';
      } catch (_) {
        healAmount = 0;
      }
    } else {
      healAmount = int.tryParse(amountStr) ?? 0;
    }
    
    final newHP = (state.character.currentHitPoints + healAmount)
        .clamp(0, state.character.maxHitPoints);
    final actualHealed = newHP - state.character.currentHitPoints;
    
    final updatedState = state.copyWith(
      character: state.character.copyWith(
        currentHitPoints: newHP,
        updatedAt: DateTime.now(),
      ),
    );
    
    final sourceText = source != null ? ' from $source' : '';
    
    return _ActionExecutionResult(
      state: updatedState,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.system,
        content: 'Healed $actualHealed HP$rollDescription$sourceText',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  _ActionExecutionResult _executeDamage(GameStateModel state, GameAction action) {
    final amount = action.params['amount'] as int? ?? 0;
    final damageTypeStr = action.params['damageType'] as String?;
    final source = action.params['source'] as String?;
    
    final damageType = damageTypeStr != null
        ? DamageType.values.firstWhere(
            (t) => t.name == damageTypeStr,
            orElse: () => DamageType.bludgeoning,
          )
        : DamageType.bludgeoning;
    
    final updatedState = applyDamageToPlayer(
      gameState: state,
      damage: amount,
      damageType: damageType,
    );
    
    final sourceText = source != null ? ' from $source' : '';
    
    return _ActionExecutionResult(
      state: updatedState,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.combat,
        content: 'Took $amount ${damageType.displayName} damage$sourceText',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  _ActionExecutionResult _executeAddGold(GameStateModel state, GameAction action) {
    final amount = action.params['amount'] as int? ?? 0;
    final source = action.params['source'] as String?;
    
    // Validate against maximum
    final maxGold = _getMaxRewardGold(state.character.level);
    final validatedAmount = amount.clamp(0, maxGold);
    
    final updatedState = state.copyWith(gold: state.gold + validatedAmount);
    final sourceText = source != null ? ' $source' : '';
    
    return _ActionExecutionResult(
      state: updatedState,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.system,
        content: 'Gained $validatedAmount gold$sourceText',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  _ActionExecutionResult _executeSpendGold(GameStateModel state, GameAction action) {
    final amount = action.params['amount'] as int? ?? 0;
    final reason = action.params['reason'] as String?;
    
    if (amount > state.gold) {
      return _ActionExecutionResult(
        state: state,
        message: StoryMessageModel(
          id: _uuid.v4(),
          type: MessageType.system,
          content: 'Not enough gold (need $amount, have ${state.gold})',
          timestamp: DateTime.now(),
        ),
      );
    }
    
    final updatedState = state.copyWith(gold: state.gold - amount);
    final reasonText = reason != null ? ' for $reason' : '';
    
    return _ActionExecutionResult(
      state: updatedState,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.system,
        content: 'Spent $amount gold$reasonText',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  _ActionExecutionResult _executeAddXP(GameStateModel state, GameAction action) {
    final amount = action.params['amount'] as int? ?? 0;
    final reason = action.params['reason'] as String?;
    
    // Validate against maximum
    final maxXP = _getMaxRewardXP(state.character.level);
    final validatedAmount = amount.clamp(0, maxXP);
    
    final levelUpResult = combatEngine.checkLevelUp(
      state.character,
      validatedAmount,
    );
    
    var updatedState = state.copyWith(
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
    
    final reasonText = reason != null ? ' ($reason)' : '';
    final messages = <StoryMessageModel>[];
    
    messages.add(StoryMessageModel(
      id: _uuid.v4(),
      type: MessageType.system,
      content: 'Gained $validatedAmount XP$reasonText',
      timestamp: DateTime.now(),
      experienceGained: validatedAmount,
    ));
    
    if (levelUpResult.didLevelUp) {
      messages.add(StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.levelUp,
        content: 'Level Up! You are now level ${levelUpResult.newLevel}! (+${levelUpResult.hpIncrease} HP)',
        timestamp: DateTime.now(),
        isImportant: true,
      ));
    }
    
    return _ActionExecutionResult(
      state: updatedState,
      message: messages.first,
      // Note: Level up message will need to be handled separately if multiple messages are needed
    );
  }
  
  _ActionExecutionResult _executeChangeLocation(GameStateModel state, GameAction action) {
    final locationName = action.params['locationName'] as String? ?? 'Unknown Location';
    final description = action.params['description'] as String? ?? '';
    final sceneTypeStr = action.params['sceneType'] as String?;
    
    final sceneType = sceneTypeStr != null
        ? SceneType.values.firstWhere(
            (t) => t.name == sceneTypeStr,
            orElse: () => SceneType.exploration,
          )
        : SceneType.exploration;
    
    final newScene = SceneModel(
      id: _uuid.v4(),
      name: locationName,
      description: description,
      type: sceneType,
    );
    
    final updatedState = state.copyWith(currentScene: newScene);
    
    return _ActionExecutionResult(
      state: updatedState,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.system,
        content: 'Arrived at $locationName',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  _ActionExecutionResult _executeEquipItem(GameStateModel state, GameAction action) {
    final itemName = action.params['itemName'] as String?;
    if (itemName == null) {
      return _ActionExecutionResult(state: state);
    }
    
    // Find the item in inventory
    final item = state.inventory.items.firstWhere(
      (i) => i.name.toLowerCase() == itemName.toLowerCase(),
      orElse: () => ItemModel(
        id: '',
        name: '',
        description: '',
        type: ItemType.misc,
        rarity: ItemRarity.common,
        weight: 0,
        value: 0,
      ),
    );
    
    if (item.id.isEmpty || !item.isEquippable) {
      return _ActionExecutionResult(state: state);
    }
    
    // Note: ItemModel doesn't track equipped state, so we just acknowledge the action
    // In a full implementation, you would add an 'isEquipped' field to ItemModel
    
    return _ActionExecutionResult(
      state: state,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.system,
        content: 'Equipped $itemName',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  _ActionExecutionResult _executeUnequipItem(GameStateModel state, GameAction action) {
    final itemName = action.params['itemName'] as String?;
    if (itemName == null) {
      return _ActionExecutionResult(state: state);
    }
    
    // Find the item in inventory
    final item = state.inventory.items.firstWhere(
      (i) => i.name.toLowerCase() == itemName.toLowerCase(),
      orElse: () => ItemModel(
        id: '',
        name: '',
        description: '',
        type: ItemType.misc,
        rarity: ItemRarity.common,
        weight: 0,
        value: 0,
      ),
    );
    
    if (item.id.isEmpty) {
      return _ActionExecutionResult(state: state);
    }
    
    // Note: ItemModel doesn't track equipped state, so we just acknowledge the action
    
    return _ActionExecutionResult(
      state: state,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.system,
        content: 'Unequipped $itemName',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  _ActionExecutionResult _executeUpdateQuest(GameStateModel state, GameAction action) {
    final questId = action.params['questId'] as String?;
    final objectiveId = action.params['objectiveId'] as String?;
    final progress = action.params['progress'] as int? ?? 1;
    
    if (questId == null || objectiveId == null) {
      return _ActionExecutionResult(state: state);
    }
    
    final updatedState = updateQuestProgress(
      gameState: state,
      questId: questId,
      objectiveId: objectiveId,
      progressDelta: progress,
    );
    
    return _ActionExecutionResult(
      state: updatedState,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.questUpdate,
        content: 'Quest progress updated',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  _ActionExecutionResult _executeRest(GameStateModel state, GameAction action) {
    final restTypeStr = action.params['restType'] as String? ?? 'short';
    final isLongRest = restTypeStr == 'long';
    
    var updatedCharacter = state.character;
    
    if (isLongRest) {
      // Long rest: restore all HP
      updatedCharacter = updatedCharacter.copyWith(
        currentHitPoints: updatedCharacter.maxHitPoints,
        hitDiceRemaining: updatedCharacter.level,
        updatedAt: DateTime.now(),
      );
    } else {
      // Short rest: can spend hit dice (simplified - just restore some HP)
      final hitDiceToSpend = (updatedCharacter.hitDiceRemaining / 2).ceil().clamp(1, updatedCharacter.hitDiceRemaining);
      if (hitDiceToSpend > 0) {
        final hitDie = _getHitDie(updatedCharacter.characterClass);
        final roll = diceRoller.rollDice(hitDiceToSpend, hitDie);
        final conMod = updatedCharacter.getAbilityModifier(Ability.constitution) * hitDiceToSpend;
        final healed = roll.total + conMod;
        
        final newHP = (updatedCharacter.currentHitPoints + healed)
            .clamp(0, updatedCharacter.maxHitPoints);
        
        updatedCharacter = updatedCharacter.copyWith(
          currentHitPoints: newHP,
          hitDiceRemaining: updatedCharacter.hitDiceRemaining - hitDiceToSpend,
          updatedAt: DateTime.now(),
        );
      }
    }
    
    final updatedState = state.copyWith(character: updatedCharacter);
    final restType = isLongRest ? 'long rest' : 'short rest';
    
    return _ActionExecutionResult(
      state: updatedState,
      message: StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.system,
        content: 'Completed a $restType. HP: ${updatedCharacter.currentHitPoints}/${updatedCharacter.maxHitPoints}',
        timestamp: DateTime.now(),
      ),
    );
  }
  
  /// Infer item type from name
  ItemType _inferItemType(String name) {
    final lowerName = name.toLowerCase();
    
    if (lowerName.contains('potion') || lowerName.contains('elixir')) {
      return ItemType.potion;
    }
    if (lowerName.contains('scroll')) {
      return ItemType.scroll;
    }
    if (lowerName.contains('sword') || lowerName.contains('axe') || 
        lowerName.contains('mace') || lowerName.contains('dagger') ||
        lowerName.contains('bow') || lowerName.contains('staff')) {
      return ItemType.weapon;
    }
    if (lowerName.contains('armor') || lowerName.contains('shield') ||
        lowerName.contains('helm') || lowerName.contains('boots')) {
      return ItemType.armor;
    }
    if (lowerName.contains('ring')) {
      return ItemType.ring;
    }
    if (lowerName.contains('amulet') || lowerName.contains('necklace')) {
      return ItemType.amulet;
    }
    if (lowerName.contains('key') || lowerName.contains('torch') ||
        lowerName.contains('rope') || lowerName.contains('tool')) {
      return ItemType.tool;
    }
    
    return ItemType.misc;
  }
  
  /// Estimate item value based on rarity
  int _estimateItemValue(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common:
        return 10;
      case ItemRarity.uncommon:
        return 50;
      case ItemRarity.rare:
        return 200;
      case ItemRarity.veryRare:
        return 1000;
      case ItemRarity.legendary:
        return 5000;
      case ItemRarity.artifact:
        return 25000;
    }
  }
  
  /// Get hit die for a character class
  int _getHitDie(CharacterClass charClass) {
    switch (charClass) {
      case CharacterClass.barbarian:
        return 12;
      case CharacterClass.fighter:
      case CharacterClass.paladin:
      case CharacterClass.ranger:
        return 10;
      case CharacterClass.bard:
      case CharacterClass.cleric:
      case CharacterClass.druid:
      case CharacterClass.monk:
      case CharacterClass.rogue:
      case CharacterClass.warlock:
        return 8;
      case CharacterClass.sorcerer:
      case CharacterClass.wizard:
        return 6;
    }
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

/// Result of processing game actions
class GameActionsResult {
  final GameStateModel updatedState;
  final List<StoryMessageModel> messages;
  
  const GameActionsResult({
    required this.updatedState,
    required this.messages,
  });
}

/// Internal result of executing a single action
class _ActionExecutionResult {
  final GameStateModel state;
  final StoryMessageModel? message;
  
  const _ActionExecutionResult({
    required this.state,
    this.message,
  });
}
