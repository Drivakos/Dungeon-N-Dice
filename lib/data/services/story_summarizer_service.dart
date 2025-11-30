import 'package:dio/dio.dart';

import '../models/story_message_model.dart';
import '../models/game_state_model.dart';

/// Configuration for the story summarizer
class SummarizerConfig {
  /// Minimum messages before considering summarization
  final int minMessagesBeforeSummary;
  
  /// Number of recent messages to keep as full context
  final int recentMessagesToKeep;
  
  /// Ollama URL for summarization
  final String ollamaUrl;
  
  /// Model to use for summarization
  final String model;

  const SummarizerConfig({
    this.minMessagesBeforeSummary = 15,
    this.recentMessagesToKeep = 5,
    this.ollamaUrl = 'http://localhost:11434',
    this.model = 'qwen2.5:3b-instruct',
  });
}

/// Result of a summarization check
class SummaryCheckResult {
  final bool shouldSummarize;
  final int messagesNeedingSummary;
  final int totalMessages;

  const SummaryCheckResult({
    required this.shouldSummarize,
    required this.messagesNeedingSummary,
    required this.totalMessages,
  });
}

/// Stored summary info
class StorySummary {
  final String id;
  final String saveId;
  final String summary;
  final int messagesSummarized;
  final int startTurn;
  final int endTurn;
  final bool isRunningSummary;
  final DateTime createdAt;

  const StorySummary({
    required this.id,
    required this.saveId,
    required this.summary,
    required this.messagesSummarized,
    required this.startTurn,
    required this.endTurn,
    required this.isRunningSummary,
    required this.createdAt,
  });

