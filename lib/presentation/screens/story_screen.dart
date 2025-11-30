import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/story_message_model.dart';
import '../../data/models/game_state_model.dart';
import '../../data/models/character_model.dart';
import '../providers/game_providers.dart';
import 'journal_screen.dart';

/// Main story/chat screen
class StoryScreen extends ConsumerStatefulWidget {
  const StoryScreen({super.key});

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      final position = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storyLog = ref.watch(storyLogProvider);
    final storyState = ref.watch(storyViewModelProvider);
    final currentScene = ref.watch(currentSceneProvider);
    final character = ref.watch(characterProvider);

    // Auto-scroll when new messages arrive
    ref.listen<List<StoryMessageModel>>(storyLogProvider, (previous, next) {
      if (previous != null && next.length > previous.length) {
        Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
      }
    });

    // Auto-scroll when processing state changes (for typing indicator)
    ref.listen<StoryViewState>(storyViewModelProvider, (previous, next) {
      if (next.processingState == StoryProcessingState.processing ||
          (previous?.processingState == StoryProcessingState.processing && 
           next.processingState == StoryProcessingState.idle)) {
        Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
      }
    });

    // Check if we're in combat by looking for recent combat messages
    final isInCombat = currentScene?.isInCombat == true || 
        storyLog.where((m) => m.type == MessageType.combat).isNotEmpty;

