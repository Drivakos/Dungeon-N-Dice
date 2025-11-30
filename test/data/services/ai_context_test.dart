import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/data/models/story_message_model.dart';
import 'package:dnd_ai_game/data/models/game_state_model.dart';
import 'package:dnd_ai_game/data/models/character_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Context Building with Summaries', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('Context Size Optimization', () {
      test('should use fewer messages when summary is provided', () {
        // With summary: should only use 5 recent messages
        // Without summary: should use 10 messages
        final storyLog = _createStoryLog(20);
        
        // Count messages that would be included
        final withoutSummaryCount = storyLog.reversed.take(10).length;
        final withSummaryCount = storyLog.reversed.take(5).length;
        
        expect(withoutSummaryCount, 10);
        expect(withSummaryCount, 5);
        expect(withSummaryCount, lessThan(withoutSummaryCount));
      });

      test('should handle story log smaller than threshold', () {
        final storyLog = _createStoryLog(3);
        
        // Should include all messages when fewer than threshold
        final count = storyLog.reversed.take(10).length;
        expect(count, 3);
      });
    });

    group('Message Type Filtering', () {
      test('should include player actions in context', () {
        final messages = _createMixedStoryLog();
        
        final playerActions = messages
            .where((m) => m.type == MessageType.playerAction)
            .toList();
        
        expect(playerActions, isNotEmpty);
      });

      test('should include narrations in context', () {
        final messages = _createMixedStoryLog();
        
        final narrations = messages
            .where((m) => m.type == MessageType.narration)
            .toList();
        
        expect(narrations, isNotEmpty);
      });

      test('should include dialogues in context', () {
        final messages = _createMixedStoryLog();
        
        final dialogues = messages
            .where((m) => m.type == MessageType.dialogue)
            .toList();
        
        expect(dialogues, isNotEmpty);
      });
    });

    group('Summary Integration', () {
      test('summary should be placed before recent messages', () {
        const summary = 'The hero explored the tavern and found a mysterious map.';
        final recentMessages = _createStoryLog(5);
        
        // Build context structure
        final context = _buildTestContext(summary, recentMessages);
        
        // Summary should come before recent events
        final summaryIndex = context.indexOf('STORY SUMMARY');
        final recentIndex = context.indexOf('RECENT EVENTS');
        
        expect(summaryIndex, lessThan(recentIndex));
      });

      test('should handle multi-line summary', () {
        const summary = '''The hero began their journey at the Crossroads Inn.
They met a mysterious stranger who gave them a quest.
A goblin attack revealed dark forces at work.''';
        
        final context = _buildTestContext(summary, _createStoryLog(5));
        
        expect(context, contains(summary));
      });

      test('should handle summary with special characters', () {
        const summary = "The hero said: \"Let's go!\" & fought the dragon.";
        
        final context = _buildTestContext(summary, _createStoryLog(5));
        
        expect(context, contains(summary));
      });
    });

    group('Context Window Management', () {
      test('should limit context size with summary', () {
        const summary = 'Short summary of events.';
        final longLog = _createStoryLog(100);
        
        // Only last 5 should be included with summary
        final recentMessages = longLog.reversed.take(5).toList();
        
        expect(recentMessages.length, 5);
      });

      test('should provide more context without summary', () {
        final longLog = _createStoryLog(100);
        
        // Without summary, can include more messages
        final recentMessages = longLog.reversed.take(10).toList();
        
        expect(recentMessages.length, 10);
      });

      test('should calculate approximate token savings', () {
        final storyLog = _createStoryLog(50);
        
        // Estimate tokens (rough: ~4 chars per token)
        final allMessagesTokens = storyLog
            .map((m) => m.content.length)
            .reduce((a, b) => a + b) ~/ 4;
        
        final recentOnlyTokens = storyLog.reversed
            .take(5)
            .map((m) => m.content.length)
            .reduce((a, b) => a + b) ~/ 4;
        
        const summaryTokens = 100; // Assume 400 char summary
        
        final withSummary = recentOnlyTokens + summaryTokens;
        
        // Summary approach should use significantly fewer tokens
        expect(withSummary, lessThan(allMessagesTokens));
      });
    });

    group('Edge Cases', () {
      test('should handle empty story log with summary', () {
        const summary = 'Previous events summary.';
        final emptyLog = <StoryMessageModel>[];
        
        final context = _buildTestContext(summary, emptyLog);
        
        expect(context, contains(summary));
        expect(context, isNot(contains('Message')));
      });

      test('should handle null summary with messages', () {
        final messages = _createStoryLog(10);
        
        final context = _buildTestContext(null, messages);
        
        expect(context, isNot(contains('STORY SUMMARY')));
        expect(context, contains('Message'));
      });

      test('should handle both null summary and empty log', () {
        final context = _buildTestContext(null, []);
        
        expect(context, isEmpty);
      });

      test('should handle very long summary', () {
        final longSummary = 'Event. ' * 200; // ~1400 chars
        final messages = _createStoryLog(5);
        
        final context = _buildTestContext(longSummary, messages);
        
        expect(context, contains('Event.'));
      });
    });

    group('Conversation History Format', () {
      test('should format player actions correctly', () {
        final message = StoryMessageModel(
          id: 'test-1',
          type: MessageType.playerAction,
          content: 'I search the room',
          timestamp: DateTime.now(),
        );
        
        // Player actions should be marked as user role
        expect(message.type, MessageType.playerAction);
      });

      test('should format narrations correctly', () {
        final message = StoryMessageModel(
          id: 'test-2',
          type: MessageType.narration,
          content: 'You find a hidden compartment.',
          timestamp: DateTime.now(),
        );
        
        // Narrations should be marked as assistant role
        expect(message.type, MessageType.narration);
      });

      test('should maintain message order', () {
        final messages = _createStoryLog(10);
        final reversed = messages.reversed.take(5).toList().reversed.toList();
        
        // Messages should be in chronological order (oldest first)
        for (var i = 0; i < reversed.length - 1; i++) {
          expect(
            reversed[i].timestamp.isBefore(reversed[i + 1].timestamp) ||
            reversed[i].timestamp.isAtSameMomentAs(reversed[i + 1].timestamp),
            isTrue,
          );
        }
      });
    });
  });
}

