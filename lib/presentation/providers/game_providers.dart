import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/game_state_model.dart';
import '../../data/models/character_model.dart';
import '../../data/models/ai_response_model.dart';
import '../../data/models/story_message_model.dart';
import '../../data/models/quest_model.dart';
import '../../data/models/story_journal_model.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/journal_service.dart';
import '../../data/services/story_summarizer_service.dart';
import '../../data/repositories/game_repository.dart';
import '../../domain/game_engine/game_master.dart';
import 'auth_providers.dart';

/// Game repository provider
final gameRepositoryProvider = Provider<IGameRepository>((ref) {
  return GameRepository();
});

/// Character factory provider
final characterFactoryProvider = Provider<CharacterFactory>((ref) {
  return CharacterFactory();
});

/// Game master provider
final gameMasterProvider = Provider<GameMaster>((ref) {
  return GameMaster();
});

/// Story summarizer service provider
final storySummarizerProvider = Provider<StorySummarizerService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final summarizer = StorySummarizerService();
  summarizer.setAuthToken(authService.accessToken);
  return summarizer;
});

/// Current story summary provider (cached)
final currentStorySummaryProvider = StateProvider<String?>((ref) => null);

/// Messages summarized count provider (tracks progress)
final messagesSummarizedProvider = StateProvider<int>((ref) => 0);

/// AI service configuration provider
final aiConfigProvider = StateProvider<AIServiceConfig?>((ref) {
  // Load from settings
  final provider = StorageService.getSetting<String>(SettingsKeys.aiProvider);
  final apiKey = StorageService.getSetting<String>(SettingsKeys.aiApiKey);
  final model = StorageService.getSetting<String>(SettingsKeys.aiModel);
  final ollamaUrl = StorageService.getSetting<String>(SettingsKeys.ollamaUrl);
  final ollamaModel = StorageService.getSetting<String>(SettingsKeys.ollamaModel);
  
  switch (provider) {
    case 'ollama':
      // Ollama doesn't need an API key
      return AIServiceConfig.ollama(
        baseUrl: ollamaUrl ?? 'http://localhost:11434',
        model: ollamaModel ?? 'qwen2.5:3b-instruct',
      );
    case 'openai':
      if (apiKey == null || apiKey.isEmpty) return null;
      return AIServiceConfig.openai(
        apiKey: apiKey,
        model: model ?? 'gpt-4-turbo-preview',
      );
    case 'anthropic':
      if (apiKey == null || apiKey.isEmpty) return null;
      return AIServiceConfig.anthropic(
        apiKey: apiKey,
        model: model ?? 'claude-3-opus-20240229',
      );
    default:
      // Default to Ollama (no API key needed)
      return AIServiceConfig.ollama(
        baseUrl: ollamaUrl ?? 'http://localhost:11434',
        model: ollamaModel ?? 'qwen2.5:3b-instruct',
      );
  }
});

/// AI service provider
final aiServiceProvider = Provider<AIService?>((ref) {
  final config = ref.watch(aiConfigProvider);
  if (config == null) return null;
  return AIService(config: config);
});

/// Current game state provider
final gameStateProvider = StateNotifierProvider<GameStateNotifier, AsyncValue<GameStateModel?>>((ref) {
  return GameStateNotifier(ref);
});

/// Game state notifier
class GameStateNotifier extends StateNotifier<AsyncValue<GameStateModel?>> {
  final Ref _ref;
  
  GameStateNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadCurrentGame();
  }
  
  Future<void> _loadCurrentGame() async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(gameRepositoryProvider);
      final gameState = await repo.loadCurrentGame();
      state = AsyncValue.data(gameState);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> createNewGame({
    required String saveName,
    required CharacterModel character,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(gameRepositoryProvider);
      final newState = await repo.createNewGame(
        saveName: saveName,
        character: character,
      );
      state = AsyncValue.data(newState);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> loadGame(String id) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(gameRepositoryProvider);
      final gameState = await repo.loadGame(id);
      
      if (gameState == null) {
        state = AsyncValue.error(Exception('Save not found'), StackTrace.current);
        return;
      }
      
      state = AsyncValue.data(gameState);
      
      // Load existing story summary for this save (non-blocking)
      _loadStorySummary(id, gameState.storyLog.length);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Load a game state directly (used when loading from cloud)
  Future<void> loadGameFromState(GameStateModel gameState, String saveId) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(gameState);
      
      // Load existing story summary for this save
      await _loadStorySummary(saveId, gameState.storyLog.length);
    } catch (e, st) {
      // Still set the state even if summary loading fails
      state = AsyncValue.data(gameState);
    }
  }
  
  /// Load story summary from the database for an existing save
  Future<void> _loadStorySummary(String saveId, int currentLogLength) async {
    try {
      final summarizer = _ref.read(storySummarizerProvider);
      final existingSummary = await summarizer.getStorySummary(saveId);
      
      if (existingSummary != null) {
        _ref.read(currentStorySummaryProvider.notifier).state = existingSummary.summary;
        _ref.read(messagesSummarizedProvider.notifier).state = existingSummary.messagesSummarized;
        print('Loaded existing story summary (${existingSummary.messagesSummarized} messages summarized)');
      } else {
        // No summary yet - reset state
        _ref.read(currentStorySummaryProvider.notifier).state = null;
        _ref.read(messagesSummarizedProvider.notifier).state = 0;
      }
    } catch (e) {
      print('Failed to load story summary: $e');
      // Non-blocking - continue without summary
      _ref.read(currentStorySummaryProvider.notifier).state = null;
      _ref.read(messagesSummarizedProvider.notifier).state = 0;
    }
  }
  
  Future<void> saveGame() async {
    final currentState = state.value;
    if (currentState == null) return;
    
    try {
      final updatedState = currentState.copyWith(
        lastPlayedAt: DateTime.now(),
      );
      
      // Save to cloud
      final saveId = _ref.read(selectedSaveIdProvider);
      if (saveId != null) {
        final cloudService = _ref.read(cloudSaveServiceProvider);
        await cloudService.updateSave(
          saveId: saveId,
          gameState: updatedState,
        );
      }
      
      // Also save locally as backup
      final repo = _ref.read(gameRepositoryProvider);
      await repo.saveGame(updatedState);
      
      state = AsyncValue.data(updatedState);
    } catch (e) {
      print('Save error: $e');
      // Handle save error silently or show notification
    }
  }
  
  void updateState(GameStateModel newState) {
    state = AsyncValue.data(newState);
  }
}

/// Story processing state
enum StoryProcessingState {
  idle,
  processing,
  error,
}

/// Story view model provider
final storyViewModelProvider = StateNotifierProvider<StoryViewModel, StoryViewState>((ref) {
  return StoryViewModel(ref);
});

/// Story view state
class StoryViewState {
  final StoryProcessingState processingState;
  final String? errorMessage;
  final List<String>? suggestedActions;
  final bool requiresChoice;
  final List<PlayerChoice>? playerChoices;
  
  const StoryViewState({
    this.processingState = StoryProcessingState.idle,
    this.errorMessage,
    this.suggestedActions,
    this.requiresChoice = false,
    this.playerChoices,
  });
  
  StoryViewState copyWith({
    StoryProcessingState? processingState,
    String? errorMessage,
    List<String>? suggestedActions,
    bool? requiresChoice,
    List<PlayerChoice>? playerChoices,
  }) {
    return StoryViewState(
      processingState: processingState ?? this.processingState,
      errorMessage: errorMessage,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      requiresChoice: requiresChoice ?? this.requiresChoice,
      playerChoices: playerChoices ?? this.playerChoices,
    );
  }
}

/// Story view model
class StoryViewModel extends StateNotifier<StoryViewState> {
  final Ref _ref;
  
  StoryViewModel(this._ref) : super(const StoryViewState());
  
