import 'package:equatable/equatable.dart';
import '../models/game_state_model.dart';
import '../models/item_model.dart';
import '../../core/constants/game_constants.dart';

/// Types of game actions that the AI can propose
/// These actions are validated and executed by the game engine
enum GameActionType {
  /// Add an item to the player's inventory
  addItem('addItem'),
  /// Remove an item from the player's inventory
  removeItem('removeItem'),
  /// Use a consumable item (triggers its effect)
  useItem('useItem'),
  /// Equip an item to a slot
  equipItem('equipItem'),
  /// Unequip an item from a slot
  unequipItem('unequipItem'),
  /// Heal the player (HP restoration)
  heal('heal'),
  /// Apply damage to the player
  damage('damage'),
  /// Add gold to the player's inventory
  addGold('addGold'),
  /// Spend gold from the player's inventory
  spendGold('spendGold'),
  /// Award experience points
  addXP('addXP'),
  /// Update a quest objective
  updateQuest('updateQuest'),
  /// Start a new quest
  startQuest('startQuest'),
  /// Complete a quest
  completeQuest('completeQuest'),
  /// Change the current location/scene
  changeLocation('changeLocation'),
  /// Apply a status effect
  applyStatus('applyStatus'),
  /// Remove a status effect
  removeStatus('removeStatus'),
  /// Modify an ability score temporarily
  modifyAbility('modifyAbility'),
  /// Rest (restore hit dice, spells, etc.)
  rest('rest');

  final String value;
  const GameActionType(this.value);

  static GameActionType? fromString(String value) {
    for (final type in GameActionType.values) {
      if (type.value == value || type.name == value) {
        return type;
      }
    }
    return null;
  }
}

/// Represents a game action proposed by the AI
/// The game engine validates and executes these actions
class GameAction extends Equatable {
  /// The type of action to perform
  final GameActionType type;
  
  /// Parameters for the action (varies by type)
  final Map<String, dynamic> params;
  
  /// Optional narration to display with this action
  final String? narration;
  
  /// Whether this action requires validation before execution
  final bool requiresValidation;

  const GameAction({
    required this.type,
    required this.params,
    this.narration,
    this.requiresValidation = true,
  });

  factory GameAction.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = typeStr != null 
        ? GameActionType.fromString(typeStr) ?? GameActionType.addItem
        : GameActionType.addItem;
    
