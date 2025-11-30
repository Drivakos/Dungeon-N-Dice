import 'package:equatable/equatable.dart';
import 'character_model.dart';
import 'item_model.dart';
import 'quest_model.dart';
import 'story_message_model.dart';

/// Represents the complete game state
class GameStateModel extends Equatable {
  final String id;
  final String saveName;
  final CharacterModel character;
  final InventoryModel inventory;
  final List<QuestModel> quests;
  final SceneModel currentScene;
  final List<StoryMessageModel> storyLog;
  final Map<String, dynamic> worldFlags;
  final Map<String, int> factionReputation;
  final int gold;
  final DateTime createdAt;
  final DateTime lastPlayedAt;
  final Duration totalPlayTime;
  final GameDifficulty difficulty;

  const GameStateModel({
    required this.id,
    required this.saveName,
    required this.character,
    required this.inventory,
    this.quests = const [],
    required this.currentScene,
    this.storyLog = const [],
    this.worldFlags = const {},
    this.factionReputation = const {},
    this.gold = 0,
    required this.createdAt,
    required this.lastPlayedAt,
    this.totalPlayTime = Duration.zero,
    this.difficulty = GameDifficulty.normal,
  });

  /// Get active quests
  List<QuestModel> get activeQuests =>
      quests.where((q) => q.status == QuestStatus.active).toList();

  /// Get completed quests
  List<QuestModel> get completedQuests =>
      quests.where((q) => q.status == QuestStatus.completed).toList();

  /// Get tracked quest
  QuestModel? get trackedQuest {
    try {
      return quests.firstWhere((q) => q.isTracked);
    } catch (_) {
      return null;
    }
  }

  GameStateModel copyWith({
    String? id,
    String? saveName,
    CharacterModel? character,
    InventoryModel? inventory,
    List<QuestModel>? quests,
    SceneModel? currentScene,
    List<StoryMessageModel>? storyLog,
    Map<String, dynamic>? worldFlags,
    Map<String, int>? factionReputation,
    int? gold,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    Duration? totalPlayTime,
    GameDifficulty? difficulty,
  }) {
    return GameStateModel(
      id: id ?? this.id,
      saveName: saveName ?? this.saveName,
      character: character ?? this.character,
      inventory: inventory ?? this.inventory,
      quests: quests ?? this.quests,
      currentScene: currentScene ?? this.currentScene,
      storyLog: storyLog ?? this.storyLog,
      worldFlags: worldFlags ?? this.worldFlags,
      factionReputation: factionReputation ?? this.factionReputation,
      gold: gold ?? this.gold,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      totalPlayTime: totalPlayTime ?? this.totalPlayTime,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saveName': saveName,
      'character': character.toJson(),
      'inventory': inventory.toJson(),
      'quests': quests.map((q) => q.toJson()).toList(),
      'currentScene': currentScene.toJson(),
      'storyLog': storyLog.map((m) => m.toJson()).toList(),
      'worldFlags': worldFlags,
      'factionReputation': factionReputation,
      'gold': gold,
      'createdAt': createdAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'totalPlayTime': totalPlayTime.inSeconds,
      'difficulty': difficulty.name,
    };
  }

