import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/story_journal_model.dart';
import '../providers/game_providers.dart';

/// Journal screen to view story history
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      appBar: AppBar(
        title: const Text('Story Journal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'Filter entries',
          ),
        ],
      ),
      body: journal == null || journal.entries.isEmpty
          ? _buildEmptyState(context)
          : _buildJournalList(context, journal),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: AppColors.dragonGold.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Journal is Empty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Your adventures will be recorded here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.parchmentDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalList(BuildContext context, StoryJournal journal) {
    // Group entries by day
    final entriesByDay = <String, List<JournalEntry>>{};
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    
    for (final entry in journal.entries.reversed) {
      final dayKey = dateFormat.format(entry.timestamp);
      entriesByDay.putIfAbsent(dayKey, () => []).add(entry);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entriesByDay.length,
      itemBuilder: (context, dayIndex) {
        final dayKey = entriesByDay.keys.elementAt(dayIndex);
        final dayEntries = entriesByDay[dayKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.dragonGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.dragonGold.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      dayKey,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 16),
                      height: 1,
                      color: AppColors.dragonGold.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
            
            // Entries for this day
            ...dayEntries.asMap().entries.map((mapEntry) {
              final index = mapEntry.key;
              final entry = mapEntry.value;
              return _JournalEntryCard(
                entry: entry,
              ).animate()
                .fadeIn(delay: Duration(milliseconds: index * 50), duration: 300.ms)
                .slideX(begin: 0.05, end: 0, duration: 300.ms);
            }),
          ],
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        title: const Text('Filter Entries'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: JournalEntryType.values.map((type) {
            return CheckboxListTile(
              title: Text(type.displayName),
              value: true,
              onChanged: (value) {
                // TODO: Implement filtering
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;

  const _JournalEntryCard({required this.entry});

  Color get _typeColor {
    switch (entry.type) {
      case JournalEntryType.narrative:
        return AppColors.parchment;
      case JournalEntryType.combat:
        return AppColors.dragonBlood;
      case JournalEntryType.discovery:
        return AppColors.forestGreen;
      case JournalEntryType.npcEncounter:
        return AppColors.mysticPurple;
      case JournalEntryType.questStart:
      case JournalEntryType.questComplete:
        return AppColors.arcaneBlue;
      case JournalEntryType.levelUp:
        return AppColors.dragonGold;
      case JournalEntryType.itemFound:
        return AppColors.charismaGold;
      case JournalEntryType.locationChange:
        return AppColors.dexterityGreen;
      case JournalEntryType.skillCheck:
        return AppColors.intelligenceBlue;
      case JournalEntryType.death:
        return AppColors.error;
      case JournalEntryType.resurrection:
        return AppColors.success;
      case JournalEntryType.note:
        return AppColors.parchmentDark;
    }
  }

  IconData get _typeIcon {
    switch (entry.type) {
      case JournalEntryType.narrative:
        return Icons.auto_stories;
      case JournalEntryType.combat:
        return Icons.gavel;
      case JournalEntryType.discovery:
        return Icons.explore;
      case JournalEntryType.npcEncounter:
        return Icons.person;
      case JournalEntryType.questStart:
        return Icons.flag;
      case JournalEntryType.questComplete:
        return Icons.check_circle;
      case JournalEntryType.levelUp:
        return Icons.arrow_upward;
      case JournalEntryType.itemFound:
        return Icons.inventory_2;
      case JournalEntryType.locationChange:
        return Icons.location_on;
      case JournalEntryType.skillCheck:
        return Icons.casino;
      case JournalEntryType.death:
        return Icons.dangerous;
      case JournalEntryType.resurrection:
        return Icons.healing;
      case JournalEntryType.note:
        return Icons.note;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgMedium.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isImportant 
              ? _typeColor.withValues(alpha: 0.5)
              : AppColors.parchmentDark.withValues(alpha: 0.2),
          width: entry.isImportant ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(_typeIcon, color: _typeColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _typeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (entry.isImportant)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.dragonGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 12,
                      color: AppColors.dragonGold,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  timeFormat.format(entry.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchmentDark,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.parchment,
                    height: 1.5,
                  ),
                ),
                
                // Location
                if (entry.location != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.place,
                        size: 14,
                        color: AppColors.parchmentDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.location!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.parchmentDark,
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Involved NPCs
                if (entry.involvedNpcs != null && entry.involvedNpcs!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: entry.involvedNpcs!.map((npc) {
                      return Chip(
                        avatar: const Icon(Icons.person, size: 14),
                        label: Text(npc, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppColors.mysticPurple.withValues(alpha: 0.2),
                      );
                    }).toList(),
                  ),
                ],
                
                // Skill check metadata
                if (entry.type == JournalEntryType.skillCheck && entry.metadata != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMetadataChip('Roll', '${entry.metadata!['roll']}'),
                        const SizedBox(width: 8),
                        Text('+', style: TextStyle(color: AppColors.parchmentDark)),
                        const SizedBox(width: 8),
                        _buildMetadataChip('Mod', '${entry.metadata!['modifier']}'),
                        const SizedBox(width: 8),
                        Text('=', style: TextStyle(color: AppColors.parchmentDark)),
                        const SizedBox(width: 8),
                        _buildMetadataChip(
                          'Total',
                          '${entry.metadata!['total']}',
                          color: entry.metadata!['success'] == true 
                              ? AppColors.success 
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'vs DC ${entry.metadata!['dc']}',
                          style: TextStyle(color: AppColors.parchmentDark, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.parchmentDark).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.parchmentDark,
              fontSize: 9,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.parchment,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

