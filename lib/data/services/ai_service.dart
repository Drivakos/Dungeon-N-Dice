import 'dart:convert';
import 'package:dio/dio.dart';

import '../../core/constants/game_constants.dart';
import '../../domain/game_engine/combat_manager.dart';
import '../models/character_model.dart';
import '../models/monster_model.dart';
import '../models/game_state_model.dart';
import '../models/ai_response_model.dart';
import '../models/story_message_model.dart';
import 'memory_service.dart';

/// AI provider types
enum AIProvider {
  openai('OpenAI'),
  anthropic('Anthropic'),
  ollama('Ollama (Local)');

  final String displayName;
  const AIProvider(this.displayName);
}

/// Configuration for AI service
class AIServiceConfig {
  final AIProvider provider;
  final String apiKey;
  final String? baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;

  const AIServiceConfig({
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    required this.model,
    this.temperature = 0.8,
    this.maxTokens = 1024,
  });

  factory AIServiceConfig.openai({
    required String apiKey,
    String model = 'gpt-4-turbo-preview',
  }) {
    return AIServiceConfig(
      provider: AIProvider.openai,
      apiKey: apiKey,
      baseUrl: 'https://api.openai.com/v1',
      model: model,
    );
  }

  factory AIServiceConfig.anthropic({
    required String apiKey,
    String model = 'claude-3-opus-20240229',
  }) {
    return AIServiceConfig(
      provider: AIProvider.anthropic,
      apiKey: apiKey,
      baseUrl: 'https://api.anthropic.com/v1',
      model: model,
    );
  }

  factory AIServiceConfig.ollama({
    String baseUrl = 'http://localhost:11434',
    String model = 'qwen2.5:3b-instruct',
  }) {
    return AIServiceConfig(
      provider: AIProvider.ollama,
      apiKey: '', // Not needed for Ollama
      baseUrl: baseUrl,
      model: model,
      temperature: 0.7,
      maxTokens: 2048,
    );
  }
}

/// Service for AI story generation
class AIService {
  final Dio _dio;
  final AIServiceConfig config;
  final MemoryService _memoryService;

  AIService({
    required this.config,
    Dio? dio,
    MemoryService? memoryService,
  }) : _dio = dio ?? Dio(),
       _memoryService = memoryService ?? MemoryServiceProvider.instance;

  /// Generate story response from player action
  /// 
  /// [storySummary] - Optional AI-generated summary of the story so far.
  /// When provided, uses summary + recent messages instead of full history.
  Future<AIResponseModel> generateStoryResponse({
    required GameStateModel gameState,
    required String playerAction,
    List<MonsterModel>? combatMonsters,
    String? storySummary,
  }) async {
    // Get memory context for RAG
    final memoryContext = await _memoryService.buildMemoryContext(playerAction);
    final systemPrompt = _buildSystemPrompt(gameState, combatMonsters, memoryContext: memoryContext);

    try {
      String response;
      
      // Use conversation history for better context
      if (config.provider == AIProvider.ollama) {
        final conversationHistory = _buildConversationHistory(
          gameState, 
          playerAction,
          storySummary: storySummary,
        );
        response = await _callOllamaWithHistory(systemPrompt, conversationHistory);
      } else {
        final userPrompt = _buildUserPrompt(gameState, playerAction, storySummary: storySummary);
        response = await _callAI(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        );
      }
      
      // Store the player action in memory
      await _memoryService.storeChatMessage(
        role: 'player',
        content: playerAction,
        messageType: MessageType.playerAction,
      );

      final aiResponse = _parseAIResponse(response);
      
      // Store the AI response in memory
      await _memoryService.storeChatMessage(
        role: 'dm',
        content: aiResponse.narration,
        messageType: MessageType.narration,
      );
      
      // Extract and store important information
      await _extractAndStoreMemories(aiResponse, gameState);

      return aiResponse;
    } catch (e) {
      // Return a fallback response on error
      return AIResponseModel(
        narration: 'The world seems to shimmer for a moment, as if reality itself is uncertain. You feel a strange disconnect...',
        suggestedActions: ['Try again', 'Look around', 'Wait'],
      );
    }
  }
  
