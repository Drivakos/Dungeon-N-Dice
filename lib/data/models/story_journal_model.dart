import 'package:equatable/equatable.dart';

/// A journal entry that records important story events
class JournalEntry extends Equatable {
  final String id;
  final DateTime timestamp;
  final JournalEntryType type;
  final String title;
  final String content;
  final String? location;
  final List<String>? involvedNpcs;
  final Map<String, dynamic>? metadata;
  final bool isImportant;

  const JournalEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    required this.content,
    this.location,
    this.involvedNpcs,
    this.metadata,
    this.isImportant = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'title': title,
      'content': content,
      'location': location,
      'involvedNpcs': involvedNpcs,
      'metadata': metadata,
      'isImportant': isImportant,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: JournalEntryType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => JournalEntryType.narrative,
      ),
      title: json['title'] as String,
      content: json['content'] as String,
      location: json['location'] as String?,
      involvedNpcs: (json['involvedNpcs'] as List<dynamic>?)?.cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      isImportant: json['isImportant'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id, timestamp, type, title, content, location,
    involvedNpcs, metadata, isImportant,
  ];
}

/// Types of journal entries
enum JournalEntryType {
  narrative('Story Event'),
  combat('Combat'),
  discovery('Discovery'),
  npcEncounter('NPC Encounter'),
  questStart('Quest Started'),
  questComplete('Quest Completed'),
  levelUp('Level Up'),
  itemFound('Item Found'),
  locationChange('Location Change'),
  skillCheck('Skill Check'),
  death('Death'),
  resurrection('Resurrection'),
  note('Player Note');

  final String displayName;
  const JournalEntryType(this.displayName);
}

/// The complete story journal for a save
class StoryJournal extends Equatable {
  final String saveId;
  final List<JournalEntry> entries;
  final Map<String, NpcRelationship> npcRelationships;
  final List<String> discoveredLocations;
  final Map<String, dynamic> worldState;
  final List<String> importantDecisions;

  const StoryJournal({
    required this.saveId,
    this.entries = const [],
    this.npcRelationships = const {},
    this.discoveredLocations = const [],
    this.worldState = const {},
    this.importantDecisions = const [],
  });

  /// Get entries by type
  List<JournalEntry> getEntriesByType(JournalEntryType type) {
    return entries.where((e) => e.type == type).toList();
  }

  /// Get entries for a specific day
  List<JournalEntry> getEntriesForDay(DateTime day) {
    return entries.where((e) =>
      e.timestamp.year == day.year &&
      e.timestamp.month == day.month &&
      e.timestamp.day == day.day
    ).toList();
  }

  /// Get important entries
  List<JournalEntry> get importantEntries {
    return entries.where((e) => e.isImportant).toList();
  }

  /// Get recent entries
  List<JournalEntry> getRecentEntries(int count) {
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(count).toList();
  }

  StoryJournal copyWith({
    String? saveId,
    List<JournalEntry>? entries,
    Map<String, NpcRelationship>? npcRelationships,
    List<String>? discoveredLocations,
    Map<String, dynamic>? worldState,
    List<String>? importantDecisions,
  }) {
    return StoryJournal(
      saveId: saveId ?? this.saveId,
      entries: entries ?? this.entries,
      npcRelationships: npcRelationships ?? this.npcRelationships,
      discoveredLocations: discoveredLocations ?? this.discoveredLocations,
      worldState: worldState ?? this.worldState,
      importantDecisions: importantDecisions ?? this.importantDecisions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'saveId': saveId,
      'entries': entries.map((e) => e.toJson()).toList(),
      'npcRelationships': npcRelationships.map((k, v) => MapEntry(k, v.toJson())),
      'discoveredLocations': discoveredLocations,
      'worldState': worldState,
      'importantDecisions': importantDecisions,
    };
  }

  factory StoryJournal.fromJson(Map<String, dynamic> json) {
    return StoryJournal(
      saveId: json['saveId'] as String,
      entries: (json['entries'] as List<dynamic>?)
          ?.map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      npcRelationships: (json['npcRelationships'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, NpcRelationship.fromJson(v as Map<String, dynamic>)),
      ) ?? {},
      discoveredLocations: (json['discoveredLocations'] as List<dynamic>?)?.cast<String>() ?? [],
      worldState: json['worldState'] as Map<String, dynamic>? ?? {},
      importantDecisions: (json['importantDecisions'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  @override
  List<Object?> get props => [
    saveId, entries, npcRelationships, discoveredLocations,
    worldState, importantDecisions,
  ];
}

/// Tracks relationship with an NPC
class NpcRelationship extends Equatable {
  final String npcId;
  final String npcName;
  final int reputation; // -100 to 100
  final RelationshipStatus status;
  final List<String> knownFacts;
  final DateTime? lastInteraction;

  const NpcRelationship({
    required this.npcId,
    required this.npcName,
    this.reputation = 0,
    this.status = RelationshipStatus.stranger,
    this.knownFacts = const [],
    this.lastInteraction,
  });

  Map<String, dynamic> toJson() {
    return {
      'npcId': npcId,
      'npcName': npcName,
      'reputation': reputation,
      'status': status.name,
      'knownFacts': knownFacts,
      'lastInteraction': lastInteraction?.toIso8601String(),
    };
  }

  factory NpcRelationship.fromJson(Map<String, dynamic> json) {
    return NpcRelationship(
      npcId: json['npcId'] as String,
      npcName: json['npcName'] as String,
      reputation: json['reputation'] as int? ?? 0,
      status: RelationshipStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RelationshipStatus.stranger,
      ),
      knownFacts: (json['knownFacts'] as List<dynamic>?)?.cast<String>() ?? [],
      lastInteraction: json['lastInteraction'] != null
          ? DateTime.parse(json['lastInteraction'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    npcId, npcName, reputation, status, knownFacts, lastInteraction,
  ];
}

/// NPC relationship status
enum RelationshipStatus {
  enemy('Enemy'),
  hostile('Hostile'),
  unfriendly('Unfriendly'),
  stranger('Stranger'),
  acquaintance('Acquaintance'),
  friendly('Friendly'),
  ally('Ally'),
  companion('Companion');

  final String displayName;
  const RelationshipStatus(this.displayName);
}

