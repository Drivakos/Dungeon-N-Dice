import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/story_journal_model.dart';
import '../models/story_message_model.dart';
import '../models/ai_response_model.dart';
import '../models/game_state_model.dart';

/// Service for managing the story journal
class JournalService {
  static const String _journalBoxName = 'story_journals';
  static late Box<String> _journalBox;
  static final Uuid _uuid = const Uuid();
  
  /// Initialize the journal storage
  static Future<void> initialize() async {
    _journalBox = await Hive.openBox<String>(_journalBoxName);
  }
  
  /// Get or create a journal for a save
  static StoryJournal getJournal(String saveId) {
    final json = _journalBox.get(saveId);
    if (json == null) {
      return StoryJournal(saveId: saveId);
    }
    
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return StoryJournal.fromJson(map);
    } catch (e) {
      return StoryJournal(saveId: saveId);
    }
  }
  
  /// Save a journal
  static Future<void> saveJournal(StoryJournal journal) async {
    final json = jsonEncode(journal.toJson());
    await _journalBox.put(journal.saveId, json);
  }
  
  /// Add an entry to the journal
  static Future<StoryJournal> addEntry({
    required String saveId,
    required JournalEntryType type,
    required String title,
    required String content,
    String? location,
    List<String>? involvedNpcs,
    Map<String, dynamic>? metadata,
    bool isImportant = false,
  }) async {
    var journal = getJournal(saveId);
    
    final entry = JournalEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: type,
      title: title,
      content: content,
      location: location,
      involvedNpcs: involvedNpcs,
      metadata: metadata,
      isImportant: isImportant,
    );
    
    journal = journal.copyWith(
      entries: [...journal.entries, entry],
    );
    
    await saveJournal(journal);
    return journal;
  }
  
  /// Record a story event from AI response
  static Future<StoryJournal> recordStoryEvent({
    required String saveId,
    required String playerAction,
    required AIResponseModel aiResponse,
    required GameStateModel gameState,
    SkillCheckResult? skillCheckResult,
  }) async {
    var journal = getJournal(saveId);
    final entries = <JournalEntry>[];
    
    // Main narrative entry
    entries.add(JournalEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      type: JournalEntryType.narrative,
      title: _generateEventTitle(playerAction),
      content: '**You:** $playerAction\n\n${aiResponse.narration}',
      location: gameState.currentScene.name,
      involvedNpcs: aiResponse.npcDialogues?.map((d) => d.npcName).toList(),
    ));
    
    // NPC dialogue entries
    if (aiResponse.npcDialogues != null && aiResponse.npcDialogues!.isNotEmpty) {
      for (final dialogue in aiResponse.npcDialogues!) {
        entries.add(JournalEntry(
          id: _uuid.v4(),
          timestamp: DateTime.now(),
          type: JournalEntryType.npcEncounter,
          title: 'Spoke with ${dialogue.npcName}',
          content: '"${dialogue.dialogue}"${dialogue.emotion != null ? ' (${dialogue.emotion})' : ''}',
          location: gameState.currentScene.name,
          involvedNpcs: [dialogue.npcName],
        ));
      }
    }
    
    // Skill check entry
    if (skillCheckResult != null) {
      entries.add(JournalEntry(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        type: JournalEntryType.skillCheck,
        title: '${skillCheckResult.checkTypeName} - ${skillCheckResult.isSuccess ? "Success" : "Failure"}',
        content: 'Rolled ${skillCheckResult.diceRoll} + ${skillCheckResult.modifier} = ${skillCheckResult.totalResult} vs DC ${skillCheckResult.difficultyClass}',
        location: gameState.currentScene.name,
        metadata: {
          'roll': skillCheckResult.diceRoll,
          'modifier': skillCheckResult.modifier,
          'total': skillCheckResult.totalResult,
          'dc': skillCheckResult.difficultyClass,
          'success': skillCheckResult.isSuccess,
        },
      ));
    }
    
    // Scene change entry
    if (aiResponse.sceneChange != null) {
      final newLocations = [...journal.discoveredLocations];
      if (!newLocations.contains(aiResponse.sceneChange!.newSceneName)) {
        newLocations.add(aiResponse.sceneChange!.newSceneName);
      }
      
      entries.add(JournalEntry(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        type: JournalEntryType.locationChange,
        title: 'Traveled to ${aiResponse.sceneChange!.newSceneName}',
        content: aiResponse.sceneChange!.transitionDescription ?? 
                 aiResponse.sceneChange!.newSceneDescription,
        location: aiResponse.sceneChange!.newSceneName,
        isImportant: !journal.discoveredLocations.contains(aiResponse.sceneChange!.newSceneName),
      ));
      
      journal = journal.copyWith(discoveredLocations: newLocations);
    }
    
    journal = journal.copyWith(
      entries: [...journal.entries, ...entries],
    );
    
    await saveJournal(journal);
    return journal;
  }
  
  /// Record a combat event
  static Future<StoryJournal> recordCombatEvent({
    required String saveId,
    required String description,
    required String location,
    List<String>? enemies,
    bool isVictory = false,
    int? damageDealt,
    int? damageTaken,
    int? xpGained,
  }) async {
    return addEntry(
      saveId: saveId,
      type: JournalEntryType.combat,
      title: isVictory ? 'Victory in Battle' : 'Combat Encounter',
      content: description,
      location: location,
      involvedNpcs: enemies,
      metadata: {
        'victory': isVictory,
        'damageDealt': damageDealt,
        'damageTaken': damageTaken,
        'xpGained': xpGained,
      },
      isImportant: isVictory,
    );
  }
  
  /// Record a level up
  static Future<StoryJournal> recordLevelUp({
    required String saveId,
    required int newLevel,
    required String characterName,
    int? hpGained,
  }) async {
    return addEntry(
      saveId: saveId,
      type: JournalEntryType.levelUp,
      title: 'Reached Level $newLevel!',
      content: '$characterName has grown stronger, reaching level $newLevel.${hpGained != null ? ' Gained $hpGained HP.' : ''}',
      isImportant: true,
      metadata: {
        'level': newLevel,
        'hpGained': hpGained,
      },
    );
  }
  
  /// Record a quest event
  static Future<StoryJournal> recordQuestEvent({
    required String saveId,
    required String questTitle,
    required bool isComplete,
    String? description,
  }) async {
    return addEntry(
      saveId: saveId,
      type: isComplete ? JournalEntryType.questComplete : JournalEntryType.questStart,
      title: isComplete ? 'Completed: $questTitle' : 'New Quest: $questTitle',
      content: description ?? (isComplete ? 'Quest completed!' : 'A new adventure begins...'),
      isImportant: true,
    );
  }
  
  /// Generate a title for a narrative event
  static String _generateEventTitle(String playerAction) {
    final action = playerAction.toLowerCase();
    if (action.contains('look') || action.contains('examine') || action.contains('inspect')) {
      return 'Observation';
    }
    if (action.contains('talk') || action.contains('speak') || action.contains('ask')) {
      return 'Conversation';
    }
    if (action.contains('attack') || action.contains('fight') || action.contains('strike')) {
      return 'Combat';
    }
    if (action.contains('search') || action.contains('find') || action.contains('look for')) {
      return 'Search';
    }
    if (action.contains('go') || action.contains('walk') || action.contains('move') || action.contains('travel')) {
      return 'Travel';
    }
    if (action.contains('take') || action.contains('grab') || action.contains('pick up')) {
      return 'Item Acquired';
    }
    return 'Event';
  }
  
  /// Get a summary of recent events for AI context
  static String getRecentEventsSummary(String saveId, {int count = 5}) {
    final journal = getJournal(saveId);
    final recent = journal.getRecentEntries(count);
    
    if (recent.isEmpty) return '';
    
    final buffer = StringBuffer('Recent events:\n');
    for (final entry in recent.reversed) {
      buffer.writeln('- ${entry.title}: ${_truncate(entry.content, 100)}');
    }
    return buffer.toString();
  }
  
  /// Get known NPC information for AI context
  static String getNpcContext(String saveId) {
    final journal = getJournal(saveId);
    if (journal.npcRelationships.isEmpty) return '';
    
    final buffer = StringBuffer('Known NPCs:\n');
    for (final npc in journal.npcRelationships.values) {
      buffer.writeln('- ${npc.npcName} (${npc.status.displayName})');
      for (final fact in npc.knownFacts.take(2)) {
        buffer.writeln('  • $fact');
      }
    }
    return buffer.toString();
  }
  
  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  /// Delete a journal
  static Future<void> deleteJournal(String saveId) async {
    await _journalBox.delete(saveId);
  }
}