  /// Extract important information from AI response and store as memories
  Future<void> _extractAndStoreMemories(AIResponseModel response, GameStateModel gameState) async {
    // Extract NPCs mentioned
    final npcNames = _extractNPCNames(response.narration);
    for (final npc in npcNames) {
      await _memoryService.recordNPCInteraction(
        npcName: npc,
        interactionContent: response.narration,
        location: gameState.currentScene.name,
      );
    }
    
    // Record location if scene changed
    if (response.sceneChange != null) {
      await _memoryService.recordLocationDiscovery(
        locationName: response.sceneChange!.newSceneName,
        description: response.sceneChange!.newSceneDescription,
      );
    }
    
    // Record NPC dialogues
    if (response.npcDialogues != null) {
      for (final dialogue in response.npcDialogues!) {
        await _memoryService.recordNPCInteraction(
          npcName: dialogue.npcName,
          interactionContent: dialogue.dialogue,
          location: gameState.currentScene.name,
        );
      }
    }
  }
  
  /// Extract NPC names from text (simple heuristic)
  List<String> _extractNPCNames(String text) {
    final names = <String>[];
    
    // Look for capitalized words that might be names
    final namePattern = RegExp(r'\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b');
    final matches = namePattern.allMatches(text);
    
    // Common words to exclude
    final excludeWords = {
      'The', 'You', 'Your', 'They', 'Their', 'This', 'That',
      'Here', 'There', 'When', 'Where', 'What', 'Who', 'How',
      'Now', 'Then', 'Just', 'But', 'And', 'With', 'From',
    };
    
    for (final match in matches) {
      final name = match.group(1);
      if (name != null && !excludeWords.contains(name)) {
        names.add(name);
      }
    }
    
    return names.toSet().toList(); // Remove duplicates
  }
  
  /// Generate combat narration from the AI
  Future<String> generateCombatNarration({
    required GameStateModel gameState,
    required CombatState combatState,
    required String combatEvent,
  }) async {
    final prompt = _buildCombatPrompt(gameState, combatState, combatEvent);
    
    try {
      final response = await _callOllama(prompt, combatEvent);
      
      // Try to extract just the narration
      final parsed = _parseAIResponse(response);
      return parsed.narration;
    } catch (e) {
      return combatEvent; // Fallback to the raw event description
    }
  }
  
  /// Build combat-specific prompt
  String _buildCombatPrompt(GameStateModel gameState, CombatState combatState, String event) {
    final character = gameState.character;
    final enemies = combatState.aliveEnemies.map((e) => '${e.name} (HP: ${e.currentHitPoints}/${e.maxHitPoints})').join(', ');
    
    return '''You are a D&D combat narrator. Describe combat actions vividly in 1-2 sentences.

COMBAT STATUS:
- Player: ${character.name} (HP: ${character.currentHitPoints}/${character.maxHitPoints})
- Enemies: $enemies
- Round: ${combatState.roundNumber}

COMBAT EVENT: $event

Write a vivid, exciting description of this combat moment. Be dramatic but brief.

Respond with JSON: {"narration":"Your vivid description here."}''';
  }
  
  /// Detect if AI response suggests combat should start
  bool detectCombatTrigger(AIResponseModel response) {
    final narration = response.narration.toLowerCase();
    final combatKeywords = [
      'attacks you', 'lunges at you', 'strikes at you',
      'combat begins', 'roll for initiative', 'battle starts',
      'draws weapon', 'hostile', 'charges at you',
      'ambush', 'fight breaks out', 'enemies appear',
    ];
    
    return combatKeywords.any((keyword) => narration.contains(keyword)) ||
           response.combatProposal != null;
  }
  
