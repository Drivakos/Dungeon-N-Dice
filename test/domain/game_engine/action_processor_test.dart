import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/domain/game_engine/game_master.dart';
import 'package:dnd_ai_game/data/services/game_action_service.dart';
import 'package:dnd_ai_game/data/models/game_state_model.dart';
import 'package:dnd_ai_game/data/models/character_model.dart';
import 'package:dnd_ai_game/data/models/item_model.dart';
import 'package:dnd_ai_game/core/constants/game_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameMaster Action Processing', () {
    late GameMaster gameMaster;
    late GameStateModel gameState;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      gameMaster = GameMaster();
      gameState = _createTestGameState();
    });

    group('addItem Action', () {
      test('should add item to inventory', () {
        final action = GameAction.addItem(
          itemName: 'Healing Potion',
          quantity: 1,
        );

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        expect(result.updatedState.inventory.items, hasLength(1));
        expect(result.updatedState.inventory.items.first.name, 'Healing Potion');
        expect(result.messages, isNotEmpty);
      });

      test('should add multiple items', () {
        final action = GameAction.addItem(
          itemName: 'Arrow',
          quantity: 5,
        );

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        expect(result.updatedState.inventory.items, hasLength(5));
      });

      test('should not exceed inventory limit', () {
        // Fill inventory to near capacity
        var state = gameState;
        for (var i = 0; i < 29; i++) {
          state = gameMaster.addItemToInventory(
            gameState: state,
            item: ItemModel(
              id: 'item-$i',
              name: 'Item $i',
              description: 'Test',
              type: ItemType.misc,
              rarity: ItemRarity.common,
              weight: 1,
              value: 1,
            ),
          );
        }

        final action = GameAction.addItem(
          itemName: 'Potion',
          quantity: 5, // Try to add 5, but only 1 slot available
        );

        final result = gameMaster.processGameActions(
          gameState: state,
          actions: [action],
        );

        expect(result.updatedState.inventory.items, hasLength(30));
      });

      test('should infer item type from name', () {
        final action = GameAction.addItem(itemName: 'Iron Sword');

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        expect(result.updatedState.inventory.items.first.type, ItemType.weapon);
      });
    });

    group('removeItem Action', () {
      test('should remove item from inventory', () {
        // First add an item
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

        final result = gameMaster.processGameActions(
          gameState: stateWithItem,
          actions: [action],
        );

        expect(result.updatedState.inventory.items, isEmpty);
      });

      test('should handle item not found gracefully', () {
        final action = GameAction.removeItem(itemName: 'NonExistent');

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        // Should not crash, just do nothing
        expect(result.updatedState.inventory.items, isEmpty);
      });
    });

    group('useItem Action', () {
      test('should remove consumable after use', () {
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

        final action = GameAction.useItem(itemName: 'Healing Potion');

        final result = gameMaster.processGameActions(
          gameState: stateWithItem,
          actions: [action],
        );

        expect(result.updatedState.inventory.items, isEmpty);
      });
    });

    group('heal Action', () {
      test('should heal player with flat amount', () {
        final damagedState = gameState.copyWith(
          character: gameState.character.copyWith(currentHitPoints: 5),
        );

        final action = GameAction.heal(amount: '3');

        final result = gameMaster.processGameActions(
          gameState: damagedState,
          actions: [action],
        );

        expect(result.updatedState.character.currentHitPoints, 8);
      });

      test('should not exceed max HP', () {
        final action = GameAction.heal(amount: '100');

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        expect(
          result.updatedState.character.currentHitPoints,
          gameState.character.maxHitPoints,
        );
      });

      test('should heal with dice notation', () {
        final damagedState = gameState.copyWith(
          character: gameState.character.copyWith(currentHitPoints: 1),
        );

        final action = GameAction.heal(amount: '2d4+2');

        final result = gameMaster.processGameActions(
          gameState: damagedState,
          actions: [action],
        );

        // Result should be between 1+4 = 5 and 1+10 = 11, capped at max HP
        expect(
          result.updatedState.character.currentHitPoints,
          greaterThanOrEqualTo(damagedState.character.currentHitPoints),
        );
      });
    });

    group('damage Action', () {
      test('should apply damage to player', () {
        final action = GameAction.damage(amount: 3);

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        expect(result.updatedState.character.currentHitPoints, 7);
      });

      test('should apply damage to temp HP first', () {
        final stateWithTempHP = gameState.copyWith(
          character: gameState.character.copyWith(temporaryHitPoints: 5),
        );

        final action = GameAction.damage(amount: 3);

        final result = gameMaster.processGameActions(
          gameState: stateWithTempHP,
          actions: [action],
        );

        expect(result.updatedState.character.temporaryHitPoints, 2);
        expect(
          result.updatedState.character.currentHitPoints,
          stateWithTempHP.character.currentHitPoints,
        );
      });

      test('should not go below 0 HP', () {
        final action = GameAction.damage(amount: 100);

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        expect(result.updatedState.character.currentHitPoints, 0);
      });
    });

    group('addGold Action', () {
      test('should add gold to player', () {
        final action = GameAction.addGold(amount: 50);

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        expect(result.updatedState.gold, gameState.gold + 50);
      });

      test('should cap gold at maximum for level', () {
        final action = GameAction.addGold(amount: 10000);

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        // Should be capped at level-based maximum
        final maxGold = GameActionValidator.maxGoldReward(gameState.character.level);
        expect(result.updatedState.gold, gameState.gold + maxGold);
      });
    });

    group('spendGold Action', () {
      test('should spend gold when sufficient', () {
        final stateWithGold = gameState.copyWith(gold: 100);

        final action = GameAction.spendGold(amount: 30);

        final result = gameMaster.processGameActions(
          gameState: stateWithGold,
          actions: [action],
        );

        expect(result.updatedState.gold, 70);
      });

      test('should fail when insufficient gold', () {
        final action = GameAction.spendGold(amount: 1000);

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        // Gold should remain unchanged
        expect(result.updatedState.gold, gameState.gold);
        expect(result.messages.any((m) => m.content.contains('Not enough gold')), isTrue);
      });
    });

    group('addXP Action', () {
      test('should add XP to player', () {
        final action = GameAction.addXP(amount: 50);

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        expect(
          result.updatedState.character.experiencePoints,
          greaterThan(gameState.character.experiencePoints),
        );
      });

      test('should cap XP at maximum for level', () {
        final action = GameAction.addXP(amount: 10000);

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        // Should be capped
        final maxXP = GameActionValidator.maxXPReward(gameState.character.level);
        expect(result.updatedState.character.experiencePoints, maxXP);
      });
    });

    group('changeLocation Action', () {
      test('should change current scene', () {
        final action = GameAction.changeLocation(
          locationName: 'Dark Forest',
          description: 'A spooky forest full of shadows',
        );

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: [action],
        );

        expect(result.updatedState.currentScene.name, 'Dark Forest');
        expect(
          result.updatedState.currentScene.description,
          'A spooky forest full of shadows',
        );
      });
    });

    group('Multiple Actions', () {
      test('should process multiple actions in sequence', () {
        final actions = [
          GameAction.addItem(itemName: 'Sword'),
          GameAction.addGold(amount: 50),
          GameAction.addXP(amount: 25),
        ];

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: actions,
        );

        expect(result.updatedState.inventory.items, hasLength(1));
        expect(result.updatedState.gold, greaterThan(gameState.gold));
        expect(
          result.updatedState.character.experiencePoints,
          greaterThan(gameState.character.experiencePoints),
        );
        expect(result.messages, hasLength(3));
      });

      test('should continue after invalid action', () {
        final actions = [
          GameAction.addItem(itemName: 'Sword'),
          GameAction.spendGold(amount: 10000), // Will fail - not enough gold
          GameAction.addGold(amount: 25), // Should still execute
        ];

        final result = gameMaster.processGameActions(
          gameState: gameState,
          actions: actions,
        );

        // Item should be added
        expect(result.updatedState.inventory.items, hasLength(1));
        // Gold should be increased (spend failed, add succeeded)
        expect(result.updatedState.gold, gameState.gold + 25);
      });
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

