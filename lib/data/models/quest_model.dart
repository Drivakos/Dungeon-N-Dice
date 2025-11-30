import 'package:equatable/equatable.dart';

/// Represents a quest in the game
class QuestModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final QuestStatus status;
  final int level;
  final List<QuestObjective> objectives;
  final QuestRewards rewards;
  final String? giverNpcId;
  final String? giverNpcName;
  final String? location;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<String> requiredQuestIds;
  final bool isTracked;

  const QuestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.status = QuestStatus.available,
    this.level = 1,
    this.objectives = const [],
    required this.rewards,
    this.giverNpcId,
    this.giverNpcName,
    this.location,
    this.startedAt,
    this.completedAt,
    this.requiredQuestIds = const [],
    this.isTracked = false,
  });

  /// Check if all objectives are complete
  bool get isComplete => objectives.every((o) => o.isComplete);

  /// Get progress percentage
  double get progress {
    if (objectives.isEmpty) return 0;
    final completed = objectives.where((o) => o.isComplete).length;
    return completed / objectives.length;
  }

  /// Get current objective (first incomplete)
  QuestObjective? get currentObjective {
    try {
      return objectives.firstWhere((o) => !o.isComplete);
    } catch (_) {
      return null;
    }
  }

  QuestModel copyWith({
    String? id,
    String? title,
    String? description,
    QuestType? type,
    QuestStatus? status,
    int? level,
    List<QuestObjective>? objectives,
    QuestRewards? rewards,
    String? giverNpcId,
    String? giverNpcName,
    String? location,
    DateTime? startedAt,
    DateTime? completedAt,
    List<String>? requiredQuestIds,
    bool? isTracked,
  }) {
    return QuestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      level: level ?? this.level,
      objectives: objectives ?? this.objectives,
      rewards: rewards ?? this.rewards,
      giverNpcId: giverNpcId ?? this.giverNpcId,
      giverNpcName: giverNpcName ?? this.giverNpcName,
      location: location ?? this.location,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      requiredQuestIds: requiredQuestIds ?? this.requiredQuestIds,
      isTracked: isTracked ?? this.isTracked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'status': status.name,
      'level': level,
      'objectives': objectives.map((o) => o.toJson()).toList(),
      'rewards': rewards.toJson(),
      'giverNpcId': giverNpcId,
      'giverNpcName': giverNpcName,
      'location': location,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'requiredQuestIds': requiredQuestIds,
      'isTracked': isTracked,
    };
  }

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    return QuestModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: QuestType.values.firstWhere((t) => t.name == json['type']),
      status: QuestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => QuestStatus.available,
      ),
      level: json['level'] as int? ?? 1,
      objectives: (json['objectives'] as List<dynamic>?)
          ?.map((o) => QuestObjective.fromJson(o as Map<String, dynamic>))
          .toList() ?? [],
      rewards: QuestRewards.fromJson(json['rewards'] as Map<String, dynamic>),
      giverNpcId: json['giverNpcId'] as String?,
      giverNpcName: json['giverNpcName'] as String?,
      location: json['location'] as String?,
      startedAt: json['startedAt'] != null 
          ? DateTime.parse(json['startedAt'] as String) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt'] as String) 
          : null,
      requiredQuestIds: (json['requiredQuestIds'] as List<dynamic>?)?.cast<String>() ?? [],
      isTracked: json['isTracked'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id, title, description, type, status, level, objectives, rewards,
    giverNpcId, giverNpcName, location, startedAt, completedAt,
    requiredQuestIds, isTracked,
  ];
}

/// Quest types
enum QuestType {
  main('Main Quest'),
  side('Side Quest'),
  bounty('Bounty'),
  exploration('Exploration'),
  collection('Collection'),
  escort('Escort'),
  mystery('Mystery');

  final String displayName;
  const QuestType(this.displayName);
}

/// Quest status
enum QuestStatus {
  locked('Locked'),
  available('Available'),
  active('Active'),
  completed('Completed'),
  failed('Failed');

  final String displayName;
  const QuestStatus(this.displayName);
}

/// Represents a quest objective
class QuestObjective extends Equatable {
  final String id;
  final String description;
  final ObjectiveType type;
  final int currentProgress;
  final int targetProgress;
  final bool isOptional;
  final String? targetId;
  final String? targetLocation;

  const QuestObjective({
    required this.id,
    required this.description,
    required this.type,
    this.currentProgress = 0,
    this.targetProgress = 1,
    this.isOptional = false,
    this.targetId,
    this.targetLocation,
  });

  /// Check if objective is complete
  bool get isComplete => currentProgress >= targetProgress;

  /// Get progress percentage
  double get progress => currentProgress / targetProgress;

  QuestObjective copyWith({
    String? id,
    String? description,
    ObjectiveType? type,
    int? currentProgress,
    int? targetProgress,
    bool? isOptional,
    String? targetId,
    String? targetLocation,
  }) {
    return QuestObjective(
      id: id ?? this.id,
      description: description ?? this.description,
      type: type ?? this.type,
      currentProgress: currentProgress ?? this.currentProgress,
      targetProgress: targetProgress ?? this.targetProgress,
      isOptional: isOptional ?? this.isOptional,
      targetId: targetId ?? this.targetId,
      targetLocation: targetLocation ?? this.targetLocation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'type': type.name,
      'currentProgress': currentProgress,
      'targetProgress': targetProgress,
      'isOptional': isOptional,
      'targetId': targetId,
      'targetLocation': targetLocation,
    };
  }

  factory QuestObjective.fromJson(Map<String, dynamic> json) {
    return QuestObjective(
      id: json['id'] as String,
      description: json['description'] as String,
      type: ObjectiveType.values.firstWhere((t) => t.name == json['type']),
      currentProgress: json['currentProgress'] as int? ?? 0,
      targetProgress: json['targetProgress'] as int? ?? 1,
      isOptional: json['isOptional'] as bool? ?? false,
      targetId: json['targetId'] as String?,
      targetLocation: json['targetLocation'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id, description, type, currentProgress, targetProgress,
    isOptional, targetId, targetLocation,
  ];
}

/// Objective types
enum ObjectiveType {
  kill('Kill'),
  collect('Collect'),
  talkTo('Talk To'),
  explore('Explore'),
  escort('Escort'),
  defend('Defend'),
  interact('Interact'),
  solve('Solve');

  final String displayName;
  const ObjectiveType(this.displayName);
}

/// Quest rewards
class QuestRewards extends Equatable {
  final int experiencePoints;
  final int gold;
  final List<String> itemIds;
  final Map<String, int>? reputationChanges;

  const QuestRewards({
    this.experiencePoints = 0,
    this.gold = 0,
    this.itemIds = const [],
    this.reputationChanges,
  });

  Map<String, dynamic> toJson() {
    return {
      'experiencePoints': experiencePoints,
      'gold': gold,
      'itemIds': itemIds,
      'reputationChanges': reputationChanges,
    };
  }

  factory QuestRewards.fromJson(Map<String, dynamic> json) {
    return QuestRewards(
      experiencePoints: json['experiencePoints'] as int? ?? 0,
      gold: json['gold'] as int? ?? 0,
      itemIds: (json['itemIds'] as List<dynamic>?)?.cast<String>() ?? [],
      reputationChanges: (json['reputationChanges'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as int),
      ),
    );
  }

  @override
  List<Object?> get props => [experiencePoints, gold, itemIds, reputationChanges];
}