  factory GameStateModel.fromJson(Map<String, dynamic> json) {
    return GameStateModel(
      id: json['id'] as String,
      saveName: json['saveName'] as String,
      character: CharacterModel.fromJson(json['character'] as Map<String, dynamic>),
      inventory: InventoryModel.fromJson(json['inventory'] as Map<String, dynamic>),
      quests: (json['quests'] as List<dynamic>?)
          ?.map((q) => QuestModel.fromJson(q as Map<String, dynamic>))
          .toList() ?? [],
      currentScene: SceneModel.fromJson(json['currentScene'] as Map<String, dynamic>),
      storyLog: (json['storyLog'] as List<dynamic>?)
          ?.map((m) => StoryMessageModel.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      worldFlags: json['worldFlags'] as Map<String, dynamic>? ?? {},
      factionReputation: (json['factionReputation'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as int),
      ) ?? {},
      gold: json['gold'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
      totalPlayTime: Duration(seconds: json['totalPlayTime'] as int? ?? 0),
      difficulty: GameDifficulty.values.firstWhere(
        (d) => d.name == json['difficulty'],
        orElse: () => GameDifficulty.normal,
      ),
    );
  }

  @override
  List<Object?> get props => [
    id, saveName, character, inventory, quests, currentScene, storyLog,
    worldFlags, factionReputation, gold, createdAt, lastPlayedAt,
    totalPlayTime, difficulty,
  ];
}

/// Game difficulty levels
enum GameDifficulty {
  easy('Easy', 0.75),
  normal('Normal', 1.0),
  hard('Hard', 1.25),
  nightmare('Nightmare', 1.5);

  final String displayName;
  final double damageMultiplier;

  const GameDifficulty(this.displayName, this.damageMultiplier);
}

/// Represents the player's inventory
class InventoryModel extends Equatable {
  final List<ItemModel> items;
  final int maxSlots;
  final Map<EquipmentSlot, String?> equippedItems;

  const InventoryModel({
    this.items = const [],
    this.maxSlots = 30,
    this.equippedItems = const {},
  });

  /// Get total weight of all items
  double get totalWeight => items.fold(0, (sum, item) => sum + (item.weight * item.quantity));

  /// Check if inventory is full
  bool get isFull => items.length >= maxSlots;

  /// Get item by ID
  ItemModel? getItem(String id) {
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get equipped item for slot
  ItemModel? getEquippedItem(EquipmentSlot slot) {
    final itemId = equippedItems[slot];
    if (itemId == null) return null;
    return getItem(itemId);
  }

  InventoryModel copyWith({
    List<ItemModel>? items,
    int? maxSlots,
    Map<EquipmentSlot, String?>? equippedItems,
  }) {
    return InventoryModel(
      items: items ?? this.items,
      maxSlots: maxSlots ?? this.maxSlots,
      equippedItems: equippedItems ?? this.equippedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()).toList(),
      'maxSlots': maxSlots,
      'equippedItems': equippedItems.map((k, v) => MapEntry(k.name, v)),
    };
  }

  factory InventoryModel.fromJson(Map<String, dynamic> json) {
    return InventoryModel(
      items: (json['items'] as List<dynamic>?)
          ?.map((i) => ItemModel.fromJson(i as Map<String, dynamic>))
          .toList() ?? [],
      maxSlots: json['maxSlots'] as int? ?? 30,
      equippedItems: (json['equippedItems'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(
          EquipmentSlot.values.firstWhere((s) => s.name == k),
          v as String?,
        ),
      ) ?? {},
    );
  }

  @override
  List<Object?> get props => [items, maxSlots, equippedItems];
}

/// Equipment slots
enum EquipmentSlot {
  head('Head'),
  neck('Neck'),
  chest('Chest'),
  hands('Hands'),
  mainHand('Main Hand'),
  offHand('Off Hand'),
  ring1('Ring 1'),
  ring2('Ring 2'),
  feet('Feet'),
  back('Back');

  final String displayName;
  const EquipmentSlot(this.displayName);
}

/// Represents the current scene/location
class SceneModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final SceneType type;
  final List<String> availableExits;
  final List<String> presentNpcIds;
  final List<String> presentMonsterIds;
  final List<String> availableItemIds;
  final Map<String, dynamic> sceneFlags;
  final String? ambientDescription;
  final bool isInCombat;
  final String? backgroundImageAsset;

  const SceneModel({
    required this.id,
    required this.name,
    required this.description,
    this.type = SceneType.exploration,
    this.availableExits = const [],
    this.presentNpcIds = const [],
    this.presentMonsterIds = const [],
    this.availableItemIds = const [],
    this.sceneFlags = const {},
    this.ambientDescription,
    this.isInCombat = false,
    this.backgroundImageAsset,
  });

  SceneModel copyWith({
    String? id,
    String? name,
    String? description,
    SceneType? type,
    List<String>? availableExits,
    List<String>? presentNpcIds,
    List<String>? presentMonsterIds,
    List<String>? availableItemIds,
    Map<String, dynamic>? sceneFlags,
    String? ambientDescription,
    bool? isInCombat,
    String? backgroundImageAsset,
  }) {
    return SceneModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      availableExits: availableExits ?? this.availableExits,
      presentNpcIds: presentNpcIds ?? this.presentNpcIds,
      presentMonsterIds: presentMonsterIds ?? this.presentMonsterIds,
      availableItemIds: availableItemIds ?? this.availableItemIds,
      sceneFlags: sceneFlags ?? this.sceneFlags,
      ambientDescription: ambientDescription ?? this.ambientDescription,
      isInCombat: isInCombat ?? this.isInCombat,
      backgroundImageAsset: backgroundImageAsset ?? this.backgroundImageAsset,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'availableExits': availableExits,
      'presentNpcIds': presentNpcIds,
      'presentMonsterIds': presentMonsterIds,
      'availableItemIds': availableItemIds,
      'sceneFlags': sceneFlags,
      'ambientDescription': ambientDescription,
      'isInCombat': isInCombat,
      'backgroundImageAsset': backgroundImageAsset,
    };
  }

  factory SceneModel.fromJson(Map<String, dynamic> json) {
    return SceneModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: SceneType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SceneType.exploration,
      ),
      availableExits: (json['availableExits'] as List<dynamic>?)?.cast<String>() ?? [],
      presentNpcIds: (json['presentNpcIds'] as List<dynamic>?)?.cast<String>() ?? [],
      presentMonsterIds: (json['presentMonsterIds'] as List<dynamic>?)?.cast<String>() ?? [],
      availableItemIds: (json['availableItemIds'] as List<dynamic>?)?.cast<String>() ?? [],
      sceneFlags: json['sceneFlags'] as Map<String, dynamic>? ?? {},
      ambientDescription: json['ambientDescription'] as String?,
      isInCombat: json['isInCombat'] as bool? ?? false,
      backgroundImageAsset: json['backgroundImageAsset'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id, name, description, type, availableExits, presentNpcIds,
    presentMonsterIds, availableItemIds, sceneFlags, ambientDescription,
    isInCombat, backgroundImageAsset,
  ];
}

/// Scene types
enum SceneType {
  exploration('Exploration'),
  combat('Combat'),
  dialogue('Dialogue'),
  shop('Shop'),
  rest('Rest'),
  puzzle('Puzzle'),
  cutscene('Cutscene');

  final String displayName;
  const SceneType(this.displayName);
}


