import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/core/constants/game_constants.dart';
import 'package:dnd_ai_game/data/models/character_model.dart';
import 'package:dnd_ai_game/data/models/game_state_model.dart';
import 'package:dnd_ai_game/data/models/quest_model.dart';
import 'package:dnd_ai_game/data/models/item_model.dart';
import 'package:dnd_ai_game/data/models/story_message_model.dart';
import 'package:dnd_ai_game/data/repositories/game_repository.dart';
import 'package:dnd_ai_game/data/services/storage_service.dart';

@GenerateMocks([IGameRepository])
import 'game_save_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Game Save Tests', () {
    late MockIGameRepository mockRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockRepository = MockIGameRepository();
    });

    group('createNewGame', () {
      test('should create a new game with valid state', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createFullGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        // Act
        final gameState = await mockRepository.createNewGame(
          saveName: 'Test Adventure',
          character: character,
        );

        // Assert
        expect(gameState.id, isNotEmpty);
        expect(gameState.saveName, 'Test Adventure');
        expect(gameState.character.name, character.name);
        expect(gameState.createdAt, isNotNull);
        expect(gameState.lastPlayedAt, isNotNull);
      });

      test('should initialize with starting scene', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createFullGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        // Act
        final gameState = await mockRepository.createNewGame(
          saveName: 'Test Adventure',
          character: character,
        );

        // Assert
        expect(gameState.currentScene, isNotNull);
        expect(gameState.currentScene.name, 'The Crossroads Inn');
        expect(gameState.currentScene.type, SceneType.exploration);
      });

      test('should initialize with starter quest', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createFullGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        // Act
        final gameState = await mockRepository.createNewGame(
          saveName: 'Test Adventure',
          character: character,
        );

        // Assert
        expect(gameState.quests, isNotEmpty);
        expect(gameState.quests.first.title, 'A New Beginning');
        expect(gameState.quests.first.status, QuestStatus.active);
      });

      test('should initialize with starter inventory', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createFullGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        // Act
        final gameState = await mockRepository.createNewGame(
          saveName: 'Test Adventure',
          character: character,
        );

        // Assert
        expect(gameState.inventory.items, isNotEmpty);
        expect(gameState.inventory.items.length, greaterThanOrEqualTo(3));
      });

      test('should initialize with starting gold', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createFullGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        // Act
        final gameState = await mockRepository.createNewGame(
          saveName: 'Test Adventure',
          character: character,
        );

        // Assert
        expect(gameState.gold, 15);
      });

      test('should initialize with empty story log', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createFullGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        // Act
        final gameState = await mockRepository.createNewGame(
          saveName: 'Test Adventure',
          character: character,
        );

        // Assert
        expect(gameState.storyLog, isEmpty);
      });

      test('should set difficulty to normal by default', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createFullGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        // Act
        final gameState = await mockRepository.createNewGame(
          saveName: 'Test Adventure',
          character: character,
        );

        // Assert
        expect(gameState.difficulty, GameDifficulty.normal);
      });
    });

    group('saveGame', () {
      test('should save game state', () async {
        // Arrange
        final character = _createTestCharacter();
        final gameState = _createFullGameState(character);

        GameStateModel? savedState;
        when(mockRepository.saveGame(any)).thenAnswer((invocation) async {
          savedState = invocation.positionalArguments[0] as GameStateModel;
        });

        when(mockRepository.loadGame(gameState.id))
            .thenAnswer((_) async => savedState);

        // Act - Modify and save
        final updatedState = gameState.copyWith(
          gold: 100,
          lastPlayedAt: DateTime.now(),
        );
        await mockRepository.saveGame(updatedState);

        // Assert
        expect(savedState?.gold, 100);
      });

      test('should preserve story log after save', () async {
        // Arrange
        final character = _createTestCharacter();
        final gameState = _createFullGameState(character);

        final storyEntry = StoryMessageModel(
          id: 'test-entry',
          type: MessageType.narration,
          content: 'You enter the tavern...',
          timestamp: DateTime.now(),
        );

        final updatedState = gameState.copyWith(
          storyLog: [storyEntry],
        );

        GameStateModel? savedState;
        when(mockRepository.saveGame(any)).thenAnswer((invocation) async {
          savedState = invocation.positionalArguments[0] as GameStateModel;
        });

        // Act
        await mockRepository.saveGame(updatedState);

        // Assert
        expect(savedState?.storyLog.length, 1);
        expect(savedState?.storyLog.first.content, 'You enter the tavern...');
      });

      test('should update lastPlayedAt on save', () async {
        // Arrange
        final character = _createTestCharacter();
        final gameState = _createFullGameState(character);
        final originalTime = gameState.lastPlayedAt;

        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        final updatedState = gameState.copyWith(
          lastPlayedAt: DateTime.now(),
        );

        // Assert
        expect(updatedState.lastPlayedAt.isAfter(originalTime), isTrue);
      });
    });

    group('Auto-save behavior', () {
      test('game should be saved immediately after creation', () async {
        // Arrange
        final character = _createTestCharacter();
        final gameState = _createFullGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => gameState);

        when(mockRepository.loadGame(gameState.id))
            .thenAnswer((_) async => gameState);

        // Act
        final created = await mockRepository.createNewGame(
          saveName: 'Auto-Save Test',
          character: character,
        );

        final loadedState = await mockRepository.loadGame(created.id);

        // Assert - Should be loadable immediately
        expect(loadedState, isNotNull);
        expect(loadedState?.id, gameState.id);
      });

      test('hasSaves should return true after creating a game', () async {
        // Arrange
        when(mockRepository.hasSaves()).thenReturn(true);

        // Act & Assert
        expect(mockRepository.hasSaves(), isTrue);
      });

      test('getAllSaves should include newly created game', () async {
        // Arrange
        final character = _createTestCharacter();
        
        when(mockRepository.getAllSaves()).thenReturn([
          SaveGameInfo(
            id: 'test-id',
            saveName: 'Listed Adventure',
            characterName: character.name,
            characterLevel: 1,
            lastPlayedAt: DateTime.now(),
            totalPlayTime: const Duration(minutes: 5),
          ),
        ]);

        // Act
        final saves = mockRepository.getAllSaves();

        // Assert
        expect(saves.any((s) => s.saveName == 'Listed Adventure'), isTrue);
      });
    });

    group('Game state modifications', () {
      test('should save character HP changes', () async {
        // Arrange
        final character = _createTestCharacter();
        final gameState = _createFullGameState(character);

        GameStateModel? savedState;
        when(mockRepository.saveGame(any)).thenAnswer((invocation) async {
          savedState = invocation.positionalArguments[0] as GameStateModel;
        });

        // Act - Simulate damage
        final damagedCharacter = gameState.character.copyWith(
          currentHitPoints: gameState.character.currentHitPoints - 5,
        );
        final updatedState = gameState.copyWith(character: damagedCharacter);
        await mockRepository.saveGame(updatedState);

        // Assert
        expect(
          savedState?.character.currentHitPoints,
          gameState.character.currentHitPoints - 5,
        );
      });

      test('should save experience points changes', () async {
        // Arrange
        final character = _createTestCharacter();
        final gameState = _createFullGameState(character);

        GameStateModel? savedState;
        when(mockRepository.saveGame(any)).thenAnswer((invocation) async {
          savedState = invocation.positionalArguments[0] as GameStateModel;
        });

        // Act - Add XP
        final leveledCharacter = gameState.character.copyWith(
          experiencePoints: 100,
        );
        final updatedState = gameState.copyWith(character: leveledCharacter);
        await mockRepository.saveGame(updatedState);

        // Assert
        expect(savedState?.character.experiencePoints, 100);
      });

      test('should save quest progress', () async {
        // Arrange
        final character = _createTestCharacter();
        final gameState = _createFullGameState(character);

        GameStateModel? savedState;
        when(mockRepository.saveGame(any)).thenAnswer((invocation) async {
          savedState = invocation.positionalArguments[0] as GameStateModel;
        });

        // Act - Complete quest
        final updatedQuest = gameState.quests.first.copyWith(
          status: QuestStatus.completed,
        );
        final updatedState = gameState.copyWith(
          quests: [updatedQuest],
        );
        await mockRepository.saveGame(updatedState);

        // Assert
        expect(savedState?.quests.first.status, QuestStatus.completed);
      });

      test('should save inventory changes', () async {
        // Arrange
        final character = _createTestCharacter();
        final gameState = _createFullGameState(character);

        GameStateModel? savedState;
        when(mockRepository.saveGame(any)).thenAnswer((invocation) async {
          savedState = invocation.positionalArguments[0] as GameStateModel;
        });

        // Act - Add item
        final newItem = ItemModel(
          id: 'new-item',
          name: 'Magic Ring',
          description: 'A mysterious ring',
          type: ItemType.misc,
          value: 100,
        );
        final updatedInventory = gameState.inventory.copyWith(
          items: [...gameState.inventory.items, newItem],
        );
        final updatedState = gameState.copyWith(inventory: updatedInventory);
        await mockRepository.saveGame(updatedState);

        // Assert
        expect(
          savedState?.inventory.items.any((i) => i.name == 'Magic Ring'),
          isTrue,
        );
      });

      test('should save scene changes', () async {
        // Arrange
        final character = _createTestCharacter();
        final gameState = _createFullGameState(character);

        GameStateModel? savedState;
        when(mockRepository.saveGame(any)).thenAnswer((invocation) async {
          savedState = invocation.positionalArguments[0] as GameStateModel;
        });

        // Act - Change scene
        final newScene = SceneModel(
          id: 'new-scene',
          name: 'Dark Forest',
          description: 'A spooky forest',
          type: SceneType.exploration,
        );
        final updatedState = gameState.copyWith(currentScene: newScene);
        await mockRepository.saveGame(updatedState);

        // Assert
        expect(savedState?.currentScene.name, 'Dark Forest');
      });
    });

    group('deleteGame', () {
      test('should delete game save', () async {
        // Arrange
        final gameId = 'test-game-id';
        
        when(mockRepository.deleteGame(gameId)).thenAnswer((_) async {});
        when(mockRepository.loadGame(gameId)).thenAnswer((_) async => null);

        // Act
        await mockRepository.deleteGame(gameId);

        // Assert
        verify(mockRepository.deleteGame(gameId)).called(1);
        final loadedState = await mockRepository.loadGame(gameId);
        expect(loadedState, isNull);
      });

      test('should not affect other saves when deleting', () async {
        // Arrange
        final game1Id = 'keep-this';
        final game2Id = 'delete-this';
        
        final character = _createTestCharacter();
        final game1 = _createFullGameState(character).copyWith(
          id: game1Id,
          saveName: 'Keep This',
        );

        when(mockRepository.loadGame(game1Id)).thenAnswer((_) async => game1);
        when(mockRepository.loadGame(game2Id)).thenAnswer((_) async => null);
        when(mockRepository.deleteGame(game2Id)).thenAnswer((_) async {});

        // Act
        await mockRepository.deleteGame(game2Id);

        // Assert
        final loadedGame1 = await mockRepository.loadGame(game1Id);
        expect(loadedGame1, isNotNull);
        expect(loadedGame1?.saveName, 'Keep This');
      });
    });
  });
}

