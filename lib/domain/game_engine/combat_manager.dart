import 'package:uuid/uuid.dart';

import '../../core/constants/game_constants.dart';
import '../../data/models/character_model.dart';
import '../../data/models/monster_model.dart';
import '../../data/models/game_state_model.dart';
import '../../data/models/story_message_model.dart';
import 'combat_engine.dart';
import 'dice_roller.dart';

/// Combat state for tracking ongoing battles
class CombatState {
  final String id;
  final List<MonsterModel> enemies;
  final List<InitiativeEntry> initiativeOrder;
  final int currentTurnIndex;
  final int roundNumber;
  final bool isPlayerTurn;
  final bool isActive;
  final CombatPhase phase;
  final String? pendingAction;
  
  const CombatState({
    required this.id,
    required this.enemies,
    required this.initiativeOrder,
    this.currentTurnIndex = 0,
    this.roundNumber = 1,
    this.isPlayerTurn = true,
    this.isActive = true,
    this.phase = CombatPhase.playerTurn,
    this.pendingAction,
  });
  
  CombatState copyWith({
    String? id,
    List<MonsterModel>? enemies,
    List<InitiativeEntry>? initiativeOrder,
    int? currentTurnIndex,
    int? roundNumber,
    bool? isPlayerTurn,
    bool? isActive,
    CombatPhase? phase,
    String? pendingAction,
  }) {
    return CombatState(
      id: id ?? this.id,
      enemies: enemies ?? this.enemies,
      initiativeOrder: initiativeOrder ?? this.initiativeOrder,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      roundNumber: roundNumber ?? this.roundNumber,
      isPlayerTurn: isPlayerTurn ?? this.isPlayerTurn,
      isActive: isActive ?? this.isActive,
      phase: phase ?? this.phase,
      pendingAction: pendingAction,
    );
  }
  
  /// Get all living enemies
  List<MonsterModel> get aliveEnemies => enemies.where((e) => e.isAlive).toList();
  
  /// Check if combat is over
  bool get isCombatOver => aliveEnemies.isEmpty || !isActive;
  
  /// Get current turn entity
  InitiativeEntry? get currentTurn => 
      initiativeOrder.isNotEmpty ? initiativeOrder[currentTurnIndex] : null;
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'enemies': enemies.map((e) => e.toJson()).toList(),
    'currentTurnIndex': currentTurnIndex,
    'roundNumber': roundNumber,
    'isPlayerTurn': isPlayerTurn,
    'isActive': isActive,
    'phase': phase.name,
  };
  
  factory CombatState.fromJson(Map<String, dynamic> json) {
    return CombatState(
      id: json['id'] as String,
      enemies: (json['enemies'] as List)
          .map((e) => MonsterModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      initiativeOrder: [], // Re-roll on load
      currentTurnIndex: json['currentTurnIndex'] as int? ?? 0,
      roundNumber: json['roundNumber'] as int? ?? 1,
      isPlayerTurn: json['isPlayerTurn'] as bool? ?? true,
      isActive: json['isActive'] as bool? ?? true,
      phase: CombatPhase.values.firstWhere(
        (p) => p.name == json['phase'],
        orElse: () => CombatPhase.playerTurn,
      ),
    );
  }
}

/// Phases of combat
enum CombatPhase {
  initiative,
  playerTurn,
  enemyTurn,
  resolution,
  victory,
  defeat,
}

/// Combat manager for handling combat flow with AI integration
class CombatManager {
  final CombatEngine _combatEngine;
  final DiceRoller _diceRoller;
  final Uuid _uuid;
  
  CombatManager({
    CombatEngine? combatEngine,
    DiceRoller? diceRoller,
  }) : _combatEngine = combatEngine ?? CombatEngine(),
       _diceRoller = diceRoller ?? DiceRoller(),
       _uuid = const Uuid();
  
  /// Start a new combat encounter
  CombatStartResult startCombat({
    required CharacterModel player,
    required List<MonsterModel> enemies,
  }) {
    final initiative = _combatEngine.rollInitiative(player, enemies);
    final isPlayerFirst = initiative.first.isPlayer;
    
    final combatState = CombatState(
      id: _uuid.v4(),
      enemies: enemies,
      initiativeOrder: initiative,
      currentTurnIndex: 0,
      roundNumber: 1,
      isPlayerTurn: isPlayerFirst,
      isActive: true,
      phase: CombatPhase.playerTurn,
    );
    
    // Build initiative message
    final initMessage = _buildInitiativeMessage(player, enemies, initiative);
    
    return CombatStartResult(
      combatState: combatState,
      initiativeMessage: initMessage,
      narrativePrompt: _buildCombatStartPrompt(player, enemies, isPlayerFirst),
    );
  }
  