  factory StorySummary.fromJson(Map<String, dynamic> json) {
    return StorySummary(
      id: json['id'] as String,
      saveId: json['save_id'] as String? ?? '',
      summary: json['summary'] as String,
      messagesSummarized: json['messages_summarized'] as int,
      startTurn: json['start_turn'] as int,
      endTurn: json['end_turn'] as int,
      isRunningSummary: json['is_running_summary'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Service for managing story summarization
/// 
/// This service handles:
/// - Checking if summarization is needed
/// - Using AI to summarize story events
/// - Storing summaries in the database
/// - Building optimized context for AI calls
class StorySummarizerService {
  final Dio _dio;
  final SummarizerConfig config;
  final String _apiBaseUrl;
  String? _authToken;
  
  // Cache the current summary to avoid repeated API calls
  StorySummary? _cachedSummary;
  String? _cachedSaveId;

  StorySummarizerService({
    SummarizerConfig? config,
    String? apiBaseUrl,
    Dio? dio,
  }) : config = config ?? const SummarizerConfig(),
       _apiBaseUrl = apiBaseUrl ?? 'http://localhost:3002',
       _dio = dio ?? Dio();

  /// Set auth token for API calls
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Check if the story log needs summarization
  SummaryCheckResult checkShouldSummarize(
    List<StoryMessageModel> storyLog,
    int messagesSummarizedSoFar,
  ) {
    final totalMessages = storyLog.length;
    final unsummarizedMessages = totalMessages - messagesSummarizedSoFar;
    
    return SummaryCheckResult(
      shouldSummarize: unsummarizedMessages >= config.minMessagesBeforeSummary,
      messagesNeedingSummary: unsummarizedMessages,
      totalMessages: totalMessages,
    );
  }

  /// Get the current running summary for a save
  Future<StorySummary?> getStorySummary(String saveId) async {
    // Return cached if same save
    if (_cachedSaveId == saveId && _cachedSummary != null) {
      return _cachedSummary;
    }

    try {
      final response = await _dio.get(
        '$_apiBaseUrl/saves/$saveId/summary',
        options: Options(
          headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
        ),
      );

      if (response.statusCode == 200 && response.data['summary'] != null) {
        _cachedSummary = StorySummary.fromJson(response.data['summary']);
        _cachedSaveId = saveId;
        return _cachedSummary;
      }

      return null;
    } catch (e) {
      print('Get summary error: $e');
      return null;
    }
  }

  /// Summarize story events using AI
  Future<String?> summarizeWithAI(
    List<StoryMessageModel> messages, {
    String? existingSummary,
  }) async {
    if (messages.isEmpty) return existingSummary;

    try {
      // Filter to only narration and important events
      final relevantMessages = messages.where((m) => 
        m.type == MessageType.narration ||
        m.type == MessageType.dialogue ||
        m.type == MessageType.questUpdate ||
        (m.type == MessageType.playerAction && m.isImportant)
      ).toList();

      if (relevantMessages.isEmpty) return existingSummary;

      final prompt = _buildSummaryPrompt(relevantMessages, existingSummary);
      
      final response = await _dio.post(
        '${config.ollamaUrl}/api/generate',
        data: {
          'model': config.model,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.3, // Low temperature for consistency
            'num_predict': 300, // Limit output length
          },
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200 && response.data['response'] != null) {
        return _cleanSummaryResponse(response.data['response'] as String);
      }

      return existingSummary;
    } catch (e) {
      print('AI summarization error: $e');
      return existingSummary;
    }
  }

  /// Store a summary in the database
  Future<StorySummary?> storeSummary({
    required String saveId,
    required String summary,
    required int messagesSummarized,
    required int startTurn,
    required int endTurn,
    bool isRunningSummary = true,
  }) async {
    try {
      final response = await _dio.post(
        '$_apiBaseUrl/saves/$saveId/summary',
        data: {
          'summary': summary,
          'messagesSummarized': messagesSummarized,
          'startTurn': startTurn,
          'endTurn': endTurn,
          'isRunningSummary': isRunningSummary,
        },
        options: Options(
          headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
        ),
      );

      if (response.statusCode == 201 && response.data['summary'] != null) {
        _cachedSummary = StorySummary.fromJson(response.data['summary']);
        _cachedSaveId = saveId;
        return _cachedSummary;
      }

      return null;
    } catch (e) {
      print('Store summary error: $e');
      return null;
    }
  }

  /// Update an existing running summary
  Future<StorySummary?> updateSummary({
    required String saveId,
    required String summary,
    int? messagesSummarized,
    int? endTurn,
  }) async {
    try {
      final response = await _dio.put(
        '$_apiBaseUrl/saves/$saveId/summary',
        data: {
          'summary': summary,
          if (messagesSummarized != null) 'messagesSummarized': messagesSummarized,
          if (endTurn != null) 'endTurn': endTurn,
        },
        options: Options(
          headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : null,
        ),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && 
          response.data['summary'] != null) {
        _cachedSummary = StorySummary.fromJson(response.data['summary']);
        _cachedSaveId = saveId;
        return _cachedSummary;
      }

      return null;
    } catch (e) {
      print('Update summary error: $e');
      return null;
    }
  }

  /// Perform full summarization flow: check, summarize, store
  Future<String?> summarizeAndStore({
    required String saveId,
    required List<StoryMessageModel> storyLog,
    String? existingSummary,
    int messagesSummarizedSoFar = 0,
  }) async {
    // Get messages that haven't been summarized yet
    final messagesToSummarize = storyLog.skip(messagesSummarizedSoFar).toList();
    
    if (messagesToSummarize.isEmpty) {
      return existingSummary;
    }

    // Generate new summary
    final newSummary = await summarizeWithAI(
      messagesToSummarize,
      existingSummary: existingSummary,
    );

    if (newSummary == null || newSummary.isEmpty) {
      return existingSummary;
    }

    // Store in database
    final startTurn = messagesSummarizedSoFar;
    final endTurn = storyLog.length - 1;

    if (existingSummary != null && existingSummary.isNotEmpty) {
      // Update existing
      await updateSummary(
        saveId: saveId,
        summary: newSummary,
        messagesSummarized: storyLog.length,
        endTurn: endTurn,
      );
    } else {
      // Create new
      await storeSummary(
        saveId: saveId,
        summary: newSummary,
        messagesSummarized: storyLog.length,
        startTurn: startTurn,
        endTurn: endTurn,
        isRunningSummary: true,
      );
    }

    return newSummary;
  }

  /// Build optimized context for AI using summary + recent messages
  String buildOptimizedContext({
    required GameStateModel gameState,
    String? summary,
  }) {
    final storyLog = gameState.storyLog;
    final recentMessages = storyLog.reversed
        .take(config.recentMessagesToKeep)
        .toList()
        .reversed
        .toList();

    final buffer = StringBuffer();

    // Add summary if available
    if (summary != null && summary.isNotEmpty) {
      buffer.writeln('=== STORY SO FAR ===');
      buffer.writeln(summary);
      buffer.writeln();
    }

    // Add recent messages
    if (recentMessages.isNotEmpty) {
      buffer.writeln('=== RECENT EVENTS (continue from here) ===');
      for (final msg in recentMessages) {
        if (msg.type == MessageType.playerAction) {
          buffer.writeln('Player: ${msg.content}');
        } else if (msg.type == MessageType.narration || msg.type == MessageType.dialogue) {
          buffer.writeln('DM: ${msg.content}');
        }
      }
    }

    return buffer.toString();
  }

  /// Build the prompt for AI summarization
  String _buildSummaryPrompt(
    List<StoryMessageModel> messages,
    String? existingSummary,
  ) {
    final eventsText = messages.map((m) {
      final prefix = m.type == MessageType.playerAction ? 'Player' : 'Story';
      return '$prefix: ${m.content}';
    }).join('\n');

    if (existingSummary != null && existingSummary.isNotEmpty) {
      return '''You are summarizing a D&D adventure story. You have a previous summary and new events.

PREVIOUS SUMMARY:
$existingSummary

NEW EVENTS TO ADD:
$eventsText

Create an updated summary that combines the previous summary with the new events.
Keep it to 3-4 sentences maximum.
Focus on: key plot points, important NPCs met, locations visited, and major player decisions.
Do NOT include combat details, dice rolls, or game mechanics.

Write ONLY the summary, no introduction or explanation.''';
    }

    return '''Summarize these D&D adventure events in 2-3 sentences.
Focus on: key plot points, important NPCs met, locations visited, and major player decisions.
Do NOT include combat details, dice rolls, or game mechanics.

EVENTS:
$eventsText

Write ONLY the summary, no introduction or explanation.''';
  }

  /// Clean up the AI response to get just the summary
  String _cleanSummaryResponse(String response) {
    // Remove any JSON formatting if present
    var cleaned = response.trim();
    
    // Remove common prefixes
    final prefixes = [
      'Summary:', 'SUMMARY:', 'Here is the summary:', 
      'Updated summary:', 'The summary is:',
    ];
    
    for (final prefix in prefixes) {
      if (cleaned.toLowerCase().startsWith(prefix.toLowerCase())) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }
    
    // Remove quotes if wrapped
    if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
        (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    
    return cleaned.trim();
  }

  /// Clear cached summary (call when switching saves)
  void clearCache() {
    _cachedSummary = null;
    _cachedSaveId = null;
  }
}