  Future<void> processPlayerAction(String action) async {
    if (action.trim().isEmpty) return;
    
    state = state.copyWith(
      processingState: StoryProcessingState.processing,
      errorMessage: null,
    );
    
    try {
      final gameState = _ref.read(gameStateProvider).value;
      if (gameState == null) {
        state = state.copyWith(
          processingState: StoryProcessingState.error,
          errorMessage: 'No active game',
        );
        return;
      }
      
      // Add player message immediately so they see what they typed
      final playerMessage = StoryMessageModel(
        id: const Uuid().v4(),
        type: MessageType.playerAction,
        content: action,
        timestamp: DateTime.now(),
      );
      
      final updatedLog = [...gameState.storyLog, playerMessage];
      final stateWithPlayerMessage = gameState.copyWith(storyLog: updatedLog);
      _ref.read(gameStateProvider.notifier).updateState(stateWithPlayerMessage);
      
      final aiService = _ref.read(aiServiceProvider);
      final gameMaster = _ref.read(gameMasterProvider);
      final summarizer = _ref.read(storySummarizerProvider);
      
      // Get current story summary for context optimization
      final currentSummary = _ref.read(currentStorySummaryProvider);
      final messagesSummarized = _ref.read(messagesSummarizedProvider);
      
      AIResponseModel aiResponse;
      
      if (aiService != null) {
        // Get AI response with optimized context
        aiResponse = await aiService.generateStoryResponse(
          gameState: gameState,
          playerAction: action,
          storySummary: currentSummary,
        );
      } else {
        // Fallback for when AI is not configured
        aiResponse = _generateFallbackResponse(action);
      }
      
      // Process through game master (skip player message since we added it above)
      final result = gameMaster.processAIResponse(
        gameState: stateWithPlayerMessage,
        aiResponse: aiResponse,
        playerAction: action,
        skipPlayerMessage: true,
      );
      
      // Update game state
      _ref.read(gameStateProvider.notifier).updateState(result.updatedState);
      
      // Record to journal
      await JournalService.recordStoryEvent(
        saveId: gameState.id,
        playerAction: action,
        aiResponse: aiResponse,
        gameState: result.updatedState,
        skillCheckResult: result.skillCheckOutcome != null
            ? SkillCheckResult(
                skill: result.skillCheckOutcome!.skill,
                ability: result.skillCheckOutcome!.ability,
                diceRoll: result.skillCheckOutcome!.rollResult.d20Roll.result,
                modifier: result.skillCheckOutcome!.rollResult.modifier,
                totalResult: result.skillCheckOutcome!.rollResult.total,
                difficultyClass: result.skillCheckOutcome!.rollResult.difficultyClass,
                isSuccess: result.skillCheckOutcome!.isSuccess,
                isCriticalSuccess: result.skillCheckOutcome!.rollResult.isCriticalSuccess,
                isCriticalFailure: result.skillCheckOutcome!.rollResult.isCriticalFailure,
              )
            : null,
      );
      
      // Auto-save
      await _ref.read(gameStateProvider.notifier).saveGame();
      
      // Check if summarization is needed (runs in background)
      _checkAndTriggerSummarization(
        saveId: gameState.id,
        storyLog: result.updatedState.storyLog,
        summarizer: summarizer,
        currentSummary: currentSummary,
        messagesSummarized: messagesSummarized,
      );
      
      state = state.copyWith(
        processingState: StoryProcessingState.idle,
        suggestedActions: result.suggestedActions ?? aiResponse.suggestedActions,
        requiresChoice: result.requiresPlayerChoice,
        playerChoices: result.playerChoices,
      );
    } catch (e) {
      print('Error processing action: $e');
      state = state.copyWith(
        processingState: StoryProcessingState.error,
        errorMessage: 'Failed to process action. Please try again.',
      );
    }
  }
  
