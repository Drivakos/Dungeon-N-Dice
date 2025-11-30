import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../models/game_state_model.dart';
import '../models/story_message_model.dart';
import '../models/ai_response_model.dart';

/// Configuration for the memory database
/// 
/// In production, pass these values from environment variables or secure storage.
/// Default values are for local development only.
class MemoryDatabaseConfig {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final String ollamaUrl;
  final String embeddingModel;
  final int embeddingDimensions;

  const MemoryDatabaseConfig({
    this.host = 'localhost',
    this.port = 5432,
    this.database = 'dnd_adventure',
    this.username = 'dnd_admin',
    this.password = '', // Set via environment or secure storage
    this.ollamaUrl = 'http://localhost:11434',
    this.embeddingModel = 'nomic-embed-text', // Best quality local embedding model
    this.embeddingDimensions = 768, // nomic-embed-text uses 768 dimensions
  });

  String get connectionString => 
      'postgresql://$username:$password@$host:$port/$database';
}

/// Memory types for categorization
enum MemoryType {
  event('event'),
  npcInteraction('npc_interaction'),
  location('location'),
  quest('quest'),
  combat('combat'),
  discovery('discovery'),
  dialogue('dialogue'),
  playerAction('player_action');

  final String value;
  const MemoryType(this.value);
}

/// A memory entry for storage
class MemoryEntry {
  final String id;
  final String saveId;
  final String content;
  final String? summary;
  final MemoryType type;
  final int importance;
  final List<double>? embedding;
  final String? location;
  final List<String>? involvedNpcs;
  final List<String>? involvedItems;
  final List<String>? tags;
  final int? turnNumber;
  final bool isPlayerAction;
  final DateTime createdAt;

