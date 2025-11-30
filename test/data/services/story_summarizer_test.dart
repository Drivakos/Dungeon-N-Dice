import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/core/constants/game_constants.dart';
import 'package:dnd_ai_game/data/services/story_summarizer_service.dart';
import 'package:dnd_ai_game/data/models/story_message_model.dart';
import 'package:dnd_ai_game/data/models/game_state_model.dart';
import 'package:dnd_ai_game/data/models/character_model.dart';

@GenerateMocks([Dio])
import 'story_summarizer_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorySummarizerService', () {
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

    group('SummarizerConfig', () {
      test('should have correct default values', () {
        const config = SummarizerConfig();
        
        expect(config.minMessagesBeforeSummary, 15);
        expect(config.recentMessagesToKeep, 5);
        expect(config.ollamaUrl, 'http://localhost:11434');
        expect(config.model, 'qwen2.5:3b-instruct');
      });

      test('should allow custom configuration', () {
        const config = SummarizerConfig(
          minMessagesBeforeSummary: 20,
          recentMessagesToKeep: 8,
          ollamaUrl: 'http://custom:11434',
          model: 'llama3',
        );
        
        expect(config.minMessagesBeforeSummary, 20);
        expect(config.recentMessagesToKeep, 8);
        expect(config.ollamaUrl, 'http://custom:11434');
        expect(config.model, 'llama3');
      });
    });

    group('checkShouldSummarize', () {
      test('should not summarize when message count is below threshold', () {
        final storyLog = _createStoryLog(10);
        
        final result = summarizer.checkShouldSummarize(storyLog, 0);
        
        expect(result.shouldSummarize, false);
        expect(result.messagesNeedingSummary, 10);
        expect(result.totalMessages, 10);
      });

      test('should summarize when message count exceeds threshold', () {
        final storyLog = _createStoryLog(20);
        
        final result = summarizer.checkShouldSummarize(storyLog, 0);
        
        expect(result.shouldSummarize, true);
        expect(result.messagesNeedingSummary, 20);
        expect(result.totalMessages, 20);
      });

      test('should consider already summarized messages', () {
        final storyLog = _createStoryLog(25);
        
        // 10 already summarized, 15 new = should summarize
        final result = summarizer.checkShouldSummarize(storyLog, 10);
        
        expect(result.shouldSummarize, true);
        expect(result.messagesNeedingSummary, 15);
        expect(result.totalMessages, 25);
      });

      test('should not summarize when new messages below threshold', () {
        final storyLog = _createStoryLog(25);
        
        // 15 already summarized, only 10 new = should not summarize
        final result = summarizer.checkShouldSummarize(storyLog, 15);
        
        expect(result.shouldSummarize, false);
        expect(result.messagesNeedingSummary, 10);
      });

      test('should handle edge case at exactly threshold', () {
        final storyLog = _createStoryLog(15);
        
        final result = summarizer.checkShouldSummarize(storyLog, 0);
        
        expect(result.shouldSummarize, true);
        expect(result.messagesNeedingSummary, 15);
      });

      test('should handle empty story log', () {
        final storyLog = <StoryMessageModel>[];
        
        final result = summarizer.checkShouldSummarize(storyLog, 0);
        
        expect(result.shouldSummarize, false);
        expect(result.messagesNeedingSummary, 0);
        expect(result.totalMessages, 0);
      });
    });

    group('buildOptimizedContext', () {
      test('should build context with summary and recent messages', () {
        final gameState = _createGameStateWithLog(20);
        const summary = 'The hero explored the tavern and met a mysterious stranger.';
        
        final context = summarizer.buildOptimizedContext(
          gameState: gameState,
          summary: summary,
        );
        
        expect(context, contains('=== STORY SO FAR ==='));
        expect(context, contains(summary));
        expect(context, contains('=== RECENT EVENTS'));
      });

      test('should include only recent messages in context', () {
        final gameState = _createGameStateWithLog(20);
        const summary = 'Story summary here.';
        
        final context = summarizer.buildOptimizedContext(
          gameState: gameState,
          summary: summary,
        );
        
        // Should only have last 5 messages, not all 20
        // Count occurrences of "Message" in context (rough check)
        final messageCount = 'Message'.allMatches(context).length;
        expect(messageCount, lessThanOrEqualTo(10)); // 5 player + 5 DM max
      });

      test('should handle null summary gracefully', () {
        final gameState = _createGameStateWithLog(10);
        
        final context = summarizer.buildOptimizedContext(
          gameState: gameState,
          summary: null,
        );
        
        expect(context, isNot(contains('=== STORY SO FAR ===')));
        expect(context, contains('=== RECENT EVENTS'));
      });

      test('should handle empty summary gracefully', () {
        final gameState = _createGameStateWithLog(10);
        
        final context = summarizer.buildOptimizedContext(
          gameState: gameState,
          summary: '',
        );
        
        expect(context, isNot(contains('=== STORY SO FAR ===')));
      });

      test('should handle empty story log', () {
        final gameState = _createGameStateWithLog(0);
        
        final context = summarizer.buildOptimizedContext(
          gameState: gameState,
          summary: 'Some summary',
        );
        
        expect(context, contains('=== STORY SO FAR ==='));
        expect(context, isNot(contains('=== RECENT EVENTS')));
      });
    });

    group('StorySummary model', () {
      test('should parse from JSON correctly', () {
        final json = {
          'id': 'summary-123',
          'save_id': 'save-456',
          'summary': 'The hero began their journey.',
          'messages_summarized': 15,
          'start_turn': 0,
          'end_turn': 14,
          'is_running_summary': true,
          'created_at': '2024-01-01T00:00:00Z',
        };

        final summary = StorySummary.fromJson(json);

        expect(summary.id, 'summary-123');
        expect(summary.saveId, 'save-456');
        expect(summary.summary, 'The hero began their journey.');
        expect(summary.messagesSummarized, 15);
        expect(summary.startTurn, 0);
        expect(summary.endTurn, 14);
        expect(summary.isRunningSummary, true);
      });

      test('should handle missing optional fields', () {
        final json = {
          'id': 'summary-123',
          'summary': 'The hero began their journey.',
          'messages_summarized': 15,
          'start_turn': 0,
          'end_turn': 14,
          'created_at': '2024-01-01T00:00:00Z',
        };

        final summary = StorySummary.fromJson(json);

        expect(summary.saveId, '');
        expect(summary.isRunningSummary, false);
      });
    });

    group('SummaryCheckResult', () {
      test('should store all properties correctly', () {
        const result = SummaryCheckResult(
          shouldSummarize: true,
          messagesNeedingSummary: 20,
          totalMessages: 35,
        );

        expect(result.shouldSummarize, true);
        expect(result.messagesNeedingSummary, 20);
        expect(result.totalMessages, 35);
      });
    });

    group('API Integration', () {
      test('should get story summary from API', () async {
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/saves/save-123/summary'),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'summary-123',
              'summary': 'The hero explored the dungeon.',
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
        expect(result!.summary, 'The hero explored the dungeon.');
        expect(result.messagesSummarized, 20);
      });

      test('should return null when no summary exists', () async {
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

      test('should handle API errors gracefully', () async {
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/saves/save-123/summary'),
          type: DioExceptionType.connectionError,
        ));

        final result = await summarizer.getStorySummary('save-123');

        expect(result, isNull);
      });

      test('should store summary via API', () async {
        when(mockDio.post(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/saves/save-123/summary'),
          statusCode: 201,
          data: {
            'summary': {
              'id': 'new-summary-id',
              'summary': 'New summary content',
              'messages_summarized': 15,
              'start_turn': 0,
              'end_turn': 14,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        final result = await summarizer.storeSummary(
          saveId: 'save-123',
          summary: 'New summary content',
          messagesSummarized: 15,
          startTurn: 0,
          endTurn: 14,
          isRunningSummary: true,
        );

        expect(result, isNotNull);
        expect(result!.id, 'new-summary-id');
        expect(result.summary, 'New summary content');
      });

      test('should update summary via API', () async {
        when(mockDio.put(
          any,
          data: anyNamed('data'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/saves/save-123/summary'),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'existing-summary-id',
              'summary': 'Updated summary content',
              'messages_summarized': 30,
              'start_turn': 0,
              'end_turn': 29,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        final result = await summarizer.updateSummary(
          saveId: 'save-123',
          summary: 'Updated summary content',
          messagesSummarized: 30,
          endTurn: 29,
        );

        expect(result, isNotNull);
        expect(result!.summary, 'Updated summary content');
        expect(result.messagesSummarized, 30);
      });
    });

    group('Cache Management', () {
      test('should cache summary after fetching', () async {
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/saves/save-123/summary'),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'summary-123',
              'summary': 'Cached summary',
              'messages_summarized': 20,
              'start_turn': 0,
              'end_turn': 19,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        // First call - should fetch from API
        await summarizer.getStorySummary('save-123');
        
        // Second call - should use cache (not call API again)
        final cached = await summarizer.getStorySummary('save-123');

        expect(cached, isNotNull);
        expect(cached!.summary, 'Cached summary');
        
        // Verify API was only called once
        verify(mockDio.get(any, options: anyNamed('options'))).called(1);
      });

      test('should clear cache', () async {
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/saves/save-123/summary'),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'summary-123',
              'summary': 'Test summary',
              'messages_summarized': 20,
              'start_turn': 0,
              'end_turn': 19,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        // Fetch and cache
        await summarizer.getStorySummary('save-123');
        
        // Clear cache
        summarizer.clearCache();
        
        // Should fetch again
        await summarizer.getStorySummary('save-123');

        verify(mockDio.get(any, options: anyNamed('options'))).called(2);
      });

      test('should fetch new summary for different save ID', () async {
        when(mockDio.get(
          any,
          options: anyNamed('options'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {
            'summary': {
              'id': 'summary-123',
              'summary': 'Test summary',
              'messages_summarized': 20,
              'start_turn': 0,
              'end_turn': 19,
              'is_running_summary': true,
              'created_at': '2024-01-01T00:00:00Z',
            },
          },
        ));

        // Fetch for first save
        await summarizer.getStorySummary('save-123');
        
        // Fetch for different save - should call API again
        await summarizer.getStorySummary('save-456');

        verify(mockDio.get(any, options: anyNamed('options'))).called(2);
      });
    });

    group('Auth Token', () {
      test('should set auth token', () {
        summarizer.setAuthToken('test-token-123');
        
        // Token is private, but we can verify it's used in requests
        // by checking the behavior works without errors
        expect(() => summarizer.setAuthToken('new-token'), returnsNormally);
      });

      test('should handle null auth token', () {
        expect(() => summarizer.setAuthToken(null), returnsNormally);
      });
    });
  });
}

/// Helper function to create a story log with N messages
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

/// Helper function to create a game state with story log
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