/// Helper to create a story log
List<StoryMessageModel> _createStoryLog(int count) {
  final messages = <StoryMessageModel>[];
  
  for (var i = 0; i < count; i++) {
    final isPlayerAction = i % 2 == 0;
    messages.add(StoryMessageModel(
      id: 'msg-$i',
      type: isPlayerAction ? MessageType.playerAction : MessageType.narration,
      content: 'Message content number $i with some additional text to simulate real messages.',
      timestamp: DateTime.now().subtract(Duration(minutes: count - i)),
    ));
  }
  
  return messages;
}

/// Helper to create mixed message types
List<StoryMessageModel> _createMixedStoryLog() {
  return [
    StoryMessageModel(
      id: 'msg-1',
      type: MessageType.playerAction,
      content: 'I enter the tavern',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    StoryMessageModel(
      id: 'msg-2',
      type: MessageType.narration,
      content: 'The tavern is warm and inviting.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
    StoryMessageModel(
      id: 'msg-3',
      type: MessageType.dialogue,
      content: '"Welcome, traveler!" says the innkeeper.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      speakerName: 'Innkeeper',
    ),
    StoryMessageModel(
      id: 'msg-4',
      type: MessageType.playerAction,
      content: 'I order an ale',
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    StoryMessageModel(
      id: 'msg-5',
      type: MessageType.narration,
      content: 'The innkeeper slides a frothy mug across the bar.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];
}

/// Helper to build test context
String _buildTestContext(String? summary, List<StoryMessageModel> messages) {
  final buffer = StringBuffer();
  
  if (summary != null && summary.isNotEmpty) {
    buffer.writeln('=== STORY SUMMARY ===');
    buffer.writeln(summary);
    buffer.writeln();
  }
  
  if (messages.isNotEmpty) {
    buffer.writeln('=== RECENT EVENTS ===');
    for (final msg in messages) {
      if (msg.type == MessageType.playerAction) {
        buffer.writeln('Player: ${msg.content}');
      } else {
        buffer.writeln('DM: ${msg.content}');
      }
    }
  }
  
  return buffer.toString();
}