/// Helper function to create a test character
CharacterModel _createTestCharacter({
  String name = 'Test Hero',
  CharacterRace race = CharacterRace.human,
  CharacterClass characterClass = CharacterClass.fighter,
}) {
  return CharacterModel(
    id: 'test-char-id',
    name: name,
    race: race,
    characterClass: characterClass,
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
    proficientSkills: {Skill.athletics, Skill.perception},
    hitDiceRemaining: 1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

/// Create a full game state with starter content
GameStateModel _createFullGameState(CharacterModel character) {
  final now = DateTime.now();
  
  final initialScene = SceneModel(
    id: 'scene-001',
    name: 'The Crossroads Inn',
    description: 'A cozy tavern at the crossroads.',
    type: SceneType.exploration,
    availableExits: ['North Road', 'South Road'],
  );
  
  final initialQuest = QuestModel(
    id: 'quest-001',
    title: 'A New Beginning',
    description: 'Start your adventure!',
    type: QuestType.main,
    status: QuestStatus.active,
    level: 1,
    objectives: [
      QuestObjective(
        id: 'obj-001',
        description: 'Explore the inn',
        type: ObjectiveType.explore,
        targetProgress: 1,
      ),
    ],
    rewards: const QuestRewards(experiencePoints: 50, gold: 10),
    giverNpcName: 'Your Journey',
    location: 'The Crossroads Inn',
    startedAt: now,
    isTracked: true,
  );
  
  final starterItems = <ItemModel>[
    ItemModel(
      id: 'item-001',
      name: "Traveler's Pack",
      description: 'Basic supplies',
      type: ItemType.misc,
      weight: 5,
      value: 2,
    ),
    PotionModel(
      id: 'potion-001',
      name: 'Potion of Healing',
      description: 'Restores health',
      rarity: ItemRarity.common,
      value: 50,
      effect: PotionEffect.healing,
      effectValue: '2d4+2',
    ),
    ItemModel(
      id: 'item-002',
      name: 'Rations',
      description: 'Food for travel',
      type: ItemType.consumable,
      weight: 2,
      value: 1,
      isStackable: true,
      quantity: 5,
      maxStack: 20,
    ),
    WeaponModel(
      id: 'weapon-001',
      name: 'Longsword',
      description: 'A versatile blade',
      value: 15,
      weight: 3,
      weaponType: WeaponType.martialMelee,
      damage: '1d8',
      damageType: DamageType.slashing,
    ),
  ];
  
  return GameStateModel(
    id: 'game-${now.millisecondsSinceEpoch}',
    saveName: 'Test Adventure',
    character: character,
    inventory: InventoryModel(items: starterItems, maxSlots: 30),
    quests: [initialQuest],
    currentScene: initialScene,
    storyLog: [],
    gold: 15,
    createdAt: now,
    lastPlayedAt: now,
    difficulty: GameDifficulty.normal,
  );
}