  /// Generate enemy encounter based on context
  Future<AIResponseModel> generateCombatEncounter({
    required GameStateModel gameState,
    required String triggerAction,
  }) async {
    final character = gameState.character;
    
    final prompt = '''You are a D&D Dungeon Master. The player triggered combat!

PLAYER: ${character.name} (Level ${character.level} ${character.characterClass.displayName})
LOCATION: ${gameState.currentScene.name}
TRIGGER: $triggerAction

Generate a combat encounter with enemies appropriate for level ${character.level}.

Respond with JSON:
{
  "narration": "Dramatic description of combat starting...",
  "combatTrigger": {
    "enemies": [
      {"name": "Enemy Name", "type": "beast/humanoid/undead", "cr": 0.5}
    ],
    "ambush": false,
    "reason": "Why combat started"
  },
  "suggestedActions": ["Attack the enemy", "Dodge", "Attempt to flee"]
}''';

    try {
      final response = await _callOllama(prompt, triggerAction);
      return _parseAIResponse(response);
    } catch (e) {
      return AIResponseModel(
        narration: 'Hostile creatures emerge from the shadows, ready to attack!',
        suggestedActions: ['Fight', 'Dodge', 'Flee'],
      );
    }
  }

  /// Build the system prompt for the AI
  String _buildSystemPrompt(GameStateModel gameState, List<MonsterModel>? monsters, {String? memoryContext}) {
    final character = gameState.character;
    
    // Use a simpler prompt for local models
    if (config.provider == AIProvider.ollama) {
      return _buildSimpleSystemPrompt(gameState, monsters, memoryContext: memoryContext);
    }
    
    return '''
You are the Dungeon Master for a text-based D&D 5e adventure game. Your role is to create immersive, engaging narrative experiences while working within the game's mechanical framework.

## YOUR RESPONSIBILITIES:
✓ Generate vivid story narration and scene descriptions
✓ Write compelling NPC dialogue and roleplay
✓ Interpret player actions in the context of the story
✓ PROPOSE skill checks with appropriate difficulty classes
✓ PROPOSE consequences for success and failure
✓ Maintain narrative coherence and world consistency

## YOU MUST NEVER:
✗ Apply damage, healing, or stat changes directly
✗ Give items without proposing them for validation
✗ Change the player's level, XP, or gold directly
✗ Override game mechanics or rules
✗ Break the established lore or world state
✗ Give overpowered rewards (max ~${_getMaxRewardXP(character.level)} XP, ~${_getMaxRewardGold(character.level)} gold per encounter)

## CURRENT CHARACTER:
- Name: ${character.name}
- Race: ${character.race.displayName}
- Class: ${character.characterClass.displayName}
- Level: ${character.level}
- HP: ${character.currentHitPoints}/${character.maxHitPoints}
- AC: ${character.armorClass}
- Stats: STR ${character.abilityScores.strength} (${_formatModifier(character.getAbilityModifier(Ability.strength))}), DEX ${character.abilityScores.dexterity} (${_formatModifier(character.getAbilityModifier(Ability.dexterity))}), CON ${character.abilityScores.constitution} (${_formatModifier(character.getAbilityModifier(Ability.constitution))}), INT ${character.abilityScores.intelligence} (${_formatModifier(character.getAbilityModifier(Ability.intelligence))}), WIS ${character.abilityScores.wisdom} (${_formatModifier(character.getAbilityModifier(Ability.wisdom))}), CHA ${character.abilityScores.charisma} (${_formatModifier(character.getAbilityModifier(Ability.charisma))})

## CURRENT SCENE:
- Location: ${gameState.currentScene.name}
- Description: ${gameState.currentScene.description}
${gameState.currentScene.isInCombat ? '- STATUS: IN COMBAT' : ''}

${monsters != null && monsters.isNotEmpty ? _buildMonsterContext(monsters) : ''}

## SUGGESTED ACTIONS (CRITICAL):
Your suggested actions MUST be specific to what you just described:
- If you mention a person → "Talk to [name]", "Ask [name] about..."
- If you mention an object → "Examine the [object]", "Pick up the [object]"
- If you mention a location → "Go to [location]", "Investigate [location]"
- If you mention danger → "Attack the [enemy]", "Flee", "Hide"
- NEVER use generic suggestions like "Continue", "Wait", or "Look around"

Examples:
- Narration mentions a glowing amulet → ["Examine the amulet", "Ask about its origin", "Detect magic on it"]
- Narration mentions a nervous guard → ["Question the guard", "Bribe him", "Intimidate him"]
- Narration mentions distant screams → ["Rush toward the screams", "Approach cautiously", "Find a vantage point"]

## RESPONSE FORMAT:
Respond with valid JSON:
{
  "narration": "Your vivid description (2-4 sentences)...",
  "suggestedActions": ["Specific action 1", "Specific action 2", "Specific action 3"],
  "proposedCheck": {
    "checkType": "skill|ability|savingThrow",
    "ability": "STR|DEX|CON|INT|WIS|CHA",
    "skill": "Skill Name (if skill check)",
    "dc": 10-25,
    "description": "What this check represents"
  },
  "successOutcome": "What happens on success...",
  "failureOutcome": "What happens on failure...",
  "npcDialogues": [
    {"npcName": "NPC Name", "dialogue": "What they say...", "emotion": "friendly"}
  ]
}

Only include fields that are relevant. suggestedActions and narration are always required.
''';
  }
  