    return GameAction(
      type: type,
      params: (json['params'] as Map<String, dynamic>?) ?? {},
      narration: json['narration'] as String?,
      requiresValidation: json['requiresValidation'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.value,
    'params': params,
    if (narration != null) 'narration': narration,
    'requiresValidation': requiresValidation,
  };

  @override
  List<Object?> get props => [type, params, narration, requiresValidation];

  // Convenience constructors for common actions

  /// Create an action to add an item
  factory GameAction.addItem({
    required String itemName,
    int quantity = 1,
    ItemRarity? rarity,
    String? description,
  }) {
    return GameAction(
      type: GameActionType.addItem,
      params: {
        'itemName': itemName,
        'quantity': quantity,
        if (rarity != null) 'rarity': rarity.name,
        if (description != null) 'description': description,
      },
    );
  }

  /// Create an action to remove an item
  factory GameAction.removeItem({
    required String itemName,
    int quantity = 1,
  }) {
    return GameAction(
      type: GameActionType.removeItem,
      params: {
        'itemName': itemName,
        'quantity': quantity,
      },
    );
  }

  /// Create an action to use a consumable item
  factory GameAction.useItem({
    required String itemName,
  }) {
    return GameAction(
      type: GameActionType.useItem,
      params: {
        'itemName': itemName,
      },
    );
  }

  /// Create an action to heal the player
  factory GameAction.heal({
    required String amount,
    String? source,
  }) {
    return GameAction(
      type: GameActionType.heal,
      params: {
        'amount': amount, // Can be a dice notation like "2d4+2" or a number
        if (source != null) 'source': source,
      },
    );
  }

  /// Create an action to damage the player
  factory GameAction.damage({
    required int amount,
    DamageType? damageType,
    String? source,
  }) {
    return GameAction(
      type: GameActionType.damage,
      params: {
        'amount': amount,
        if (damageType != null) 'damageType': damageType.name,
        if (source != null) 'source': source,
      },
    );
  }

  /// Create an action to add gold
  factory GameAction.addGold({
    required int amount,
    String? source,
  }) {
    return GameAction(
      type: GameActionType.addGold,
      params: {
        'amount': amount,
        if (source != null) 'source': source,
      },
    );
  }

  /// Create an action to spend gold
  factory GameAction.spendGold({
    required int amount,
    String? reason,
  }) {
    return GameAction(
      type: GameActionType.spendGold,
      params: {
        'amount': amount,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Create an action to add experience points
  factory GameAction.addXP({
    required int amount,
    String? reason,
  }) {
    return GameAction(
      type: GameActionType.addXP,
      params: {
        'amount': amount,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Create an action to update quest progress
  factory GameAction.updateQuest({
    required String questId,
    required String objectiveId,
    required int progress,
  }) {
    return GameAction(
      type: GameActionType.updateQuest,
      params: {
        'questId': questId,
        'objectiveId': objectiveId,
        'progress': progress,
      },
    );
  }

  /// Create an action to change location
  factory GameAction.changeLocation({
    required String locationName,
    required String description,
    SceneType? sceneType,
  }) {
    return GameAction(
      type: GameActionType.changeLocation,
      params: {
        'locationName': locationName,
        'description': description,
        if (sceneType != null) 'sceneType': sceneType.name,
      },
    );
  }

  /// Create an action to rest
  factory GameAction.rest({
    required RestType restType,
  }) {
    return GameAction(
      type: GameActionType.rest,
      params: {
        'restType': restType.name,
      },
    );
  }
}

/// Types of rest
enum RestType {
  short,  // 1 hour - recover some hit dice
  long,   // 8 hours - recover all HP and resources
}

/// Result of executing a game action
class GameActionResult {
  /// Whether the action was successfully executed
  final bool success;
  
  /// Error message if the action failed
  final String? error;
  
  /// The updated game state after the action
  final GameStateModel? updatedState;
  
  /// Message to display to the player
  final String? message;
  
  /// Additional data from the action (e.g., dice roll results)
  final Map<String, dynamic>? data;

  const GameActionResult({
    required this.success,
    this.error,
    this.updatedState,
    this.message,
    this.data,
  });

  factory GameActionResult.success({
    required GameStateModel state,
    String? message,
    Map<String, dynamic>? data,
  }) {
    return GameActionResult(
      success: true,
      updatedState: state,
      message: message,
      data: data,
    );
  }

  factory GameActionResult.failure(String error) {
    return GameActionResult(
      success: false,
      error: error,
    );
  }
}

/// Validates game actions before execution
class GameActionValidator {
  /// Maximum gold that can be added in a single action (level-scaled)
  static int maxGoldReward(int playerLevel) => 50 + (playerLevel * 25);
  
  /// Maximum XP that can be awarded in a single action (level-scaled)
  static int maxXPReward(int playerLevel) => 100 + (playerLevel * 50);
  
  /// Validate an action against game rules
  /// Note: Gold and XP amounts are capped by the executor, not rejected here
  static ValidationResult validate(GameAction action, GameStateModel state) {
    switch (action.type) {
      case GameActionType.addGold:
        // Gold rewards are capped by executor, not rejected
        // Only reject if amount is negative
        final amount = action.params['amount'] as int? ?? 0;
        if (amount < 0) {
          return ValidationResult.invalid('Gold amount cannot be negative');
        }
        break;
        
      case GameActionType.addXP:
        // XP rewards are capped by executor, not rejected
        // Only reject if amount is negative
        final amount = action.params['amount'] as int? ?? 0;
        if (amount < 0) {
          return ValidationResult.invalid('XP amount cannot be negative');
        }
        break;
        
      case GameActionType.spendGold:
        final amount = action.params['amount'] as int? ?? 0;
        if (amount > state.gold) {
          return ValidationResult.invalid(
            'Not enough gold (need $amount, have ${state.gold})',
          );
        }
        break;
        
      case GameActionType.removeItem:
      case GameActionType.useItem:
        final itemName = action.params['itemName'] as String?;
        if (itemName == null) {
          return ValidationResult.invalid('Item name is required');
        }
        final hasItem = state.inventory.items.any(
          (i) => i.name.toLowerCase() == itemName.toLowerCase(),
        );
        if (!hasItem) {
          return ValidationResult.invalid(
            'Item "$itemName" not found in inventory',
          );
        }
        break;
        
      case GameActionType.heal:
        // Healing is generally allowed
        break;
        
      case GameActionType.damage:
        // Damage is generally allowed (but could add max damage validation)
        break;
        
      default:
        break;
    }
    
    return ValidationResult.valid();
  }
}

/// Result of validating a game action
class ValidationResult {
  final bool isValid;
  final String? error;
  final dynamic suggestedValue;

  const ValidationResult._({
    required this.isValid,
    this.error,
    this.suggestedValue,
  });

  factory ValidationResult.valid() => const ValidationResult._(isValid: true);
  
  factory ValidationResult.invalid(String error, {dynamic suggestedValue}) =>
      ValidationResult._(
        isValid: false,
        error: error,
        suggestedValue: suggestedValue,
      );
}

