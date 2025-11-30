import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/data/services/game_action_service.dart';
import 'package:dnd_ai_game/data/models/game_state_model.dart';
import 'package:dnd_ai_game/data/models/character_model.dart';
import 'package:dnd_ai_game/data/models/item_model.dart';
import 'package:dnd_ai_game/core/constants/game_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameActionType', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should have correct values', () {
      expect(GameActionType.addItem.value, 'addItem');
      expect(GameActionType.removeItem.value, 'removeItem');
      expect(GameActionType.useItem.value, 'useItem');
      expect(GameActionType.heal.value, 'heal');
      expect(GameActionType.damage.value, 'damage');
      expect(GameActionType.addGold.value, 'addGold');
      expect(GameActionType.spendGold.value, 'spendGold');
      expect(GameActionType.addXP.value, 'addXP');
      expect(GameActionType.changeLocation.value, 'changeLocation');
    });

    test('fromString should parse valid values', () {
      expect(GameActionType.fromString('addItem'), GameActionType.addItem);
      expect(GameActionType.fromString('heal'), GameActionType.heal);
      expect(GameActionType.fromString('damage'), GameActionType.damage);
    });

    test('fromString should return null for invalid values', () {
      expect(GameActionType.fromString('invalid'), isNull);
      expect(GameActionType.fromString(''), isNull);
    });
  });

  group('GameAction', () {
    test('should create with required fields', () {
      final action = GameAction(
        type: GameActionType.addItem,
        params: {'itemName': 'Sword', 'quantity': 1},
      );

      expect(action.type, GameActionType.addItem);
      expect(action.params['itemName'], 'Sword');
      expect(action.params['quantity'], 1);
      expect(action.narration, isNull);
      expect(action.requiresValidation, isTrue);
    });

    test('should serialize to JSON correctly', () {
      final action = GameAction(
        type: GameActionType.heal,
        params: {'amount': '2d4+2'},
        narration: 'You drink the potion',
      );

      final json = action.toJson();

      expect(json['type'], 'heal');
      expect(json['params']['amount'], '2d4+2');
      expect(json['narration'], 'You drink the potion');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'type': 'damage',
        'params': {'amount': 5, 'damageType': 'fire'},
        'narration': 'The flames burn you',
      };

      final action = GameAction.fromJson(json);

      expect(action.type, GameActionType.damage);
      expect(action.params['amount'], 5);
      expect(action.params['damageType'], 'fire');
      expect(action.narration, 'The flames burn you');
    });

    test('addItem factory should create correct action', () {
      final action = GameAction.addItem(
        itemName: 'Healing Potion',
        quantity: 2,
        rarity: ItemRarity.uncommon,
      );

      expect(action.type, GameActionType.addItem);
      expect(action.params['itemName'], 'Healing Potion');
      expect(action.params['quantity'], 2);
      expect(action.params['rarity'], 'uncommon');
    });

    test('removeItem factory should create correct action', () {
      final action = GameAction.removeItem(
        itemName: 'Old Key',
        quantity: 1,
      );

      expect(action.type, GameActionType.removeItem);
      expect(action.params['itemName'], 'Old Key');
      expect(action.params['quantity'], 1);
    });

    test('useItem factory should create correct action', () {
      final action = GameAction.useItem(itemName: 'Health Potion');

      expect(action.type, GameActionType.useItem);
      expect(action.params['itemName'], 'Health Potion');
    });

    test('heal factory should create correct action', () {
      final action = GameAction.heal(
        amount: '2d4+2',
        source: 'Healing Potion',
      );

      expect(action.type, GameActionType.heal);
      expect(action.params['amount'], '2d4+2');
      expect(action.params['source'], 'Healing Potion');
    });

    test('damage factory should create correct action', () {
      final action = GameAction.damage(
        amount: 10,
        damageType: DamageType.fire,
        source: 'Dragon breath',
      );

      expect(action.type, GameActionType.damage);
      expect(action.params['amount'], 10);
      expect(action.params['damageType'], 'fire');
      expect(action.params['source'], 'Dragon breath');
    });

    test('addGold factory should create correct action', () {
      final action = GameAction.addGold(
        amount: 50,
        source: 'treasure chest',
      );

      expect(action.type, GameActionType.addGold);
      expect(action.params['amount'], 50);
      expect(action.params['source'], 'treasure chest');
    });

    test('spendGold factory should create correct action', () {
      final action = GameAction.spendGold(
        amount: 25,
        reason: 'bought a sword',
      );

      expect(action.type, GameActionType.spendGold);
      expect(action.params['amount'], 25);
      expect(action.params['reason'], 'bought a sword');
    });

    test('addXP factory should create correct action', () {
      final action = GameAction.addXP(
        amount: 100,
        reason: 'defeated goblin',
      );

      expect(action.type, GameActionType.addXP);
      expect(action.params['amount'], 100);
      expect(action.params['reason'], 'defeated goblin');
    });

    test('changeLocation factory should create correct action', () {
      final action = GameAction.changeLocation(
        locationName: 'Dark Forest',
        description: 'A spooky forest',
        sceneType: SceneType.exploration,
      );

      expect(action.type, GameActionType.changeLocation);
      expect(action.params['locationName'], 'Dark Forest');
      expect(action.params['description'], 'A spooky forest');
      expect(action.params['sceneType'], 'exploration');
    });

    test('rest factory should create correct action', () {
      final action = GameAction.rest(restType: RestType.long);

      expect(action.type, GameActionType.rest);
      expect(action.params['restType'], 'long');
    });
  });

  group('GameActionResult', () {
    test('success factory should create successful result', () {
      final state = _createTestGameState();
      final result = GameActionResult.success(
        state: state,
        message: 'Item added',
        data: {'itemId': 'item-123'},
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.updatedState, state);
      expect(result.message, 'Item added');
      expect(result.data?['itemId'], 'item-123');
    });

    test('failure factory should create failed result', () {
      final result = GameActionResult.failure('Not enough gold');

      expect(result.success, isFalse);
      expect(result.error, 'Not enough gold');
      expect(result.updatedState, isNull);
    });
  });

  group('GameActionValidator', () {
    late GameStateModel gameState;

    setUp(() {
      gameState = _createTestGameState();
    });

    test('should validate addGold within limits', () {
      final action = GameAction.addGold(amount: 50);
      final result = GameActionValidator.validate(action, gameState);

      expect(result.isValid, isTrue);
    });

    test('should allow addGold exceeding limits (executor will cap)', () {
      // The executor caps the gold, not the validator
      final action = GameAction.addGold(amount: 10000);
      final result = GameActionValidator.validate(action, gameState);

      // Validator allows it, executor will cap it
      expect(result.isValid, isTrue);
    });

    test('should reject negative addGold', () {
      final action = GameAction.addGold(amount: -50);
      final result = GameActionValidator.validate(action, gameState);

      expect(result.isValid, isFalse);
    });

    test('should validate addXP within limits', () {
      final action = GameAction.addXP(amount: 50);
      final result = GameActionValidator.validate(action, gameState);

      expect(result.isValid, isTrue);
    });

    test('should allow addXP exceeding limits (executor will cap)', () {
      // The executor caps the XP, not the validator
      final action = GameAction.addXP(amount: 5000);
      final result = GameActionValidator.validate(action, gameState);

      // Validator allows it, executor will cap it
      expect(result.isValid, isTrue);
    });

    test('should reject negative addXP', () {
      final action = GameAction.addXP(amount: -100);
      final result = GameActionValidator.validate(action, gameState);

      expect(result.isValid, isFalse);
    });

    test('should validate spendGold when sufficient', () {
      final stateWithGold = gameState.copyWith(gold: 100);
      final action = GameAction.spendGold(amount: 50);
      final result = GameActionValidator.validate(action, stateWithGold);

      expect(result.isValid, isTrue);
    });

    test('should reject spendGold when insufficient', () {
      final stateWithGold = gameState.copyWith(gold: 10);
      final action = GameAction.spendGold(amount: 50);
      final result = GameActionValidator.validate(action, stateWithGold);

      expect(result.isValid, isFalse);
      expect(result.error, contains('Not enough gold'));
    });

    test('should validate removeItem when item exists', () {
      final item = ItemModel(
        id: 'item-123',
        name: 'Healing Potion',
        description: 'Heals',
        type: ItemType.potion,
        rarity: ItemRarity.common,
        weight: 0.5,
        value: 50,
      );
      final stateWithItem = gameState.copyWith(
        inventory: gameState.inventory.copyWith(items: [item]),
      );

      final action = GameAction.removeItem(itemName: 'Healing Potion');
      final result = GameActionValidator.validate(action, stateWithItem);

      expect(result.isValid, isTrue);
    });

    test('should reject removeItem when item not found', () {
      final action = GameAction.removeItem(itemName: 'NonExistent Item');
      final result = GameActionValidator.validate(action, gameState);

      expect(result.isValid, isFalse);
      expect(result.error, contains('not found'));
    });

    test('should reject useItem when item not found', () {
      final action = GameAction.useItem(itemName: 'NonExistent Item');
      final result = GameActionValidator.validate(action, gameState);

      expect(result.isValid, isFalse);
      expect(result.error, contains('not found'));
    });

    test('maxGoldReward should scale with level', () {
      expect(GameActionValidator.maxGoldReward(1), 75);
      expect(GameActionValidator.maxGoldReward(5), 175);
      expect(GameActionValidator.maxGoldReward(10), 300);
    });

    test('maxXPReward should scale with level', () {
      expect(GameActionValidator.maxXPReward(1), 150);
      expect(GameActionValidator.maxXPReward(5), 350);
      expect(GameActionValidator.maxXPReward(10), 600);
    });
  });

  group('ValidationResult', () {
    test('valid should create valid result', () {
      final result = ValidationResult.valid();

      expect(result.isValid, isTrue);
      expect(result.error, isNull);
      expect(result.suggestedValue, isNull);
    });

    test('invalid should create invalid result', () {
      final result = ValidationResult.invalid(
        'Test error',
        suggestedValue: 100,
      );

      expect(result.isValid, isFalse);
      expect(result.error, 'Test error');
      expect(result.suggestedValue, 100);
    });
  });
}

GameStateModel _createTestGameState() {
  final character = CharacterModel(
    id: 'char-test',
    name: 'Test Hero',
    race: CharacterRace.human,
    characterClass: CharacterClass.fighter,
    level: 1,
    experiencePoints: 0,
    abilityScores: const AbilityScores(
      strength: 15,
      dexterity: 14,
      constitution: 13,
      intelligence: 12,
      wisdom: 10,
      charisma: 8,
    ),
    currentHitPoints: 10,
    maxHitPoints: 10,
    armorClass: 14,
    proficientSkills: {Skill.athletics},
    hitDiceRemaining: 1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  return GameStateModel(
    id: 'game-test',
    saveName: 'Test Game',
    character: character,
    inventory: const InventoryModel(items: [], maxSlots: 30),
    quests: [],
    currentScene: SceneModel(
      id: 'scene-test',
      name: 'Test Location',
      description: 'A test location',
      type: SceneType.exploration,
    ),
    storyLog: [],
    gold: 15,
    createdAt: DateTime.now(),
    lastPlayedAt: DateTime.now(),
    difficulty: GameDifficulty.normal,
  );
}

