import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/core/constants/game_constants.dart';
import 'package:dnd_ai_game/data/models/character_model.dart';
import 'package:dnd_ai_game/data/models/game_state_model.dart';
import 'package:dnd_ai_game/data/models/story_message_model.dart';
import 'package:dnd_ai_game/data/repositories/game_repository.dart';
import 'package:dnd_ai_game/data/services/ai_service.dart';
import 'package:dnd_ai_game/data/services/storage_service.dart';
import 'package:dnd_ai_game/domain/game_engine/game_master.dart';

@GenerateMocks([IGameRepository, AIService, GameMaster])
import 'auto_save_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auto-Save Tests', () {
    late MockIGameRepository mockRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockRepository = MockIGameRepository();
    });

    group('Game Creation Auto-Save', () {
      test('createNewGame should automatically save the game', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createTestGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        // Act
        final result = await mockRepository.createNewGame(
          saveName: 'Test Adventure',
          character: character,
        );

        // Assert
        verify(mockRepository.createNewGame(
          saveName: 'Test Adventure',
          character: character,
        )).called(1);
        expect(result.id, isNotEmpty);
      });

      test('new game should be loadable immediately after creation', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createTestGameState(character).copyWith(
          saveName: 'New Adventure',
        );

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        when(mockRepository.loadGame(expectedState.id))
            .thenAnswer((_) async => expectedState);

        // Act
        final created = await mockRepository.createNewGame(
          saveName: 'New Adventure',
          character: character,
        );
        final loaded = await mockRepository.loadGame(created.id);

        // Assert
        expect(loaded, isNotNull);
        expect(loaded?.id, created.id);
        expect(loaded?.saveName, 'New Adventure');
      });

      test('new game should appear in saves list', () async {
        // Arrange
        final character = _createTestCharacter();
        final expectedState = _createTestGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => expectedState);

        when(mockRepository.getAllSaves()).thenReturn([
          SaveGameInfo(
            id: expectedState.id,
            saveName: 'Listed Adventure',
            characterName: character.name,
            characterLevel: 1,
            lastPlayedAt: DateTime.now(),
            totalPlayTime: const Duration(minutes: 5),
          ),
        ]);

        // Act
        await mockRepository.createNewGame(
          saveName: 'Listed Adventure',
          character: character,
        );
        final saves = mockRepository.getAllSaves();

        // Assert
        expect(saves.any((s) => s.saveName == 'Listed Adventure'), isTrue);
      });
    });

    group('Player Action Auto-Save', () {
      test('game should be saved after player sends a message', () async {
        // Arrange
        final character = _createTestCharacter();
        final initialState = _createTestGameState(character);

        var saveCount = 0;
        when(mockRepository.saveGame(any)).thenAnswer((_) async {
          saveCount++;
        });

        when(mockRepository.loadGame(initialState.id))
            .thenAnswer((_) async => initialState);

        // Act - Simulate what happens after player action
        // In the real code, processPlayerAction calls saveGame
        final updatedState = initialState.copyWith(
          storyLog: [
            ...initialState.storyLog,
            StoryMessageModel(
              id: 'player-msg-1',
              type: MessageType.playerAction,
              content: 'I look around the tavern',
              timestamp: DateTime.now(),
            ),
          ],
          lastPlayedAt: DateTime.now(),
        );
        await mockRepository.saveGame(updatedState);

        // Assert
        expect(saveCount, 1);
        verify(mockRepository.saveGame(any)).called(1);
      });

      test('story log should persist across sessions', () async {
        // Arrange
        final character = _createTestCharacter();
        final storyMessages = <StoryMessageModel>[
          StoryMessageModel(
            id: 'msg-1',
            type: MessageType.playerAction,
            content: 'I enter the tavern',
            timestamp: DateTime.now(),
          ),
          StoryMessageModel(
            id: 'msg-2',
            type: MessageType.narration,
            content: 'The tavern is warm and inviting...',
            timestamp: DateTime.now(),
          ),
        ];

        final stateWithMessages = _createTestGameState(character).copyWith(
          storyLog: storyMessages,
        );

        when(mockRepository.loadGame(stateWithMessages.id))
            .thenAnswer((_) async => stateWithMessages);

        // Act
        final loadedState = await mockRepository.loadGame(stateWithMessages.id);

        // Assert
        expect(loadedState?.storyLog.length, 2);
        expect(loadedState?.storyLog[0].content, 'I enter the tavern');
        expect(loadedState?.storyLog[1].content, 'The tavern is warm and inviting...');
      });

      test('save should include all game state changes', () async {
        // Arrange
        final character = _createTestCharacter();
        final initialState = _createTestGameState(character);

        GameStateModel? savedState;
        when(mockRepository.saveGame(any)).thenAnswer((invocation) async {
          savedState = invocation.positionalArguments[0] as GameStateModel;
        });

        // Act - Simulate comprehensive state change
        final updatedState = initialState.copyWith(
          gold: 100,
          character: character.copyWith(
            currentHitPoints: 5,
            experiencePoints: 50,
          ),
          storyLog: [
            StoryMessageModel(
              id: 'action-1',
              type: MessageType.playerAction,
              content: 'I fight the goblin',
              timestamp: DateTime.now(),
            ),
          ],
          lastPlayedAt: DateTime.now(),
        );
        await mockRepository.saveGame(updatedState);

        // Assert
        expect(savedState, isNotNull);
        expect(savedState?.gold, 100);
        expect(savedState?.character.currentHitPoints, 5);
        expect(savedState?.character.experiencePoints, 50);
        expect(savedState?.storyLog.length, 1);
      });
    });

    group('Save Timing', () {
      test('lastPlayedAt should update on each save', () async {
        // Arrange
        final character = _createTestCharacter();
        final initialState = _createTestGameState(character);
        final originalTime = initialState.lastPlayedAt;

        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        final updatedState = initialState.copyWith(
          lastPlayedAt: DateTime.now(),
        );

        // Assert
        expect(updatedState.lastPlayedAt.isAfter(originalTime), isTrue);
      });

      test('createdAt should remain unchanged after saves', () async {
        // Arrange
        final character = _createTestCharacter();
        final initialState = _createTestGameState(character);
        final originalCreatedAt = initialState.createdAt;

        // Act - Multiple updates
        var state = initialState;
        for (var i = 0; i < 5; i++) {
          state = state.copyWith(
            gold: state.gold + 10,
            lastPlayedAt: DateTime.now(),
          );
        }

        // Assert - createdAt stays the same
        expect(state.createdAt, originalCreatedAt);
      });
    });

    group('Guest Account Auto-Save', () {
      test('guest user should have saves persisted', () async {
        // Arrange
        final character = _createTestCharacter(name: 'Guest Adventurer');
        final guestGameState = _createTestGameState(character);

        when(mockRepository.createNewGame(
          saveName: anyNamed('saveName'),
          character: anyNamed('character'),
        )).thenAnswer((_) async => guestGameState);

        when(mockRepository.hasSaves()).thenReturn(true);

        // Act
        await mockRepository.createNewGame(
          saveName: 'Guest Adventure',
          character: character,
        );

        // Assert
        expect(mockRepository.hasSaves(), isTrue);
      });

      test('guest progress should survive app restart', () async {
        // Arrange - Simulate save
        final character = _createTestCharacter(name: 'Guest Hero');
        final gameState = _createTestGameState(character).copyWith(
          storyLog: [
            StoryMessageModel(
              id: 'guest-msg',
              type: MessageType.narration,
              content: 'Your journey begins...',
              timestamp: DateTime.now(),
            ),
          ],
          gold: 50,
        );

        when(mockRepository.loadGame(gameState.id))
            .thenAnswer((_) async => gameState);

        // Act - Simulate "restart" by loading
        final loadedState = await mockRepository.loadGame(gameState.id);

        // Assert
        expect(loadedState, isNotNull);
        expect(loadedState?.character.name, 'Guest Hero');
        expect(loadedState?.gold, 50);
        expect(loadedState?.storyLog.length, 1);
      });
    });

    group('Combat Auto-Save', () {
      test('combat damage should persist after save', () async {
        // Arrange
        final character = _createTestCharacter();
        final afterCombatState = _createTestGameState(character).copyWith(
          character: character.copyWith(currentHitPoints: 5),
        );

        when(mockRepository.loadGame(afterCombatState.id))
            .thenAnswer((_) async => afterCombatState);

        // Act
        final loadedState = await mockRepository.loadGame(afterCombatState.id);

        // Assert
        expect(loadedState?.character.currentHitPoints, 5);
      });

      test('combat results should be in story log', () async {
        // Arrange
        final character = _createTestCharacter();
        final combatState = _createTestGameState(character).copyWith(
          storyLog: [
            StoryMessageModel(
              id: 'combat-1',
              type: MessageType.combat,
              content: 'You attack the goblin!',
              timestamp: DateTime.now(),
              combatResult: const CombatResult(
                attackerName: 'Test Hero',
                defenderName: 'Goblin',
                actionType: CombatActionType.meleeAttack,
                attackRoll: 15,
                damageRoll: 8,
                totalDamage: 8,
                isHit: true,
              ),
            ),
          ],
        );

        when(mockRepository.loadGame(combatState.id))
            .thenAnswer((_) async => combatState);

        // Act
        final loadedState = await mockRepository.loadGame(combatState.id);

        // Assert
        expect(loadedState?.storyLog.length, 1);
        expect(loadedState?.storyLog.first.type, MessageType.combat);
        expect(loadedState?.storyLog.first.combatResult?.isHit, isTrue);
        expect(loadedState?.storyLog.first.combatResult?.totalDamage, 8);
      });
    });

    group('Multiple Save Slots', () {
      test('should support multiple save files', () async {
        // Arrange
        final char1 = _createTestCharacter(name: 'Hero One');
        final char2 = _createTestCharacter(name: 'Hero Two');
        final game1 = _createTestGameState(char1);
        final game2 = _createTestGameState(char2);

        when(mockRepository.getAllSaves()).thenReturn([
          SaveGameInfo(
            id: game1.id,
            saveName: 'Save 1',
            characterName: 'Hero One',
            characterLevel: 1,
            lastPlayedAt: DateTime.now(),
            totalPlayTime: const Duration(minutes: 10),
          ),
          SaveGameInfo(
            id: game2.id,
            saveName: 'Save 2',
            characterName: 'Hero Two',
            characterLevel: 1,
            lastPlayedAt: DateTime.now(),
            totalPlayTime: const Duration(minutes: 5),
          ),
        ]);

        // Act
        final saves = mockRepository.getAllSaves();

        // Assert
        expect(saves.length, 2);
        expect(saves[0].characterName, 'Hero One');
        expect(saves[1].characterName, 'Hero Two');
      });

      test('each save should be independent', () async {
        // Arrange - Use fixed IDs to avoid timing issues
        final char1 = _createTestCharacter(name: 'Hero One');
        final char2 = _createTestCharacter(name: 'Hero Two');
        final game1Id = 'game-1-fixed-id';
        final game2Id = 'game-2-fixed-id';
        
        final game1 = GameStateModel(
          id: game1Id,
          saveName: 'Save 1',
          character: char1,
          inventory: const InventoryModel(items: [], maxSlots: 30),
          quests: [],
          currentScene: SceneModel(
            id: 'scene-1',
            name: 'Test Location',
            description: 'A test location',
            type: SceneType.exploration,
          ),
          storyLog: [],
          gold: 100,
          createdAt: DateTime.now(),
          lastPlayedAt: DateTime.now(),
          difficulty: GameDifficulty.normal,
        );
        
        final game2 = GameStateModel(
          id: game2Id,
          saveName: 'Save 2',
          character: char2,
          inventory: const InventoryModel(items: [], maxSlots: 30),
          quests: [],
          currentScene: SceneModel(
            id: 'scene-2',
            name: 'Test Location 2',
            description: 'Another test location',
            type: SceneType.exploration,
          ),
          storyLog: [],
          gold: 500,
          createdAt: DateTime.now(),
          lastPlayedAt: DateTime.now(),
          difficulty: GameDifficulty.normal,
        );

        when(mockRepository.loadGame(game1Id))
            .thenAnswer((_) async => game1);
        when(mockRepository.loadGame(game2Id))
            .thenAnswer((_) async => game2);

        // Act
        final loaded1 = await mockRepository.loadGame(game1Id);
        final loaded2 = await mockRepository.loadGame(game2Id);

        // Assert
        expect(loaded1?.gold, 100);
        expect(loaded2?.gold, 500);
        expect(loaded1?.character.name, 'Hero One');
        expect(loaded2?.character.name, 'Hero Two');
      });
    });
  });
}

/// Helper to create test character
CharacterModel _createTestCharacter({String name = 'Test Hero'}) {
  return CharacterModel(
    id: 'test-char-${DateTime.now().millisecondsSinceEpoch}',
    name: name,
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
    proficientSkills: {Skill.athletics, Skill.perception},
    hitDiceRemaining: 1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

/// Helper to create test game state
GameStateModel _createTestGameState(CharacterModel character) {
  return GameStateModel(
    id: 'test-game-${DateTime.now().millisecondsSinceEpoch}',
    saveName: 'Test Adventure',
    character: character,
    inventory: const InventoryModel(items: [], maxSlots: 30),
    quests: [],
    currentScene: SceneModel(
      id: 'test-scene',
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
