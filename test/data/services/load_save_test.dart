import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/core/constants/game_constants.dart';
import 'package:dnd_ai_game/data/models/story_message_model.dart';
import 'package:dnd_ai_game/data/models/game_state_model.dart';
import 'package:dnd_ai_game/data/models/character_model.dart';
import 'package:dnd_ai_game/data/services/story_summarizer_service.dart';

@GenerateMocks([Dio])
import 'load_save_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Load Save Tests', () {
    late MockDio mockDio;
    late StorySummarizerService summarizer;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDio = MockDio();
      when(mockDio.options).thenReturn(BaseOptions());
      
      summarizer = StorySummarizerService(
        config: const SummarizerConfig(
          minMessagesBeforeSummary: 15,
          recentMessagesToKeep: 5,
          ollamaUrl: 'http://localhost:11434',
          model: 'qwen2.5:3b-instruct',
        ),
        apiBaseUrl: 'http://localhost:3002',
        dio: mockDio,
      );
    });

    group('Game State Loading', () {
      test('should load game state with existing summary', () async {
        // Mock the API to return a summary
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/saves/save-123/summary'),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'summary-123',
              'save_id': 'save-123',
              'summary': 'The hero explored the tavern and found a mysterious map.',
              'messages_summarized': 20,
              'start_turn': 0,
              'end_turn': 19,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        final result = await summarizer.getStorySummary('save-123');

        expect(result, isNotNull);
        expect(result!.summary, 'The hero explored the tavern and found a mysterious map.');
        expect(result.messagesSummarized, 20);
      });

      test('should load game state without existing summary', () async {
        // Mock the API to return no summary
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/saves/save-123/summary'),
          statusCode: 200,
          data: {'summary': null, 'message': 'No summary yet'},
        ));

        final result = await summarizer.getStorySummary('save-123');

        expect(result, isNull);
      });

      test('should handle API error gracefully during load', () async {
        // Mock the API to throw an error
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/saves/save-123/summary'),
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        ));

        final result = await summarizer.getStorySummary('save-123');

        // Should return null instead of throwing
        expect(result, isNull);
      });
    });

    group('Story Log Integration', () {
      test('should build context with loaded summary and story log', () {
        final gameState = _createGameStateWithLog(25);
        const summary = 'The hero met a mysterious stranger who gave them a quest.';
        
        final context = summarizer.buildOptimizedContext(
          gameState: gameState,
          summary: summary,
        );
        
        // Should contain the summary
        expect(context, contains(summary));
        
        // Should contain recent events section
        expect(context, contains('=== RECENT EVENTS'));
      });

      test('should only include recent messages when loading with summary', () {
        final gameState = _createGameStateWithLog(50);
        const summary = 'Long story summary of 50 messages.';
        
        final context = summarizer.buildOptimizedContext(
          gameState: gameState,
          summary: summary,
        );
        
        // Count message occurrences (rough estimate)
        // Should only have ~5 recent messages, not all 50
        final lines = context.split('\n').where((l) => l.contains('Player:') || l.contains('DM:')).length;
        expect(lines, lessThanOrEqualTo(10)); // 5 player + 5 DM max
      });

      test('should include all messages when no summary exists', () {
        final gameState = _createGameStateWithLog(10);
        
        final context = summarizer.buildOptimizedContext(
          gameState: gameState,
          summary: null,
        );
        
        // Without summary, recent events should still be included
        expect(context, contains('=== RECENT EVENTS'));
      });
    });

    group('State Transitions', () {
      test('should handle loading different saves', () async {
        // First save
        when(mockDio.get(
          argThat(contains('save-1')),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'sum-1',
              'summary': 'Summary for save 1',
              'messages_summarized': 10,
              'start_turn': 0,
              'end_turn': 9,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        // Second save  
        when(mockDio.get(
          argThat(contains('save-2')),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'sum-2',
              'summary': 'Summary for save 2',
              'messages_summarized': 20,
              'start_turn': 0,
              'end_turn': 19,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        // Load first save
        summarizer.clearCache();
        final result1 = await summarizer.getStorySummary('save-1');
        expect(result1?.summary, 'Summary for save 1');

        // Load second save
        summarizer.clearCache();
        final result2 = await summarizer.getStorySummary('save-2');
        expect(result2?.summary, 'Summary for save 2');
      });

      test('should clear cache when switching saves', () async {
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'sum-1',
              'summary': 'Original summary',
              'messages_summarized': 10,
              'start_turn': 0,
              'end_turn': 9,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        // Load and cache
        await summarizer.getStorySummary('save-1');
        
        // Clear cache
        summarizer.clearCache();
        
        // Should fetch again (verify by checking call count)
        await summarizer.getStorySummary('save-1');
        
        verify(mockDio.get(any, options: anyNamed('options'))).called(2);
      });
    });

    group('Error Recovery', () {
      test('should recover from failed summary load', () async {
        // First call fails
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ));

        final result1 = await summarizer.getStorySummary('save-123');
        expect(result1, isNull);

        // Clear cache to allow retry
        summarizer.clearCache();
        
        // Second call succeeds
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'sum-123',
              'summary': 'Recovered summary',
              'messages_summarized': 15,
              'start_turn': 0,
              'end_turn': 14,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        final result2 = await summarizer.getStorySummary('save-123');
        expect(result2, isNotNull);
        expect(result2!.summary, 'Recovered summary');
      });

      test('should handle 404 response', () async {
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 404,
          data: {'error': 'Summary not found'},
        ));

        final result = await summarizer.getStorySummary('save-123');
        expect(result, isNull);
      });

      test('should handle malformed response', () async {
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {'unexpected': 'format'},
        ));

        final result = await summarizer.getStorySummary('save-123');
        expect(result, isNull);
      });
    });

    group('Concurrent Loads', () {
      test('should handle rapid load requests', () async {
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async {
          // Simulate network delay
          await Future.delayed(const Duration(milliseconds: 50));
          return Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: {
              'summary': {
                'id': 'sum-1',
                'summary': 'Test summary',
                'messages_summarized': 10,
                'start_turn': 0,
                'end_turn': 9,
                'is_running_summary': true,
                'created_at': '2024-01-01T00:00:00Z',
              },
            },
          );
        });

        // Fire multiple requests
        final futures = [
          summarizer.getStorySummary('save-1'),
          summarizer.getStorySummary('save-1'),
          summarizer.getStorySummary('save-1'),
        ];

        final results = await Future.wait(futures);
        
        // All should succeed
        for (final result in results) {
          expect(result, isNotNull);
          expect(result!.summary, 'Test summary');
        }
      });
    });
  });
}

/// Helper to create a story log with N messages
List<StoryMessageModel> _createStoryLog(int count) {
  final messages = <StoryMessageModel>[];
  
  for (var i = 0; i < count; i++) {
    final isPlayerAction = i % 2 == 0;
    messages.add(StoryMessageModel(
      id: 'msg-$i',
      type: isPlayerAction ? MessageType.playerAction : MessageType.narration,
      content: isPlayerAction 
          ? 'Player action message $i'
          : 'Narration message $i from the DM.',
      timestamp: DateTime.now().subtract(Duration(minutes: count - i)),
    ));
  }
  
  return messages;
}

/// Helper to create a game state with story log
GameStateModel _createGameStateWithLog(int messageCount) {
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
    storyLog: _createStoryLog(messageCount),
    gold: 15,
    createdAt: DateTime.now(),
    lastPlayedAt: DateTime.now(),
    difficulty: GameDifficulty.normal,
  );
}