    return Column(
      children: [
        // Header with scene info
        _buildHeader(context, currentScene?.name ?? 'Unknown', character),
        
        // Combat status panel (when in combat)
        if (isInCombat && character != null)
          _buildCombatStatusPanel(context, character, storyLog),
        
        // Story messages
        Expanded(
          child: _buildStoryLog(storyLog, storyState),
        ),
        
        // Quick actions
        if (storyState.suggestedActions != null && 
            storyState.suggestedActions!.isNotEmpty)
          _buildQuickActions(storyState.suggestedActions!),
        
        // Input area
        _buildInputArea(storyState),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String sceneName, character) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgDark,
            AppColors.bgDark.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Scene indicator
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sceneName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.dragonGold,
                    ),
                  ),
                  if (character != null)
                    Text(
                      '${character.name} • Level ${character.level} ${character.characterClass.displayName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.parchmentDark,
                      ),
                    ),
                ],
              ),
            ),
            
            // Journal button
            IconButton(
              icon: const Icon(Icons.book, color: AppColors.dragonGold),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const JournalScreen(),
                  ),
                );
              },
              tooltip: 'View Journal',
            ),
            
            // HP indicator
            if (character != null)
              _buildHPIndicator(character),
          ],
        ),
      ),
    );
  }

  /// Build combat status panel showing all participants
  Widget _buildCombatStatusPanel(BuildContext context, CharacterModel character, List<StoryMessageModel> storyLog) {
    // Extract enemy info from recent combat messages
    final combatMessages = storyLog.where((m) => m.type == MessageType.combat).toList();
    final enemyNames = <String>{};
    
    for (final msg in combatMessages) {
      if (msg.combatResult != null) {
        // Add defender if it's not the player
        if (msg.combatResult!.defenderName != character.name) {
          enemyNames.add(msg.combatResult!.defenderName);
        }
        // Add attacker if it's not the player
        if (msg.combatResult!.attackerName != character.name) {
          enemyNames.add(msg.combatResult!.attackerName);
        }
      }
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.dragonBlood.withValues(alpha: 0.2),
            AppColors.bgDark.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dragonBlood.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.dragonBlood.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Combat header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.dragonBlood.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.sports_kabaddi, color: AppColors.dragonBlood, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                '⚔️ COMBAT IN PROGRESS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.dragonBlood,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Participants row
          Row(
            children: [
              // Player
              Expanded(
                child: _buildCombatParticipant(
                  context,
                  name: character.name,
                  currentHP: character.currentHitPoints,
                  maxHP: character.maxHitPoints,
                  isPlayer: true,
                ),
              ),
              
              // VS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: AppColors.dragonBlood,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              
              // Enemies
              Expanded(
                child: enemyNames.isEmpty
                    ? _buildCombatParticipant(
                        context,
                        name: 'Enemy',
                        currentHP: null,
                        maxHP: null,
                        isPlayer: false,
                      )
                    : Column(
                        children: enemyNames.take(3).map((name) => 
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _buildCombatParticipant(
                              context,
                              name: name,
                              currentHP: null, // We don't track enemy HP in messages
                              maxHP: null,
                              isPlayer: false,
                            ),
                          ),
                        ).toList(),
                      ),
              ),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 300.ms)
      .slideY(begin: -0.2, end: 0, duration: 300.ms);
  }
  
  /// Build a single combat participant display
  Widget _buildCombatParticipant(
    BuildContext context, {
    required String name,
    required int? currentHP,
    required int? maxHP,
    required bool isPlayer,
  }) {
    final color = isPlayer ? AppColors.dragonGold : AppColors.dragonBlood;
    final hpPercent = (currentHP != null && maxHP != null && maxHP > 0) 
        ? currentHP / maxHP 
        : 1.0;
    
    Color hpColor;
    if (hpPercent > 0.5) {
      hpColor = AppColors.success;
    } else if (hpPercent > 0.25) {
      hpColor = AppColors.warning;
    } else {
      hpColor = AppColors.error;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: isPlayer
                  ? Icon(Icons.person, color: color, size: 18)
                  : Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Name
          Text(
            name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          // HP bar (only for player or if we have HP data)
          if (currentHP != null && maxHP != null) ...[
            const SizedBox(height: 6),
            
            // HP bar background
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: hpPercent.clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [hpColor, hpColor.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 2),
            
            // HP text
            Text(
              '$currentHP / $maxHP',
              style: TextStyle(
                color: hpColor,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHPIndicator(character) {
    final hpPercent = character.currentHitPoints / character.maxHitPoints;
    final hpColor = hpPercent > 0.5 
        ? AppColors.success 
        : hpPercent > 0.25 
            ? AppColors.warning 
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgMedium,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hpColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, color: hpColor, size: 16),
          const SizedBox(width: 6),
          Text(
            '${character.currentHitPoints}/${character.maxHitPoints}',
            style: TextStyle(
              color: hpColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryLog(List<StoryMessageModel> messages, StoryViewState state) {
    final currentScene = ref.watch(currentSceneProvider);
    
    // Calculate total items: scene intro + messages + typing indicator
    final itemCount = 1 + messages.length + 
        (state.processingState == StoryProcessingState.processing ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // First item: Scene introduction
        if (index == 0) {
          return _buildSceneIntro(currentScene);
        }
        
        // Typing indicator at the end
        if (index == itemCount - 1 && state.processingState == StoryProcessingState.processing) {
          return _buildTypingIndicator();
        }
        
        // Story messages
        final messageIndex = index - 1;
        if (messageIndex < messages.length) {
          final message = messages[messageIndex];
          return _StoryMessageWidget(
            message: message,
            isLatest: messageIndex == messages.length - 1 && 
                      state.processingState != StoryProcessingState.processing,
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }
  
  Widget _buildSceneIntro(SceneModel? scene) {
    if (scene == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.dragonGold.withValues(alpha: 0.15),
            AppColors.mysticPurple.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.dragonGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppColors.dragonGold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                scene.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.dragonGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            scene.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.parchment,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (scene.ambientDescription != null) ...[
            const SizedBox(height: 8),
            Text(
              scene.ambientDescription!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.parchmentDark,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'What do you do?',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.dragonGold,
              ),
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms)
      .slideY(begin: -0.1, end: 0, duration: 600.ms);
  }

  Widget _buildEmptyState() {
    final currentScene = ref.watch(currentSceneProvider);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              size: 64,
              color: AppColors.dragonGold.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Your Adventure Begins',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (currentScene != null)
              Text(
                currentScene.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.parchmentDark,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            Text(
              'Type your action below to begin...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.parchmentDark.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(duration: 600.ms)
      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 600.ms);
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgMedium,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.dragonGold,
        shape: BoxShape.circle,
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(),
    ).scale(
      begin: const Offset(0.5, 0.5),
      end: const Offset(1, 1),
      duration: 600.ms,
      delay: Duration(milliseconds: index * 200),
    );
  }

  Widget _buildQuickActions(List<String> actions) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(actions[index]),
            backgroundColor: AppColors.bgMedium,
            side: BorderSide(color: AppColors.dragonGold.withValues(alpha: 0.5)),
            labelStyle: TextStyle(color: AppColors.parchment, fontSize: 12),
            onPressed: () {
              _textController.text = actions[index];
              _submitAction();
            },
          );
        },
      ),
    );
  }

  Widget _buildInputArea(StoryViewState state) {
    final isProcessing = state.processingState == StoryProcessingState.processing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        border: Border(
          top: BorderSide(
            color: AppColors.dragonGold.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Quick action buttons
            IconButton(
              icon: const Icon(Icons.casino),
              color: AppColors.dragonGold,
              tooltip: 'Roll dice',
              onPressed: isProcessing ? null : _showDiceRoller,
            ),
            
            // Text input
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !isProcessing,
                maxLines: null,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  hintText: 'What do you do?',
                  filled: true,
                  fillColor: AppColors.bgMedium,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _submitAction(),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Send button
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.dragonGold,
                    AppColors.dragonGold.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: IconButton(
                icon: isProcessing 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.inkBlack,
                        ),
                      )
                    : const Icon(Icons.send),
                color: AppColors.inkBlack,
                onPressed: isProcessing ? null : _submitAction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitAction() {
    final action = _textController.text.trim();
    if (action.isEmpty) return;

    ref.read(storyViewModelProvider.notifier).processPlayerAction(action);
    _textController.clear();
    _focusNode.requestFocus();

    // Scroll to bottom after a delay to allow new messages to render
    Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
    Future.delayed(const Duration(milliseconds: 500), () => _scrollToBottom());
  }

  void _showDiceRoller() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _DiceRollerSheet(),
    );
  }
}

/// Widget for displaying a story message
class _StoryMessageWidget extends StatelessWidget {
  final StoryMessageModel message;
  final bool isLatest;

  const _StoryMessageWidget({
    required this.message,
    this.isLatest = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _buildMessageContent(context),
    );
    
    // Only animate the latest message, show others normally
    if (isLatest) {
      return content.animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms);
    }
    
    return content;
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case MessageType.playerAction:
        return _buildPlayerMessage(context);
      case MessageType.narration:
        return _buildNarrationMessage(context);
      case MessageType.dialogue:
        return _buildDialogueMessage(context);
      case MessageType.skillCheck:
        return _buildSkillCheckMessage(context);
      case MessageType.combat:
        return _buildCombatMessage(context);
      case MessageType.system:
      case MessageType.itemReceived:
      case MessageType.questUpdate:
      case MessageType.levelUp:
        return _buildSystemMessage(context);
    }
  }

  Widget _buildPlayerMessage(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.dragonGold.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: AppColors.dragonGold.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, size: 14, color: AppColors.dragonGold),
                    const SizedBox(width: 4),
                    Text(
                      'You',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.dragonGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.parchment,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text(
              timeFormat.format(message.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.parchmentDark.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrationMessage(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgMedium.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.mysticPurple.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.mysticPurple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_stories, size: 14, color: AppColors.mysticPurple),
                        const SizedBox(width: 4),
                        Text(
                          'Dungeon Master',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.mysticPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.parchment,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            timeFormat.format(message.timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.parchmentDark.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogueMessage(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Speaker avatar
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.mysticPurple.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.mysticPurple),
          ),
          child: Center(
            child: Text(
              message.speakerName?.substring(0, 1).toUpperCase() ?? '?',
              style: const TextStyle(
                color: AppColors.parchment,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.speakerName ?? 'Unknown',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.mysticPurple,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgMedium,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  '"${message.content}"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.parchment,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillCheckMessage(BuildContext context) {
    final result = message.skillCheckResult;
    if (result == null) return _buildNarrationMessage(context);

    final isSuccess = result.isSuccess;
    final color = isSuccess ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skill check header
          Row(
            children: [
              Icon(
                Icons.casino,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.checkTypeName,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSuccess ? 'SUCCESS' : 'FAILURE',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Roll details
          Row(
            children: [
              _buildRollChip('Roll', '${result.diceRoll}', AppColors.parchment),
              const SizedBox(width: 8),
              Text(
                result.modifier >= 0 ? '+' : '',
                style: TextStyle(color: AppColors.parchmentDark),
              ),
              _buildRollChip('Mod', '${result.modifier}', AppColors.parchmentDark),
              const SizedBox(width: 8),
              Text('=', style: TextStyle(color: AppColors.parchmentDark)),
              const SizedBox(width: 8),
              _buildRollChip('Total', '${result.totalResult}', color),
              const SizedBox(width: 8),
              Text('vs DC ${result.difficultyClass}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.parchmentDark,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Outcome text
          Text(
            message.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.parchment,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRollChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.parchmentDark,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombatMessage(BuildContext context) {
    final result = message.combatResult;
    final timeFormat = DateFormat('HH:mm');
    final content = message.content.toLowerCase();
    
    // Determine combat event type from content
    final isCritical = result?.isCriticalHit == true || content.contains('critical');
    final isMiss = result?.isMiss == true || content.contains('miss');
    final isVictory = content.contains('victory') || content.contains('all enemies defeated');
    final isDefeat = content.contains('fallen') || content.contains('defeat');
    final isCombatStart = content.contains('combat begins') || content.contains('initiative');
    final isHeal = content.contains('heal') || content.contains('💚');
    final isDodge = content.contains('dodge');
    final isFlee = content.contains('flee') || content.contains('escape');
    final isHit = result?.isHit == true || content.contains('hits ') || content.contains('damage');
    
    // Choose colors and icons based on result
    Color primaryColor;
    IconData primaryIcon;
    String headerText;
    
    if (isVictory) {
      primaryColor = AppColors.success;
      primaryIcon = Icons.emoji_events;
      headerText = '🎉 VICTORY';
    } else if (isDefeat) {
      primaryColor = AppColors.error;
      primaryIcon = Icons.dangerous;
      headerText = '💀 DEFEAT';
    } else if (isCombatStart) {
      primaryColor = AppColors.dragonBlood;
      primaryIcon = Icons.sports_kabaddi;
      headerText = '⚔️ COMBAT BEGINS';
    } else if (isCritical) {
      primaryColor = AppColors.dragonGold;
      primaryIcon = Icons.flash_on;
      headerText = '💥 CRITICAL HIT';
    } else if (isMiss) {
      primaryColor = AppColors.parchmentDark;
      primaryIcon = Icons.shield;
      headerText = '🛡️ MISSED';
    } else if (isHeal) {
      primaryColor = AppColors.success;
      primaryIcon = Icons.favorite;
      headerText = '💚 HEALING';
    } else if (isDodge) {
      primaryColor = AppColors.mysticPurple;
      primaryIcon = Icons.security;
      headerText = '🛡️ DODGE';
    } else if (isFlee) {
      primaryColor = AppColors.warning;
      primaryIcon = Icons.directions_run;
      headerText = '🏃 FLEE';
    } else if (isHit) {
      primaryColor = AppColors.dragonBlood;
      primaryIcon = Icons.gavel;
      headerText = '⚔️ ATTACK';
    } else {
      primaryColor = AppColors.dragonBlood;
      primaryIcon = Icons.sports_kabaddi;
      headerText = '⚔️ COMBAT';
    }
    
    // Extract combatant names from content if no combatResult
    String? attackerName;
    String? defenderName;
    int? damage;
    
    if (result != null) {
      attackerName = result.attackerName;
      defenderName = result.defenderName;
      damage = result.totalDamage;
    } else {
      // Try to parse from content
      final parsed = _parseCombatContent(message.content);
      attackerName = parsed['attacker'];
      defenderName = parsed['defender'];
      damage = parsed['damage'];
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.15),
            AppColors.bgDark.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Combat header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(primaryIcon, color: primaryColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  headerText,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  timeFormat.format(message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchmentDark.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          
          // Combatants section (if we have combatant info)
          if (attackerName != null && defenderName != null) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Attacker
                  Expanded(
                    child: _buildCombatantCard(
                      context,
                      name: attackerName,
                      isAttacker: true,
                      isPlayer: _isPlayerName(attackerName),
                    ),
                  ),
                  
                  // VS / Arrow
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          color: primaryColor,
                          size: 24,
                        ),
                        if (damage != null && damage > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '-$damage',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Defender
                  Expanded(
                    child: _buildCombatantCard(
                      context,
                      name: defenderName,
                      isAttacker: false,
                      isPlayer: _isPlayerName(defenderName),
                    ),
                  ),
                ],
              ),
            ),
            
            // Roll details
            if (result?.attackRoll != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDiceResult('🎲 Attack', result!.attackRoll!, isCritical || result.isCriticalHit == true),
                    if (result.damageRoll != null) ...[
                      const SizedBox(width: 16),
                      _buildDiceResult('💥 Damage', result.damageRoll!, false),
                    ],
                  ],
                ),
              ),
          ],
          
          // Message content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.parchment,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Parse combat content to extract combatant names and damage
  Map<String, dynamic> _parseCombatContent(String content) {
    String? attacker;
    String? defender;
    int? damage;
    
    // Common patterns: "X hits Y for Z damage" or "X attacks Y"
    final hitPattern = RegExp(r'(\w+(?:\s+\w+)?)\s+(?:hits|attacks|strikes|slashes|bites)\s+(\w+(?:\s+\w+)?)', caseSensitive: false);
    final damagePattern = RegExp(r'(\d+)\s*(?:damage|HP)', caseSensitive: false);
    final forDamagePattern = RegExp(r'for\s+(\d+)', caseSensitive: false);
    
    final hitMatch = hitPattern.firstMatch(content);
    if (hitMatch != null) {
      attacker = hitMatch.group(1);
      defender = hitMatch.group(2);
    }
    
    // Try to find damage
    final forDamageMatch = forDamagePattern.firstMatch(content);
    if (forDamageMatch != null) {
      damage = int.tryParse(forDamageMatch.group(1) ?? '');
    } else {
      final damageMatch = damagePattern.firstMatch(content);
      if (damageMatch != null) {
        damage = int.tryParse(damageMatch.group(1) ?? '');
      }
    }
    
    // If still no match, try "X's attack misses Y"
    if (attacker == null) {
      final missPattern = RegExp(r"(\w+(?:'s)?)\s+attack\s+(?:misses|missed)\s*(\w+)?", caseSensitive: false);
      final missMatch = missPattern.firstMatch(content);
      if (missMatch != null) {
        attacker = missMatch.group(1)?.replaceAll("'s", '');
        defender = missMatch.group(2);
      }
    }
    
    // Check for healing pattern
    if (attacker == null && content.toLowerCase().contains('heal')) {
      final healPattern = RegExp(r'(\w+(?:\s+\w+)?)\s+heal', caseSensitive: false);
      final healMatch = healPattern.firstMatch(content);
      if (healMatch != null) {
        attacker = healMatch.group(1);
        defender = attacker; // Self-heal
      }
    }
    
    return {
      'attacker': attacker,
      'defender': defender,
      'damage': damage,
    };
  }
  
  /// Check if a name is likely the player character
  bool _isPlayerName(String name) {
    final lowerName = name.toLowerCase();
    // Common monster/enemy names
    final enemyIndicators = [
      'goblin', 'orc', 'skeleton', 'zombie', 'wolf', 'spider',
      'rat', 'bandit', 'thug', 'guard', 'soldier', 'ogre',
      'troll', 'dragon', 'demon', 'ghost', 'wraith', 'slime',
    ];
    
    for (final indicator in enemyIndicators) {
      if (lowerName.contains(indicator)) {
        return false;
      }
    }
    
    // If it doesn't match enemy patterns, assume it's a player or NPC
    return true;
  }
  
  Widget _buildCombatantCard(BuildContext context, {
    required String name,
    required bool isAttacker,
    required bool isPlayer,
  }) {
    final color = isPlayer ? AppColors.dragonGold : AppColors.dragonBlood;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            child: Center(
              child: isPlayer 
                  ? Icon(Icons.person, color: color, size: 20)
                  : Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          
          // Name
          Text(
            name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Role indicator
          Text(
            isAttacker ? 'Attacker' : 'Defender',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.parchmentDark.withValues(alpha: 0.6),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDiceResult(String label, int value, bool isCritical) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.parchmentDark,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isCritical 
                ? AppColors.dragonGold.withValues(alpha: 0.3)
                : AppColors.bgMedium,
            borderRadius: BorderRadius.circular(4),
            border: isCritical 
                ? Border.all(color: AppColors.dragonGold)
                : null,
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              color: isCritical ? AppColors.dragonGold : AppColors.parchment,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    Color color;
    IconData icon;
    
    switch (message.type) {
      case MessageType.levelUp:
        color = AppColors.dragonGold;
        icon = Icons.arrow_upward;
        break;
      case MessageType.itemReceived:
        color = AppColors.forestGreen;
        icon = Icons.inventory_2;
        break;
      case MessageType.questUpdate:
        color = AppColors.arcaneBlue;
        icon = Icons.assignment;
        break;
      default:
        color = AppColors.parchmentDark;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            message.content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: message.isImportant ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dice roller bottom sheet
class _DiceRollerSheet extends ConsumerStatefulWidget {
  const _DiceRollerSheet();

  @override
  ConsumerState<_DiceRollerSheet> createState() => _DiceRollerSheetState();
}

class _DiceRollerSheetState extends ConsumerState<_DiceRollerSheet> {
  String? _lastRoll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Roll Dice',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          
          // Dice buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _DiceButton(label: 'd4', sides: 4, onRoll: _onRoll),
              _DiceButton(label: 'd6', sides: 6, onRoll: _onRoll),
              _DiceButton(label: 'd8', sides: 8, onRoll: _onRoll),
              _DiceButton(label: 'd10', sides: 10, onRoll: _onRoll),
              _DiceButton(label: 'd12', sides: 12, onRoll: _onRoll),
              _DiceButton(label: 'd20', sides: 20, onRoll: _onRoll),
              _DiceButton(label: 'd100', sides: 100, onRoll: _onRoll),
            ],
          ),
          
          if (_lastRoll != null) ...[
            const SizedBox(height: 24),
            Text(
              _lastRoll!,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.dragonGold,
              ),
            ).animate().scale(duration: 200.ms),
          ],
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _onRoll(int sides, int result) {
    setState(() {
      _lastRoll = 'd$sides: $result';
    });
  }
}

class _DiceButton extends ConsumerWidget {
  final String label;
  final int sides;
  final void Function(int sides, int result) onRoll;

  const _DiceButton({
    required this.label,
    required this.sides,
    required this.onRoll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.bgMedium,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final gameMaster = ref.read(gameMasterProvider);
          final result = gameMaster.diceRoller.rollDie(sides);
          onRoll(sides, result);
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dragonGold.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.dragonGold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