  /// Build a simpler system prompt for local/smaller models
  String _buildSimpleSystemPrompt(GameStateModel gameState, List<MonsterModel>? monsters, {String? memoryContext}) {
    final character = gameState.character;
    final inCombat = gameState.currentScene.isInCombat;
    
    if (inCombat && monsters != null && monsters.isNotEmpty) {
      return _buildCombatSystemPrompt(gameState, monsters);
    }
    
    // Build memory section if available
    final memorySection = memoryContext != null && memoryContext.isNotEmpty
        ? '''
$memoryContext
USE THE ABOVE MEMORIES to maintain story continuity. Reference past events, NPCs, and locations when relevant.
'''
        : '';
    
    return '''You are an expert D&D Dungeon Master running a continuous adventure.

PLAYER: ${character.name} (Level ${character.level} ${character.race.displayName} ${character.characterClass.displayName})
LOCATION: ${gameState.currentScene.name}
HP: ${character.currentHitPoints}/${character.maxHitPoints}
$memorySection
CRITICAL RULES:
1. NEVER repeat previous events
2. ALWAYS continue the story forward
3. Reference past events and NPCs from MEMORIES when relevant
4. Describe NEW events after the player's action

SUGGESTED ACTIONS - Must be SPECIFIC to your narration:
- Person mentioned → "Talk to [name]", "Ask [name] about..."
- Object mentioned → "Examine the [object]", "Take the [object]"
- Location mentioned → "Go to [location]", "Investigate [location]"
- Danger/enemy mentioned → "Attack", "Prepare for battle", "Flee"
- NEVER use "Continue", "Wait", "Look around"

COMBAT TRIGGERS - If player attacks or enemies appear:
Add this to your response: "combatTrigger": {"enemies": [{"name": "Goblin", "cr": 0.25}]}

RESPONSE FORMAT (JSON only):
{"narration":"2-3 sentences describing what happens.","suggestedActions":["Specific 1","Specific 2","Specific 3"]}

For skill checks:
{"narration":"Description.","check":{"ability":"DEX","dc":12},"success":"Success.","failure":"Failure.","suggestedActions":["Action 1","Action 2"]}

ABILITIES: STR, DEX, CON, INT, WIS, CHA''';
  }
  
  /// Build combat-specific system prompt
  String _buildCombatSystemPrompt(GameStateModel gameState, List<MonsterModel> monsters) {
    final character = gameState.character;
    final enemyList = monsters.map((m) => '${m.name} (HP: ${m.currentHitPoints}/${m.maxHitPoints})').join(', ');
    
    return '''You are a D&D combat narrator. You describe battle actions dramatically.

COMBAT IN PROGRESS!
PLAYER: ${character.name} (HP: ${character.currentHitPoints}/${character.maxHitPoints})
ENEMIES: $enemyList

YOUR ROLE:
- Describe combat actions vividly and briefly (1-2 sentences)
- Do NOT determine hit/miss or damage (the game engine handles that)
- Focus on the action and tension of battle
- Suggest tactical combat options

RESPONSE FORMAT (JSON):
{"narration":"Vivid combat description.","suggestedActions":["Attack [enemy]","Cast spell","Dodge","Flee"]}

For attack attempts:
{"narration":"Description of attack attempt.","combatAction":{"type":"attack","target":"Enemy Name"}}

Keep responses SHORT and ACTION-FOCUSED.''';
  }

