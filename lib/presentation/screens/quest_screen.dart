import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/quest_model.dart';
import '../providers/game_providers.dart';

/// Quest log screen
class QuestScreen extends ConsumerStatefulWidget {
  const QuestScreen({super.key});

  @override
  ConsumerState<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends ConsumerState<QuestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quests = ref.watch(questsProvider);
    final activeQuests = quests.where((q) => q.status == QuestStatus.active).toList();
    final completedQuests = quests.where((q) => q.status == QuestStatus.completed).toList();
    final availableQuests = quests.where((q) => q.status == QuestStatus.available).toList();

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Quest Log',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.dragonGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${activeQuests.length} Active',
                    style: TextStyle(
                      color: AppColors.dragonGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Tab bar
        Container(
          color: AppColors.bgDark,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.dragonGold,
            labelColor: AppColors.dragonGold,
            unselectedLabelColor: AppColors.parchmentDark,
            tabs: [
              Tab(text: 'Active (${activeQuests.length})'),
              Tab(text: 'Available (${availableQuests.length})'),
              Tab(text: 'Completed (${completedQuests.length})'),
            ],
          ),
        ),
        
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildQuestList(activeQuests, 'No active quests'),
              _buildQuestList(availableQuests, 'No available quests'),
              _buildQuestList(completedQuests, 'No completed quests'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestList(List<QuestModel> quests, String emptyMessage) {
    if (quests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: AppColors.parchmentDark.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.parchmentDark,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        return _QuestCard(
          quest: quests[index],
          onTap: () => _showQuestDetails(quests[index]),
        ).animate()
          .fadeIn(delay: Duration(milliseconds: index * 100), duration: 300.ms)
          .slideX(begin: 0.1, end: 0, duration: 300.ms);
      },
    );
  }

  void _showQuestDetails(QuestModel quest) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _QuestDetailSheet(quest: quest),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final QuestModel quest;
  final VoidCallback onTap;

  const _QuestCard({
    required this.quest,
    required this.onTap,
  });

  Color get _typeColor {
    switch (quest.type) {
      case QuestType.main:
        return AppColors.dragonGold;
      case QuestType.side:
        return AppColors.arcaneBlue;
      case QuestType.bounty:
        return AppColors.dragonBlood;
      case QuestType.exploration:
        return AppColors.forestGreen;
      case QuestType.collection:
        return AppColors.charismaGold;
      case QuestType.escort:
        return AppColors.mysticPurple;
      case QuestType.mystery:
        return AppColors.wisdomSilver;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Quest type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _typeColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      quest.type.displayName,
                      style: TextStyle(
                        color: _typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Level
                  Text(
                    'Lv ${quest.level}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.parchmentDark,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Tracked indicator
                  if (quest.isTracked)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.dragonGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.push_pin,
                        color: AppColors.dragonGold,
                        size: 14,
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Title
              Text(
                quest.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.parchment,
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Description preview
              Text(
                quest.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.parchmentDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Progress bar (for active quests)
              if (quest.status == QuestStatus.active && quest.objectives.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: quest.progress,
                          backgroundColor: AppColors.bgDark,
                          valueColor: AlwaysStoppedAnimation(_typeColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(quest.progress * 100).toInt()}%',
                      style: TextStyle(
                        color: _typeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Current objective
              if (quest.currentObjective != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      color: _typeColor,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quest.currentObjective!.description,
                        style: TextStyle(
                          color: _typeColor,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestDetailSheet extends StatelessWidget {
  final QuestModel quest;

  const _QuestDetailSheet({required this.quest});

  Color get _typeColor {
    switch (quest.type) {
      case QuestType.main:
        return AppColors.dragonGold;
      case QuestType.side:
        return AppColors.arcaneBlue;
      case QuestType.bounty:
        return AppColors.dragonBlood;
      case QuestType.exploration:
        return AppColors.forestGreen;
      case QuestType.collection:
        return AppColors.charismaGold;
      case QuestType.escort:
        return AppColors.mysticPurple;
      case QuestType.mystery:
        return AppColors.wisdomSilver;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: _typeColor.withValues(alpha: 0.5)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _typeColor.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.parchmentDark,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Quest type and level
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _typeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _typeColor),
                            ),
                            child: Text(
                              quest.type.displayName,
                              style: TextStyle(
                                color: _typeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Level ${quest.level}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.parchmentDark,
                            ),
                          ),
                          const Spacer(),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor().withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              quest.status.displayName,
                              style: TextStyle(
                                color: _getStatusColor(),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Title
                      Text(
                        quest.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.parchment,
                        ),
                      ),
                      
                      if (quest.giverNpcName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: AppColors.parchmentDark),
                            const SizedBox(width: 8),
                            Text(
                              'Given by: ${quest.giverNpcName}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.parchmentDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      if (quest.location != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: AppColors.parchmentDark),
                            const SizedBox(width: 8),
                            Text(
                              quest.location!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.parchmentDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Description
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _typeColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quest.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.parchment,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Objectives
                if (quest.objectives.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Objectives',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _typeColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...quest.objectives.map((obj) => _ObjectiveRow(
                          objective: obj,
                          color: _typeColor,
                        )),
                      ],
                    ),
                  ),
                
                // Rewards
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rewards',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _typeColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgMedium,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (quest.rewards.experiencePoints > 0)
                              _RewardChip(
                                icon: Icons.star,
                                label: 'XP',
                                value: '${quest.rewards.experiencePoints}',
                                color: AppColors.arcaneBlue,
                              ),
                            if (quest.rewards.gold > 0)
                              _RewardChip(
                                icon: Icons.monetization_on,
                                label: 'Gold',
                                value: '${quest.rewards.gold}',
                                color: AppColors.charismaGold,
                              ),
                            if (quest.rewards.itemIds.isNotEmpty)
                              _RewardChip(
                                icon: Icons.inventory_2,
                                label: 'Items',
                                value: '${quest.rewards.itemIds.length}',
                                color: AppColors.forestGreen,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor() {
    switch (quest.status) {
      case QuestStatus.locked:
        return AppColors.parchmentDark;
      case QuestStatus.available:
        return AppColors.info;
      case QuestStatus.active:
        return AppColors.dragonGold;
      case QuestStatus.completed:
        return AppColors.success;
      case QuestStatus.failed:
        return AppColors.error;
    }
  }
}

class _ObjectiveRow extends StatelessWidget {
  final QuestObjective objective;
  final Color color;

  const _ObjectiveRow({
    required this.objective,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: objective.isComplete
                  ? color.withValues(alpha: 0.2)
                  : Colors.transparent,
              border: Border.all(
                color: objective.isComplete ? color : AppColors.parchmentDark,
                width: 2,
              ),
            ),
            child: objective.isComplete
                ? Icon(Icons.check, color: color, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          
          // Description and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  objective.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: objective.isComplete
                        ? AppColors.parchmentDark
                        : AppColors.parchment,
                    decoration: objective.isComplete
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (objective.targetProgress > 1) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: objective.progress,
                            backgroundColor: AppColors.bgDark,
                            valueColor: AlwaysStoppedAnimation(color),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${objective.currentProgress}/${objective.targetProgress}',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Optional badge
          if (objective.isOptional)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.parchmentDark.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Optional',
                style: TextStyle(
                  color: AppColors.parchmentDark,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _RewardChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.parchmentDark,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}