  /// Process player's combat action
  PlayerCombatResult processPlayerAction({
    required CombatState combatState,
    required CharacterModel player,
    required PlayerCombatAction action,
  }) {
    final messages = <StoryMessageModel>[];
    var updatedEnemies = List<MonsterModel>.from(combatState.enemies);
    var updatedPlayer = player;
    String narrativePrompt = '';
    
    switch (action.type) {
      case CombatActionType.meleeAttack:
      case CombatActionType.rangedAttack:
        final targetIndex = updatedEnemies.indexWhere((e) => e.id == action.targetId);
        if (targetIndex == -1) break;
        
        final target = updatedEnemies[targetIndex];
        final attackResult = _combatEngine.playerAttack(
          player: player,
          target: target,
          attackBonus: action.attackBonus ?? player.proficiencyBonus + 
              player.getAbilityModifier(Ability.strength),
          damageNotation: action.damageNotation ?? '1d8',
          damageType: action.damageType ?? DamageType.slashing,
          advantage: action.hasAdvantage,
          disadvantage: action.hasDisadvantage,
        );
        
        // Update enemy HP
        updatedEnemies[targetIndex] = target.copyWith(
          currentHitPoints: attackResult.targetNewHP,
        );
        
        // Build combat message
        messages.add(_buildAttackMessage(
          attackerName: player.name,
          targetName: target.name,
          result: attackResult,
          isPlayerAttack: true,
        ));
        
        if (attackResult.targetKilled) {
          messages.add(StoryMessageModel(
            id: _uuid.v4(),
            type: MessageType.combat,
            content: '💀 ${target.name} has been defeated!',
            timestamp: DateTime.now(),
            isImportant: true,
          ));
        }
        
        // Build narrative prompt for AI
        narrativePrompt = _buildAttackNarrativePrompt(
          attackerName: player.name,
          targetName: target.name,
          result: attackResult,
          isPlayerAttack: true,
        );
        break;
        
      case CombatActionType.dodge:
        messages.add(StoryMessageModel(
          id: _uuid.v4(),
          type: MessageType.combat,
          content: '🛡️ ${player.name} takes the Dodge action, gaining advantage on DEX saves.',
          timestamp: DateTime.now(),
        ));
        narrativePrompt = '${player.name} takes a defensive stance, ready to dodge incoming attacks.';
        break;
        
      case CombatActionType.flee:
        final fleeRoll = _diceRoller.rollD20();
        final fleeDC = 10;
        final fleeSuccess = fleeRoll >= fleeDC;
        
        messages.add(StoryMessageModel(
          id: _uuid.v4(),
          type: MessageType.combat,
          content: fleeSuccess 
              ? '🏃 ${player.name} successfully flees from combat! (Rolled $fleeRoll vs DC $fleeDC)'
              : '❌ ${player.name} fails to escape! (Rolled $fleeRoll vs DC $fleeDC)',
          timestamp: DateTime.now(),
        ));
        
        if (fleeSuccess) {
          return PlayerCombatResult(
            updatedCombatState: combatState.copyWith(
              isActive: false,
              phase: CombatPhase.resolution,
            ),
            updatedPlayer: player,
            messages: messages,
            narrativePrompt: '${player.name} manages to escape from the battle!',
            combatEnded: true,
            playerVictory: false,
            playerFled: true,
          );
        }
        narrativePrompt = '${player.name} tries to flee but the enemies block the escape!';
        break;
        
      case CombatActionType.healing:
        if (action.healingNotation != null) {
          final healResult = _combatEngine.applyHealing(
            target: player,
            healingNotation: action.healingNotation!,
          );
          updatedPlayer = player.copyWith(currentHitPoints: healResult.newHP);
          
          messages.add(StoryMessageModel(
            id: _uuid.v4(),
            type: MessageType.combat,
            content: '💚 ${player.name} heals for ${healResult.actualHealing} HP! (Now at ${healResult.newHP}/${player.maxHitPoints})',
            timestamp: DateTime.now(),
          ));
          narrativePrompt = '${player.name} channels healing energy, recovering ${healResult.actualHealing} hit points.';
        }
        break;
        
      default:
        messages.add(StoryMessageModel(
          id: _uuid.v4(),
          type: MessageType.combat,
          content: '${player.name} prepares for the next move.',
          timestamp: DateTime.now(),
        ));
        break;
    }
    
    // Check for victory
    final aliveEnemies = updatedEnemies.where((e) => e.isAlive).toList();
    if (aliveEnemies.isEmpty) {
      final xpReward = _combatEngine.calculateExperienceReward(updatedEnemies);
      
      messages.add(StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.combat,
        content: '🎉 Victory! All enemies defeated! Earned $xpReward XP!',
        timestamp: DateTime.now(),
        isImportant: true,
        experienceGained: xpReward,
      ));
      
      return PlayerCombatResult(
        updatedCombatState: combatState.copyWith(
          enemies: updatedEnemies,
          isActive: false,
          phase: CombatPhase.victory,
        ),
        updatedPlayer: updatedPlayer,
        messages: messages,
        narrativePrompt: 'Victory! ${player.name} has defeated all enemies!',
        combatEnded: true,
        playerVictory: true,
        xpEarned: xpReward,
      );
    }
    