  /// Check if summarization is needed and trigger it in the background
  Future<void> _checkAndTriggerSummarization({
    required String saveId,
    required List<StoryMessageModel> storyLog,
    required StorySummarizerService summarizer,
    String? currentSummary,
    required int messagesSummarized,
  }) async {
    try {
      // Check if we should summarize
      final checkResult = summarizer.checkShouldSummarize(storyLog, messagesSummarized);
      
      if (!checkResult.shouldSummarize) return;
      
      print('Triggering story summarization: ${checkResult.messagesNeedingSummary} messages to summarize');
      
      // Run summarization in background (don't await to not block UI)
      summarizer.summarizeAndStore(
        saveId: saveId,
        storyLog: storyLog,
        existingSummary: currentSummary,
        messagesSummarizedSoFar: messagesSummarized,
      ).then((newSummary) {
        if (newSummary != null) {
          // Update cached summary
          _ref.read(currentStorySummaryProvider.notifier).state = newSummary;
          _ref.read(messagesSummarizedProvider.notifier).state = storyLog.length;
          print('Story summarized successfully');
        }
      }).catchError((e) {
        print('Summarization error (non-blocking): $e');
      });
    } catch (e) {
      print('Check summarization error: $e');
    }
  }
  
  AIResponseModel _generateFallbackResponse(String action) {
    // Simple fallback when AI is not configured
    return AIResponseModel(
      narration: 'You attempt to $action. The world around you responds in kind, though the details remain shrouded in mystery. Perhaps configuring an AI provider in settings would reveal more of the story...',
      suggestedActions: [
        'Look around',
        'Talk to someone nearby',
        'Check your inventory',
        'Rest for a moment',
      ],
    );
  }
  
  void clearError() {
    state = state.copyWith(
      processingState: StoryProcessingState.idle,
      errorMessage: null,
    );
  }
}

/// Character sheet provider - derived from game state
final characterProvider = Provider<CharacterModel?>((ref) {
  final gameState = ref.watch(gameStateProvider).value;
  return gameState?.character;
});

/// Inventory provider - derived from game state
final inventoryProvider = Provider<InventoryModel?>((ref) {
  final gameState = ref.watch(gameStateProvider).value;
  return gameState?.inventory;
});

/// Quest list provider - derived from game state
final questsProvider = Provider<List<QuestModel>>((ref) {
  final gameState = ref.watch(gameStateProvider).value;
  return gameState?.quests ?? [];
});

/// Active quests provider
final activeQuestsProvider = Provider<List<QuestModel>>((ref) {
  final quests = ref.watch(questsProvider);
  return quests.where((q) => q.status == QuestStatus.active).toList();
});

/// Story log provider - derived from game state
final storyLogProvider = Provider<List<StoryMessageModel>>((ref) {
  final gameState = ref.watch(gameStateProvider).value;
  return gameState?.storyLog ?? [];
});

/// Current scene provider
final currentSceneProvider = Provider<SceneModel?>((ref) {
  final gameState = ref.watch(gameStateProvider).value;
  return gameState?.currentScene;
});

/// Gold provider
final goldProvider = Provider<int>((ref) {
  final gameState = ref.watch(gameStateProvider).value;
  return gameState?.gold ?? 0;
});

/// Journal provider
final journalProvider = Provider<StoryJournal?>((ref) {
  final gameState = ref.watch(gameStateProvider).value;
  if (gameState == null) return null;
  return JournalService.getJournal(gameState.id);
});

/// Save games list provider
final saveGamesProvider = Provider<List<SaveGameInfo>>((ref) {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.getAllSaves();
});

/// Settings providers
final soundEnabledProvider = StateProvider<bool>((ref) {
  return StorageService.getSetting<bool>(SettingsKeys.soundEnabled) ?? true;
});

final musicEnabledProvider = StateProvider<bool>((ref) {
  return StorageService.getSetting<bool>(SettingsKeys.musicEnabled) ?? true;
});

final showDiceRollsProvider = StateProvider<bool>((ref) {
  return StorageService.getSetting<bool>(SettingsKeys.showDiceRolls) ?? true;
});

final textSizeProvider = StateProvider<double>((ref) {
  return StorageService.getSetting<double>(SettingsKeys.textSize) ?? 1.0;
});


