import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_providers.dart';

/// Save files management screen
class SavesScreen extends ConsumerStatefulWidget {
  const SavesScreen({super.key});

  @override
  ConsumerState<SavesScreen> createState() => _SavesScreenState();
}

class _SavesScreenState extends ConsumerState<SavesScreen> {
  bool _isDeleting = false;
  String? _deletingSaveId;

  @override
  Widget build(BuildContext context) {
    final savesAsync = ref.watch(userSavesProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context, currentUser),
              
              // Saves List
              Expanded(
                child: savesAsync.when(
                  data: (saves) => _buildSavesList(context, saves),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.dragonGold),
                  ),
                  error: (e, _) => _buildError(context, e.toString()),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSaveDialog(context),
        backgroundColor: AppColors.dragonGold,
        foregroundColor: AppColors.bgDark,
        icon: const Icon(Icons.add),
        label: Text(
          'New Adventure',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
        ),
      ).animate().fadeIn().slideY(begin: 1, end: 0),
    );
  }

  Widget _buildHeader(BuildContext context, AppUser? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgMedium.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.parchment),
          ),
          const SizedBox(width: 12),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Adventures',
                  style: GoogleFonts.cinzel(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dragonGold,
                  ),
                ),
                if (user != null)
                  Text(
                    user.displayName,
                    style: TextStyle(
                      color: AppColors.parchmentDark,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          
          // User avatar
          if (user != null)
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.mysticPurple, AppColors.dragonBlood],
                ),
                border: Border.all(color: AppColors.dragonGold, width: 2),
              ),
              child: Center(
                child: Text(
                  user.displayName.isNotEmpty 
                      ? user.displayName[0].toUpperCase()
                      : user.email[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.3, end: 0);
  }

  Widget _buildSavesList(BuildContext context, List<GameSaveInfo> saves) {
    if (saves.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: saves.length,
      itemBuilder: (context, index) {
        final save = saves[index];
        return _buildSaveCard(context, save, index);
      },
    );
  }

  Widget _buildSaveCard(BuildContext context, GameSaveInfo save, int index) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final isDeleting = _isDeleting && _deletingSaveId == save.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bgMedium,
            AppColors.bgDark.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDeleting ? null : () => _loadSave(context, save),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Character info + Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Character Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getClassColor(save.characterClass),
                            _getClassColor(save.characterClass).withValues(alpha: 0.6),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.dragonGold.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Lv${save.characterLevel}',
                          style: GoogleFonts.cinzel(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Character Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            save.characterName,
                            style: GoogleFonts.cinzel(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.dragonGold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildClassBadge(save.characterClass),
                              const SizedBox(width: 8),
                              Text(
                                'Level ${save.characterLevel}',
                                style: TextStyle(
                                  color: AppColors.parchmentDark,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Action buttons
                    if (isDeleting)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    else
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppColors.parchmentDark),
                        color: AppColors.bgMedium,
                        onSelected: (value) {
                          if (value == 'delete') {
                            _confirmDelete(context, save);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: AppColors.error, size: 20),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Divider
                Container(
                  height: 1,
                  color: AppColors.borderColor.withValues(alpha: 0.3),
                ),
                
                const SizedBox(height: 12),
                
                // Bottom row: Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Save name
                    Expanded(
                      child: Text(
                        save.saveName,
                        style: TextStyle(
                          color: AppColors.parchment,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Play time
                    Row(
                      children: [
                        Icon(Icons.timer, size: 14, color: AppColors.parchmentDark),
                        const SizedBox(width: 4),
                        Text(
                          save.playTimeFormatted,
                          style: TextStyle(
                            color: AppColors.parchmentDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Last played
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: AppColors.parchmentDark),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(save.lastPlayedAt),
                          style: TextStyle(
                            color: AppColors.parchmentDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 100).ms)
      .fadeIn()
      .slideX(begin: 0.1, end: 0);
  }

  Widget _buildClassBadge(String characterClass) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getClassColor(characterClass).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getClassColor(characterClass).withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        characterClass,
        style: TextStyle(
          color: _getClassColor(characterClass),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getClassColor(String characterClass) {
    switch (characterClass.toLowerCase()) {
      case 'fighter':
        return AppColors.dragonBlood;
      case 'wizard':
        return AppColors.mysticPurple;
      case 'rogue':
        return Colors.grey;
      case 'cleric':
        return AppColors.dragonGold;
      case 'ranger':
        return Colors.green;
      case 'paladin':
        return Colors.amber;
      case 'barbarian':
        return Colors.orange;
      case 'bard':
        return Colors.pink;
      case 'druid':
        return Colors.teal;
      case 'monk':
        return Colors.cyan;
      case 'sorcerer':
        return Colors.deepPurple;
      case 'warlock':
        return Colors.indigo;
      default:
        return AppColors.dragonGold;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgMedium.withValues(alpha: 0.5),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: const Icon(
                Icons.auto_stories,
                size: 60,
                color: AppColors.parchmentDark,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            
            const SizedBox(height: 24),
            
            Text(
              'No Adventures Yet',
              style: GoogleFonts.cinzel(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.dragonGold,
              ),
            ).animate().fadeIn(delay: 200.ms),
            
            const SizedBox(height: 12),
            
            Text(
              'Start a new adventure to create your\nfirst save file',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.parchmentDark,
                fontSize: 16,
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Saves',
              style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.parchmentDark),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(userSavesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dragonGold,
                foregroundColor: AppColors.bgDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSave(BuildContext context, GameSaveInfo save) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.dragonGold),
      ),
    );
    
    try {
      // Load save from cloud
      final cloudService = ref.read(cloudSaveServiceProvider);
      final saveData = await cloudService.loadSave(save.id);
      
      if (saveData != null) {
        // Use the proper load method that also loads the story summary
        ref.read(selectedSaveIdProvider.notifier).state = save.id;
        await ref.read(gameStateProvider.notifier).loadGameFromState(saveData, save.id);
        
        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading
          context.go('/story');
        }
      } else {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load save'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCreateSaveDialog(BuildContext context) {
    context.push('/character-creation');
  }

  void _confirmDelete(BuildContext context, GameSaveInfo save) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Save?',
          style: GoogleFonts.cinzel(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this save?',
              style: TextStyle(color: AppColors.parchment),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppColors.dragonGold, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          save.characterName,
                          style: TextStyle(
                            color: AppColors.dragonGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Level ${save.characterLevel} ${save.characterClass}',
                          style: TextStyle(
                            color: AppColors.parchmentDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.parchmentDark),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSave(save.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSave(String saveId) async {
    setState(() {
      _isDeleting = true;
      _deletingSaveId = saveId;
    });

    final success = await ref.read(cloudSaveServiceProvider).deleteSave(saveId);

    if (!mounted) return;

    setState(() {
      _isDeleting = false;
      _deletingSaveId = null;
    });

    if (success) {
      ref.invalidate(userSavesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save deleted successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete save'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