    // Advance to enemy turn
    final nextTurnIndex = (combatState.currentTurnIndex + 1) % combatState.initiativeOrder.length;
    final nextTurn = combatState.initiativeOrder[nextTurnIndex];
    
    return PlayerCombatResult(
      updatedCombatState: combatState.copyWith(
        enemies: updatedEnemies,
        currentTurnIndex: nextTurnIndex,
        isPlayerTurn: nextTurn.isPlayer,
        phase: nextTurn.isPlayer ? CombatPhase.playerTurn : CombatPhase.enemyTurn,
        roundNumber: nextTurnIndex == 0 ? combatState.roundNumber + 1 : combatState.roundNumber,
      ),
      updatedPlayer: updatedPlayer,
      messages: messages,
      narrativePrompt: narrativePrompt,
      combatEnded: false,
    );
  }
  
  /// Process enemy turn (AI-driven)
  EnemyCombatResult processEnemyTurn({
    required CombatState combatState,
    required CharacterModel player,
  }) {
    final messages = <StoryMessageModel>[];
    var updatedPlayer = player;
    
    // Find the current enemy
    final currentTurn = combatState.currentTurn;
    if (currentTurn == null || currentTurn.isPlayer) {
      // Skip if it's player's turn
      return EnemyCombatResult(
        updatedCombatState: combatState,
        updatedPlayer: player,
        messages: [],
        narrativePrompt: '',
      );
    }
    
    final enemy = combatState.enemies.firstWhere(
      (e) => e.id == currentTurn.id,
      orElse: () => combatState.aliveEnemies.first,
    );
    
    if (!enemy.isAlive) {
      // Skip dead enemy, move to next turn
      return _advanceToNextTurn(combatState, player, messages);
    }
    
    // Choose enemy action (simple AI: pick first available action)
    final action = enemy.actions.isNotEmpty ? enemy.actions.first : MonsterAction(
      name: 'Attack',
      description: 'Basic attack',
      damage: '1d6',
      damageType: DamageType.bludgeoning,
    );
    
    // Process attack
    final attackResult = _combatEngine.monsterAttack(
      attacker: enemy,
      player: player,
      action: action,
    );
    
    updatedPlayer = player.copyWith(
      currentHitPoints: attackResult.playerNewHP,
      temporaryHitPoints: attackResult.tempHPRemaining ?? player.temporaryHitPoints,
    );
    
    // Build message
    messages.add(_buildMonsterAttackMessage(enemy.name, action.name, attackResult));
    
    // Check for player defeat
    if (attackResult.playerKnocked) {
      messages.add(StoryMessageModel(
        id: _uuid.v4(),
        type: MessageType.combat,
        content: '💀 ${player.name} has fallen! The world fades to black...',
        timestamp: DateTime.now(),
        isImportant: true,
      ));
      
      return EnemyCombatResult(
        updatedCombatState: combatState.copyWith(
          isActive: false,
          phase: CombatPhase.defeat,
        ),
        updatedPlayer: updatedPlayer,
        messages: messages,
        narrativePrompt: '${player.name} falls unconscious as ${enemy.name}\'s attack lands!',
        playerDefeated: true,
      );
    }
    
    // Advance turn
    return _advanceToNextTurn(
      combatState,
      updatedPlayer,
      messages,
      narrativePrompt: _buildMonsterAttackNarrative(enemy.name, action.name, attackResult),
    );
  }
  
  EnemyCombatResult _advanceToNextTurn(
    CombatState combatState,
    CharacterModel player,
    List<StoryMessageModel> messages, {
    String narrativePrompt = '',
  }) {
    final nextTurnIndex = (combatState.currentTurnIndex + 1) % combatState.initiativeOrder.length;
    final nextTurn = combatState.initiativeOrder[nextTurnIndex];
    
    return EnemyCombatResult(
      updatedCombatState: combatState.copyWith(
        currentTurnIndex: nextTurnIndex,
        isPlayerTurn: nextTurn.isPlayer,
        phase: nextTurn.isPlayer ? CombatPhase.playerTurn : CombatPhase.enemyTurn,
        roundNumber: nextTurnIndex == 0 ? combatState.roundNumber + 1 : combatState.roundNumber,
      ),
      updatedPlayer: player,
      messages: messages,
      narrativePrompt: narrativePrompt,
    );
  }
  
  /// Build initiative order message
  StoryMessageModel _buildInitiativeMessage(
    CharacterModel player,
    List<MonsterModel> enemies,
    List<InitiativeEntry> order,
  ) {
    final orderText = order.map((e) => '${e.name}: ${e.initiative}').join(', ');
    
    return StoryMessageModel(
      id: _uuid.v4(),
      type: MessageType.combat,
      content: '⚔️ COMBAT BEGINS!\n\nInitiative Order: $orderText\n\n${order.first.name} acts first!',
      timestamp: DateTime.now(),
      isImportant: true,
    );
  }
  
  /// Build attack result message
  StoryMessageModel _buildAttackMessage({
    required String attackerName,
    required String targetName,
    required PlayerAttackResult result,
    required bool isPlayerAttack,
  }) {
    String content;
    
    if (result.attackRoll.isCriticalHit) {
      content = '💥 CRITICAL HIT! $attackerName strikes $targetName for ${result.finalDamage} damage!';
    } else if (result.attackRoll.isCriticalMiss) {
      content = '❌ Critical Miss! $attackerName\'s attack goes wild!';
    } else if (result.isHit) {
      content = '⚔️ $attackerName hits $targetName for ${result.finalDamage} ${result.damageType.displayName} damage!';
    } else {
      content = '🛡️ $attackerName\'s attack misses $targetName! (${result.attackRoll.total} vs AC)';
    }
    
    return StoryMessageModel(
      id: _uuid.v4(),
      type: MessageType.combat,
      content: content,
      timestamp: DateTime.now(),
      combatResult: CombatResult(
        attackerName: attackerName,
        defenderName: targetName,
        actionType: CombatActionType.meleeAttack,
        attackRoll: result.attackRoll.total,
        damageRoll: result.damageRoll?.total,
        totalDamage: result.finalDamage,
        damageType: result.damageType,
        isHit: result.isHit,
        isCriticalHit: result.isCritical,
        isMiss: !result.isHit,
        isCriticalMiss: result.attackRoll.isCriticalMiss,
      ),
    );
  }
  
  /// Build monster attack message
  StoryMessageModel _buildMonsterAttackMessage(
    String attackerName,
    String actionName,
    MonsterAttackResult result,
  ) {
    String content;
    
    if (result.attackRoll.isCriticalHit) {
      content = '💥 CRITICAL! $attackerName uses $actionName and deals ${result.finalDamage} damage!';
    } else if (result.attackRoll.isCriticalMiss) {
      content = '😅 $attackerName\'s $actionName misses completely!';
    } else if (result.isHit) {
      content = '🔴 $attackerName uses $actionName dealing ${result.finalDamage} damage!';
    } else {
      content = '🛡️ $attackerName\'s $actionName misses! (${result.attackRoll.total} vs AC)';
    }
    
    return StoryMessageModel(
      id: _uuid.v4(),
      type: MessageType.combat,
      content: content,
      timestamp: DateTime.now(),
    );
  }
  
  /// Build narrative prompt for AI to describe combat start
  String _buildCombatStartPrompt(CharacterModel player, List<MonsterModel> enemies, bool playerFirst) {
    final enemyNames = enemies.map((e) => e.name).join(', ');
    return '''
COMBAT HAS STARTED!
Enemies: $enemyNames
${playerFirst ? '${player.name} acts first!' : '${enemies.first.name} acts first!'}

Describe the tense moment as combat begins. Set the scene for battle.
''';
  }
  
  /// Build narrative prompt for attack
  String _buildAttackNarrativePrompt({
    required String attackerName,
    required String targetName,
    required PlayerAttackResult result,
    required bool isPlayerAttack,
  }) {
    if (result.isCritical) {
      return '$attackerName lands a devastating critical hit on $targetName for ${result.finalDamage} damage!';
    } else if (result.isHit) {
      return '$attackerName strikes $targetName for ${result.finalDamage} damage.';
    } else {
      return '$attackerName\'s attack misses $targetName.';
    }
  }
  
  /// Build narrative for monster attack
  String _buildMonsterAttackNarrative(String attackerName, String actionName, MonsterAttackResult result) {
    if (result.isCritical) {
      return '$attackerName lands a brutal $actionName, dealing ${result.finalDamage} damage!';
    } else if (result.isHit) {
      return '$attackerName\'s $actionName connects, dealing ${result.finalDamage} damage.';
    } else {
      return '$attackerName\'s $actionName misses!';
    }
  }
  
  /// Get suggested combat actions for player
  List<String> getCombatSuggestions(CombatState combatState, CharacterModel player) {
    final suggestions = <String>[];
    final aliveEnemies = combatState.aliveEnemies;
    
    if (aliveEnemies.isEmpty) return ['Victory!'];
    
    // Attack suggestions
    for (final enemy in aliveEnemies.take(2)) {
      suggestions.add('Attack ${enemy.name}');
    }
    
    // Defensive options
    suggestions.add('Dodge');
    
    // Class-specific options
    if (player.characterClass == CharacterClass.cleric || 
        player.characterClass == CharacterClass.paladin) {
      suggestions.add('Cast healing spell');
    }
    
    if (player.characterClass == CharacterClass.rogue) {
      suggestions.add('Hide and prepare sneak attack');
    }
    
    // Always allow flee
    suggestions.add('Attempt to flee');
    
    return suggestions.take(4).toList();
  }
}