  /// Build monster context for combat
  String _buildMonsterContext(List<MonsterModel> monsters) {
    final buffer = StringBuffer('## MONSTERS IN SCENE:\n');
    for (final monster in monsters) {
      buffer.writeln('- ${monster.name} (${monster.type.displayName})');
      buffer.writeln('  HP: ${monster.currentHitPoints}/${monster.maxHitPoints}, AC: ${monster.armorClass}');
      buffer.writeln('  ${monster.description}');
    }
    return buffer.toString();
  }

  /// Build conversation history for the AI
  /// 
  /// When [storySummary] is provided, uses a more efficient context:
  /// - Summary of earlier events
  /// - Only the last 5 recent messages in full
  /// 
  /// Without summary, uses last 10 messages (legacy behavior).
  List<Map<String, String>> _buildConversationHistory(
    GameStateModel gameState, 
    String playerAction, {
    String? storySummary,
  }) {
    final messages = <Map<String, String>>[];
    
    // Determine how many recent messages to include
    final recentMessageCount = storySummary != null ? 5 : 10;
    final recentMessages = gameState.storyLog.reversed
        .take(recentMessageCount)
        .toList()
        .reversed
        .toList();
    
    // If we have a summary, add it as context first
    if (storySummary != null && storySummary.isNotEmpty) {
      messages.add({
        'role': 'user', 
        'content': 'STORY SUMMARY (what has happened so far):\n$storySummary\n\n---\nThe following are the most recent events. Continue from here.',
      });
      messages.add({
        'role': 'assistant',
        'content': '{"narration":"I understand the story context. I will continue from the recent events without repeating the summarized content.","suggestedActions":[]}',
      });
    }
    
    // Convert recent story messages to conversation format
    for (final msg in recentMessages) {
      if (msg.type == MessageType.playerAction) {
        messages.add({'role': 'user', 'content': 'Player action: ${msg.content}'});
      } else if (msg.type == MessageType.narration || msg.type == MessageType.dialogue) {
        // Combine narration as assistant response
        messages.add({'role': 'assistant', 'content': '{"narration":"${_escapeJson(msg.content)}","suggestedActions":["Continue","Look around","Wait"]}'});
      }
    }
    
    // Add current action as the final user message
    messages.add({'role': 'user', 'content': 'Player action: $playerAction\n\nContinue the story. Do NOT repeat previous events. Describe what happens NEXT.'});
    
    return messages;
  }
  