  MemoryEntry({
    String? id,
    required this.saveId,
    required this.content,
    this.summary,
    required this.type,
    this.importance = 5,
    this.embedding,
    this.location,
    this.involvedNpcs,
    this.involvedItems,
    this.tags,
    this.turnNumber,
    this.isPlayerAction = false,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'save_id': saveId,
    'content': content,
    'summary': summary,
    'memory_type': type.value,
    'importance': importance,
    'embedding': embedding,
    'location': location,
    'involved_npcs': involvedNpcs,
    'involved_items': involvedItems,
    'tags': tags,
    'turn_number': turnNumber,
    'is_player_action': isPlayerAction,
    'created_at': createdAt.toIso8601String(),
  };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    return MemoryEntry(
      id: json['id'] as String,
      saveId: json['save_id'] as String,
      content: json['content'] as String,
      summary: json['summary'] as String?,
      type: MemoryType.values.firstWhere(
        (t) => t.value == json['memory_type'],
        orElse: () => MemoryType.event,
      ),
      importance: json['importance'] as int? ?? 5,
      embedding: (json['embedding'] as List<dynamic>?)?.cast<double>(),
      location: json['location'] as String?,
      involvedNpcs: (json['involved_npcs'] as List<dynamic>?)?.cast<String>(),
      involvedItems: (json['involved_items'] as List<dynamic>?)?.cast<String>(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      turnNumber: json['turn_number'] as int?,
      isPlayerAction: json['is_player_action'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Search result with similarity score
class MemorySearchResult {
  final MemoryEntry memory;
  final double similarity;

  const MemorySearchResult({
    required this.memory,
    required this.similarity,
  });
}

/// Service for managing game memories and RAG
class MemoryService {
  final MemoryDatabaseConfig config;
  final Dio _dio;
  final Uuid _uuid;
  
  // In-memory cache for when DB is not available
  final Map<String, List<MemoryEntry>> _memoryCache = {};
  final Map<String, List<Map<String, dynamic>>> _chatCache = {};
  
  bool _useDatabase = false;
  String? _currentSaveId;
  int _turnCounter = 0;

  MemoryService({
    MemoryDatabaseConfig? config,
    Dio? dio,
  }) : config = config ?? const MemoryDatabaseConfig(),
       _dio = dio ?? Dio(),
       _uuid = const Uuid();

  /// Initialize the service and check database connection
  Future<bool> initialize() async {
    try {
      // For now, we'll use a REST API approach via Supabase or a simple backend
      // In production, you'd use postgres package directly
      _useDatabase = await _checkDatabaseConnection();
      return _useDatabase;
    } catch (e) {
      print('Memory service initialization failed: $e');
      _useDatabase = false;
      return false;
    }
  }

  /// Check if database is available
  Future<bool> _checkDatabaseConnection() async {
    // For local development without a backend API, return false
    // In production, this would check the actual database connection
    return false;
  }

  /// Set the current save ID
  void setCurrentSave(String saveId) {
    _currentSaveId = saveId;
    if (!_memoryCache.containsKey(saveId)) {
      _memoryCache[saveId] = [];
    }
    if (!_chatCache.containsKey(saveId)) {
      _chatCache[saveId] = [];
    }
  }

  /// Generate embedding for text using Ollama
  Future<List<double>?> generateEmbedding(String text) async {
    try {
      final response = await _dio.post(
        '${config.ollamaUrl}/api/embeddings',
        data: {
          'model': config.embeddingModel,
          'prompt': text,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.data != null && response.data['embedding'] != null) {
        return (response.data['embedding'] as List<dynamic>).cast<double>();
      }
      return null;
    } catch (e) {
      print('Embedding generation failed: $e');
      return null;
    }
  }

  /// Store a memory entry
  Future<void> storeMemory(MemoryEntry memory) async {
    if (_currentSaveId == null) return;

    // Generate embedding if not provided
    MemoryEntry entryToStore = memory;
    if (memory.embedding == null) {
      final embedding = await generateEmbedding(memory.content);
      if (embedding != null) {
        entryToStore = MemoryEntry(
          id: memory.id,
          saveId: memory.saveId,
          content: memory.content,
          summary: memory.summary,
          type: memory.type,
          importance: memory.importance,
          embedding: embedding,
          location: memory.location,
          involvedNpcs: memory.involvedNpcs,
          involvedItems: memory.involvedItems,
          tags: memory.tags,
          turnNumber: memory.turnNumber,
          isPlayerAction: memory.isPlayerAction,
          createdAt: memory.createdAt,
        );
      }
    }

    // Store in cache
    _memoryCache[_currentSaveId]?.add(entryToStore);

    // Store in database if available
    if (_useDatabase) {
      await _storeMemoryToDatabase(entryToStore);
    }
  }

  Future<void> _storeMemoryToDatabase(MemoryEntry memory) async {
    // Implementation for database storage
    // Would use postgres package or REST API
  }

  /// Store a chat message
  Future<void> storeChatMessage({
    required String role,
    required String content,
    required MessageType messageType,
    Map<String, dynamic>? combatData,
  }) async {
    if (_currentSaveId == null) return;

    _turnCounter++;
    
    final message = {
      'id': _uuid.v4(),
      'save_id': _currentSaveId,
      'role': role,
      'content': content,
      'message_type': messageType.name,
      'turn_number': _turnCounter,
      'combat_data': combatData,
      'created_at': DateTime.now().toIso8601String(),
    };

    _chatCache[_currentSaveId]?.add(message);

    // Also create a memory entry for important messages
    if (_shouldCreateMemory(messageType, content)) {
      await storeMemory(MemoryEntry(
        saveId: _currentSaveId!,
        content: content,
        type: _getMemoryType(messageType),
        importance: _calculateImportance(messageType, content),
        turnNumber: _turnCounter,
        isPlayerAction: role == 'player',
      ));
    }
  }

  bool _shouldCreateMemory(MessageType type, String content) {
    // Create memories for significant events
    return type == MessageType.narration ||
           type == MessageType.combat ||
           type == MessageType.questUpdate ||
           type == MessageType.levelUp ||
           content.length > 100;
  }

  MemoryType _getMemoryType(MessageType messageType) {
    switch (messageType) {
      case MessageType.combat:
        return MemoryType.combat;
      case MessageType.dialogue:
        return MemoryType.dialogue;
      case MessageType.questUpdate:
        return MemoryType.quest;
      case MessageType.playerAction:
        return MemoryType.playerAction;
      default:
        return MemoryType.event;
    }
  }

  int _calculateImportance(MessageType type, String content) {
    int importance = 5;

    // Combat is important
    if (type == MessageType.combat) importance += 2;
    
    // Quest updates are very important
    if (type == MessageType.questUpdate) importance += 3;
    
    // Level ups are very important
    if (type == MessageType.levelUp) importance = 10;
    
    // Longer content tends to be more important
    if (content.length > 200) importance += 1;
    
    // Check for important keywords
    final importantKeywords = [
      'discovered', 'found', 'secret', 'treasure', 'artifact',
      'quest', 'mission', 'died', 'killed', 'defeated',
      'learned', 'revealed', 'ancient', 'powerful', 'legendary',
    ];
    
    for (final keyword in importantKeywords) {
      if (content.toLowerCase().contains(keyword)) {
        importance += 1;
        break;
      }
    }

    return importance.clamp(1, 10);
  }

  /// Search for relevant memories using semantic similarity
  Future<List<MemorySearchResult>> searchMemories(
    String query, {
    int limit = 5,
    List<MemoryType>? types,
    int? minImportance,
  }) async {
    if (_currentSaveId == null) return [];

    // Generate query embedding
    final queryEmbedding = await generateEmbedding(query);
    if (queryEmbedding == null) {
      // Fallback to keyword search
      return _keywordSearch(query, limit: limit, types: types);
    }

    // Search in cache using cosine similarity
    final memories = _memoryCache[_currentSaveId] ?? [];
    final results = <MemorySearchResult>[];

    for (final memory in memories) {
      if (memory.embedding == null) continue;
      if (types != null && !types.contains(memory.type)) continue;
      if (minImportance != null && memory.importance < minImportance) continue;

      final similarity = _cosineSimilarity(queryEmbedding, memory.embedding!);
      results.add(MemorySearchResult(memory: memory, similarity: similarity));
    }

    // Sort by similarity
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    return results.take(limit).toList();
  }

  /// Keyword-based search fallback
  List<MemorySearchResult> _keywordSearch(
    String query, {
    int limit = 5,
    List<MemoryType>? types,
  }) {
    if (_currentSaveId == null) return [];

    final queryWords = query.toLowerCase().split(' ');
    final memories = _memoryCache[_currentSaveId] ?? [];
    final results = <MemorySearchResult>[];

    for (final memory in memories) {
      if (types != null && !types.contains(memory.type)) continue;

      final content = memory.content.toLowerCase();
      int matchCount = 0;
      
      for (final word in queryWords) {
        if (content.contains(word)) matchCount++;
      }

      if (matchCount > 0) {
        final similarity = matchCount / queryWords.length;
        results.add(MemorySearchResult(memory: memory, similarity: similarity));
      }
    }

    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(limit).toList();
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;

    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  double sqrt(double x) => x > 0 ? _sqrt(x) : 0;
  
  double _sqrt(double x) {
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  /// Get recent chat history
  List<Map<String, dynamic>> getRecentChat({int limit = 20}) {
    if (_currentSaveId == null) return [];
    
    final chat = _chatCache[_currentSaveId] ?? [];
    return chat.reversed.take(limit).toList().reversed.toList();
  }

  /// Get important memories for context
  Future<List<MemoryEntry>> getImportantMemories({
    int minImportance = 7,
    int limit = 10,
  }) async {
    if (_currentSaveId == null) return [];

    final memories = _memoryCache[_currentSaveId] ?? [];
    final important = memories
        .where((m) => m.importance >= minImportance)
        .toList()
      ..sort((a, b) => b.importance.compareTo(a.importance));

    return important.take(limit).toList();
  }

  /// Build context for AI from memories
  Future<String> buildMemoryContext(String currentAction) async {
    final buffer = StringBuffer();

    // Get relevant memories for the current action
    final relevantMemories = await searchMemories(
      currentAction,
      limit: 5,
      minImportance: 5,
    );

    if (relevantMemories.isNotEmpty) {
      buffer.writeln('=== RELEVANT MEMORIES ===');
      for (final result in relevantMemories) {
        buffer.writeln('- ${result.memory.content}');
      }
      buffer.writeln();
    }

    // Get important memories
    final importantMemories = await getImportantMemories(minImportance: 8, limit: 5);
    if (importantMemories.isNotEmpty) {
      buffer.writeln('=== IMPORTANT EVENTS ===');
      for (final memory in importantMemories) {
        buffer.writeln('- ${memory.content}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Record an NPC interaction
  Future<void> recordNPCInteraction({
    required String npcName,
    required String interactionContent,
    String? location,
    int relationshipChange = 0,
  }) async {
    if (_currentSaveId == null) return;

    await storeMemory(MemoryEntry(
      saveId: _currentSaveId!,
      content: 'Interaction with $npcName: $interactionContent',
      type: MemoryType.npcInteraction,
      importance: 6,
      location: location,
      involvedNpcs: [npcName],
      turnNumber: _turnCounter,
    ));
  }

  /// Record a location discovery
  Future<void> recordLocationDiscovery({
    required String locationName,
    required String description,
    List<String>? npcsFound,
    List<String>? itemsFound,
  }) async {
    if (_currentSaveId == null) return;

    await storeMemory(MemoryEntry(
      saveId: _currentSaveId!,
      content: 'Discovered $locationName: $description',
      type: MemoryType.location,
      importance: 7,
      location: locationName,
      involvedNpcs: npcsFound,
      involvedItems: itemsFound,
      turnNumber: _turnCounter,
    ));
  }

  /// Record a quest update
  Future<void> recordQuestUpdate({
    required String questName,
    required String update,
    bool isComplete = false,
  }) async {
    if (_currentSaveId == null) return;

    await storeMemory(MemoryEntry(
      saveId: _currentSaveId!,
      content: 'Quest "$questName": $update',
      type: MemoryType.quest,
      importance: isComplete ? 9 : 7,
      tags: ['quest', if (isComplete) 'completed'],
      turnNumber: _turnCounter,
    ));
  }

  /// Clear memories for a save (when starting new game)
  void clearMemories(String saveId) {
    _memoryCache.remove(saveId);
    _chatCache.remove(saveId);
    _turnCounter = 0;
  }

  /// Export memories for backup
  Map<String, dynamic> exportMemories() {
    return {
      'memories': _memoryCache.map((key, value) => 
          MapEntry(key, value.map((m) => m.toJson()).toList())),
      'chat': _chatCache,
      'turnCounter': _turnCounter,
    };
  }

  /// Import memories from backup
  void importMemories(Map<String, dynamic> data) {
    if (data['memories'] != null) {
      final memories = data['memories'] as Map<String, dynamic>;
      for (final entry in memories.entries) {
        _memoryCache[entry.key] = (entry.value as List)
            .map((m) => MemoryEntry.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    }
    
    if (data['chat'] != null) {
      final chat = data['chat'] as Map<String, dynamic>;
      for (final entry in chat.entries) {
        _chatCache[entry.key] = (entry.value as List)
            .cast<Map<String, dynamic>>();
      }
    }
    
    _turnCounter = data['turnCounter'] as int? ?? 0;
  }
}

/// Provider for memory service
class MemoryServiceProvider {
  static MemoryService? _instance;

  static MemoryService get instance {
    _instance ??= MemoryService();
    return _instance!;
  }

  static Future<MemoryService> initialize({
    MemoryDatabaseConfig? config,
  }) async {
    _instance = MemoryService(config: config);
    await _instance!.initialize();
    return _instance!;
  }
}