/// Player combat action
class PlayerCombatAction {
  final CombatActionType type;
  final String? targetId;
  final int? attackBonus;
  final String? damageNotation;
  final DamageType? damageType;
  final String? healingNotation;
  final bool hasAdvantage;
  final bool hasDisadvantage;
  
  const PlayerCombatAction({
    required this.type,
    this.targetId,
    this.attackBonus,
    this.damageNotation,
    this.damageType,
    this.healingNotation,
    this.hasAdvantage = false,
    this.hasDisadvantage = false,
  });
}

/// Result of starting combat
class CombatStartResult {
  final CombatState combatState;
  final StoryMessageModel initiativeMessage;
  final String narrativePrompt;
  
  const CombatStartResult({
    required this.combatState,
    required this.initiativeMessage,
    required this.narrativePrompt,
  });
}

/// Result of player combat action
class PlayerCombatResult {
  final CombatState updatedCombatState;
  final CharacterModel updatedPlayer;
  final List<StoryMessageModel> messages;
  final String narrativePrompt;
  final bool combatEnded;
  final bool playerVictory;
  final bool playerFled;
  final int? xpEarned;
  
  const PlayerCombatResult({
    required this.updatedCombatState,
    required this.updatedPlayer,
    required this.messages,
    required this.narrativePrompt,
    this.combatEnded = false,
    this.playerVictory = false,
    this.playerFled = false,
    this.xpEarned,
  });
}

/// Result of enemy combat turn
class EnemyCombatResult {
  final CombatState updatedCombatState;
  final CharacterModel updatedPlayer;
  final List<StoryMessageModel> messages;
  final String narrativePrompt;
  final bool playerDefeated;
  
  const EnemyCombatResult({
    required this.updatedCombatState,
    required this.updatedPlayer,
    required this.messages,
    required this.narrativePrompt,
    this.playerDefeated = false,
  });
}