  /// Escape string for JSON
  String _escapeJson(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
  
  /// Build a simple user prompt (fallback)
  String _buildUserPrompt(GameStateModel gameState, String playerAction, {String? storySummary}) {
    final recentMessageCount = storySummary != null ? 5 : 6;
    final recentMessages = gameState.storyLog.reversed.take(recentMessageCount).toList().reversed;
    final contextBuffer = StringBuffer();
    
    // Add summary if available
    if (storySummary != null && storySummary.isNotEmpty) {
      contextBuffer.writeln('=== STORY SUMMARY ===');
      contextBuffer.writeln(storySummary);
      contextBuffer.writeln('=== END SUMMARY ===\n');
    }
    
    if (recentMessages.isNotEmpty) {
      contextBuffer.writeln('=== RECENT EVENTS (continue from here) ===');
      for (final msg in recentMessages) {
        if (msg.type == MessageType.playerAction) {
          contextBuffer.writeln('PLAYER: ${msg.content}');
        } else if (msg.type == MessageType.narration) {
          contextBuffer.writeln('DM: ${msg.content}');
        }
      }
      contextBuffer.writeln('=== END OF RECENT EVENTS ===\n');
    }
    
    return '''
${contextBuffer.toString()}
NEW PLAYER ACTION: "$playerAction"

IMPORTANT: Continue the story from where it left off. Do NOT repeat or summarize previous events. Describe what happens NEXT as a direct result of this action.

Respond with JSON only.
''';
  }

  /// Call the AI API based on provider
  Future<String> _callAI({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    switch (config.provider) {
      case AIProvider.openai:
        return _callOpenAI(systemPrompt, userPrompt);
      case AIProvider.anthropic:
        return _callAnthropic(systemPrompt, userPrompt);
      case AIProvider.ollama:
        return _callOllama(systemPrompt, userPrompt);
    }
  }

  /// Call OpenAI API
  Future<String> _callOpenAI(String systemPrompt, String userPrompt) async {
    final response = await _dio.post(
      '${config.baseUrl}/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': config.model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': config.temperature,
        'max_tokens': config.maxTokens,
        'response_format': {'type': 'json_object'},
      },
    );

    return response.data['choices'][0]['message']['content'] as String;
  }

  /// Call Anthropic API
  Future<String> _callAnthropic(String systemPrompt, String userPrompt) async {
    final response = await _dio.post(
      '${config.baseUrl}/messages',
      options: Options(
        headers: {
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': config.model,
        'max_tokens': config.maxTokens,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': userPrompt},
        ],
      },
    );

    return response.data['content'][0]['text'] as String;
  }

  /// Call Ollama API (local) with conversation history
  Future<String> _callOllamaWithHistory(String systemPrompt, List<Map<String, String>> conversationHistory) async {
    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
        ...conversationHistory,
      ];
      
      final response = await _dio.post(
        '${config.baseUrl}/api/chat',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
        data: {
          'model': config.model,
          'messages': messages,
          'stream': false,
          'format': 'json',
          'options': {
            'temperature': config.temperature,
            'num_predict': config.maxTokens,
          },
        },
      );

      final message = response.data['message'];
      if (message != null && message['content'] != null) {
        return message['content'] as String;
      }
      
      throw Exception('No response content');
    } catch (e) {
      print('Ollama chat error: $e');
      rethrow;
    }
  }
  
  /// Call Ollama API (local) - simple version
  Future<String> _callOllama(String systemPrompt, String userPrompt) async {
    try {
      final response = await _dio.post(
        '${config.baseUrl}/api/chat',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
        data: {
          'model': config.model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'stream': false,
          'format': 'json',
          'options': {
            'temperature': config.temperature,
            'num_predict': config.maxTokens,
          },
        },
      );

      final message = response.data['message'];
      if (message != null && message['content'] != null) {
        return message['content'] as String;
      }
      
      return _callOllamaGenerate(systemPrompt, userPrompt);
    } catch (e) {
      return _callOllamaGenerate(systemPrompt, userPrompt);
    }
  }
  
  /// Fallback to Ollama generate endpoint
  Future<String> _callOllamaGenerate(String systemPrompt, String userPrompt) async {
    final response = await _dio.post(
      '${config.baseUrl}/api/generate',
      options: Options(
        headers: {'Content-Type': 'application/json'},
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 30),
      ),
      data: {
        'model': config.model,
        'system': systemPrompt,
        'prompt': userPrompt,
        'stream': false,
        'format': 'json',
        'options': {
          'temperature': config.temperature,
          'num_predict': config.maxTokens,
        },
      },
    );

    return response.data['response'] as String;
  }

  /// Parse AI response into structured format
  AIResponseModel _parseAIResponse(String response) {
    try {
      // Clean the response
      String jsonStr = _cleanJsonResponse(response);
      
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Extract narration (required) - try multiple field names
      final narration = _extractString(json, ['narration', 'narrative', 'description', 'text']) 
          ?? 'The story continues...';
      
      // Extract suggested actions
      final suggestedActions = _extractStringList(json, ['suggestedActions', 'suggested_actions', 'actions'])
          ?? ['Continue', 'Look around', 'Wait'];
      
      // Parse proposed check - handle both "check" and "proposedCheck" formats
      ProposedCheck? proposedCheck;
      final checkJson = json['check'] ?? json['proposedCheck'] ?? json['proposed_check'];
      if (checkJson != null && checkJson is Map<String, dynamic>) {
        proposedCheck = _parseProposedCheck(checkJson);
      }
      
      // Extract success/failure outcomes
      final successOutcome = _extractString(json, ['success', 'successOutcome', 'success_outcome']);
      final failureOutcome = _extractString(json, ['failure', 'failureOutcome', 'failure_outcome']);
      
      // Parse NPC dialogues
      List<NPCDialogue>? npcDialogues;
      final dialoguesJson = json['npcDialogues'] ?? json['npc_dialogues'] ?? json['dialogue'];
      if (dialoguesJson != null && dialoguesJson is List) {
        npcDialogues = dialoguesJson
            .whereType<Map<String, dynamic>>()
            .map((d) => NPCDialogue.fromJson(d))
            .toList();
      }
      
      // Parse rewards
      List<ProposedReward>? rewards;
      final rewardsJson = json['proposedRewards'] ?? json['rewards'];
      if (rewardsJson != null && rewardsJson is List) {
        rewards = rewardsJson
            .whereType<Map<String, dynamic>>()
            .map((r) => _parseReward(r))
            .toList();
      }
      
      // Parse scene change
      SceneChange? sceneChange;
      final sceneJson = json['sceneChange'] ?? json['scene_change'] ?? json['newScene'];
      if (sceneJson != null && sceneJson is Map<String, dynamic>) {
        try {
          sceneChange = SceneChange.fromJson(sceneJson);
        } catch (_) {
          // Ignore scene parsing errors
        }
      }
      
      // Parse combat trigger
      CombatTrigger? combatTrigger;
      final combatJson = json['combatTrigger'] ?? json['combat_trigger'] ?? json['combat'];
      if (combatJson != null && combatJson is Map<String, dynamic>) {
        try {
          combatTrigger = CombatTrigger.fromJson(combatJson);
        } catch (_) {
          // Ignore combat parsing errors
        }
      }
      
      return AIResponseModel(
        narration: narration,
        suggestedActions: suggestedActions,
        proposedCheck: proposedCheck,
        successOutcome: successOutcome,
        failureOutcome: failureOutcome,
        npcDialogues: npcDialogues,
        proposedRewards: rewards,
        sceneChange: sceneChange,
        combatTrigger: combatTrigger,
        ambientDescription: json['ambientDescription'] as String?,
      );
    } catch (e) {
      print('AI Response parsing error: $e');
      
      // Try to extract narration using regex as fallback
      final narration = _extractNarrationFallback(response);
      final actions = _extractActionsFallback(response);
      
      return AIResponseModel(
        narration: narration,
        suggestedActions: actions,
      );
    }
  }
  
  /// Clean JSON response from AI
  String _cleanJsonResponse(String response) {
    String cleaned = response.trim();
    
    // Remove markdown code blocks
    cleaned = cleaned.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    
    // Remove any leading/trailing non-JSON text
    final jsonMatch = RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}').firstMatch(cleaned);
    if (jsonMatch != null) {
      cleaned = jsonMatch.group(0)!;
    }
    
    // Fix common JSON issues
    cleaned = cleaned.replaceAll(RegExp(r',\s*}'), '}'); // Remove trailing commas
    cleaned = cleaned.replaceAll(RegExp(r',\s*]'), ']'); // Remove trailing commas in arrays
    
    return cleaned;
  }
  
  /// Extract string from JSON with multiple possible keys
  String? _extractString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json[key] != null && json[key] is String) {
        return json[key] as String;
      }
    }
    return null;
  }
  
  /// Extract string list from JSON with multiple possible keys
  List<String>? _extractStringList(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json[key] != null && json[key] is List) {
        return (json[key] as List).map((e) => e.toString()).toList();
      }
    }
    return null;
  }
  
  /// Fallback narration extraction using regex
  String _extractNarrationFallback(String response) {
    // Try to find narration in JSON-like format
    final patterns = [
      RegExp(r'"narration"\s*:\s*"((?:[^"\\]|\\.)*)"'),
      RegExp(r'"narrative"\s*:\s*"((?:[^"\\]|\\.)*)"'),
      RegExp(r'"description"\s*:\s*"((?:[^"\\]|\\.)*)"'),
      RegExp(r'"text"\s*:\s*"((?:[^"\\]|\\.)*)"'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(response);
      if (match != null) {
        return match.group(1)!
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\\', '\\');
      }
    }
    
    // If nothing found, clean up and return the raw response
    String cleaned = response
        .replaceAll(RegExp(r'[{}\[\]]'), '')
        .replaceAll(RegExp(r'"[a-zA-Z]+"\s*:'), '')
        .replaceAll('"', '')
        .trim();
    
    // Take first few sentences if too long
    if (cleaned.length > 500) {
      final sentences = cleaned.split(RegExp(r'[.!?]'));
      if (sentences.length > 3) {
        cleaned = sentences.take(3).join('. ') + '.';
      }
    }
    
    return cleaned.isNotEmpty ? cleaned : 'The adventure continues...';
  }
  
  /// Fallback actions extraction using regex
  List<String> _extractActionsFallback(String response) {
    final pattern = RegExp(r'"suggestedActions"\s*:\s*\[((?:[^\[\]])*)\]');
    final match = pattern.firstMatch(response);
    
    if (match != null) {
      final actionsStr = match.group(1)!;
      final actions = RegExp(r'"([^"]+)"')
          .allMatches(actionsStr)
          .map((m) => m.group(1)!)
          .toList();
      
      if (actions.isNotEmpty) return actions;
    }
    
    return ['Continue', 'Look around', 'Wait'];
  }
  
  /// Parse a proposed check with flexible ability matching
  ProposedCheck? _parseProposedCheck(Map<String, dynamic> json) {
    try {
      final abilityStr = json['ability'] as String?;
      Ability? ability;
      
      if (abilityStr != null) {
        // Handle formats like "STR", "Strength", "STR/DEX" (take first)
        final firstAbility = abilityStr.split('/').first.trim().toUpperCase();
        ability = Ability.values.firstWhere(
          (a) => a.abbreviation.toUpperCase() == firstAbility || 
                 a.name.toUpperCase() == firstAbility ||
                 a.fullName.toUpperCase() == firstAbility,
          orElse: () => Ability.strength,
        );
      }
      
      final skillStr = json['skill'] as String?;
      Skill? skill;
      if (skillStr != null) {
        skill = Skill.values.firstWhere(
          (s) => s.displayName.toLowerCase() == skillStr.toLowerCase() || 
                 s.name.toLowerCase() == skillStr.toLowerCase(),
          orElse: () => Skill.athletics,
        );
      }
      
      return ProposedCheck(
        checkType: skill != null ? CheckType.skill : CheckType.ability,
        ability: ability,
        skill: skill,
        difficultyClass: json['dc'] as int? ?? json['difficultyClass'] as int? ?? 10,
        description: json['description'] as String?,
      );
    } catch (e) {
      print('Error parsing proposed check: $e');
      return null;
    }
  }
  
  /// Parse a reward with flexible type matching
  ProposedReward _parseReward(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?)?.toLowerCase() ?? 'experience';
    RewardType type;
    
    if (typeStr.contains('gold') || typeStr.contains('coin')) {
      type = RewardType.gold;
    } else if (typeStr.contains('item')) {
      type = RewardType.item;
    } else if (typeStr.contains('exp') || typeStr.contains('xp')) {
      type = RewardType.experience;
    } else {
      type = RewardType.experience;
    }
    
    return ProposedReward(
      type: type,
      itemName: json['itemName'] as String? ?? json['item_name'] as String?,
      quantity: json['quantity'] as int?,
      goldAmount: json['goldAmount'] as int? ?? json['gold_amount'] as int? ?? json['gold'] as int?,
      experiencePoints: json['experiencePoints'] as int? ?? json['experience_points'] as int? ?? json['xp'] as int?,
    );
  }

  /// Format modifier for display
  String _formatModifier(int mod) {
    return mod >= 0 ? '+$mod' : '$mod';
  }

  /// Get max XP reward for level
  int _getMaxRewardXP(int level) => 100 + (level * 50);

  /// Get max gold reward for level
  int _getMaxRewardGold(int level) => 50 + (level * 25);
}

/// Abstract interface for AI services
abstract class IAIService {
  Future<AIResponseModel> generateStoryResponse({
    required GameStateModel gameState,
    required String playerAction,
    List<MonsterModel>? combatMonsters,
  });
}


