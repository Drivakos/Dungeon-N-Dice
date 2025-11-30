import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_state_model.dart';
import '../models/character_model.dart';

/// Service for local data persistence
class StorageService {
  static const String _gameStateBoxName = 'game_states';
  static const String _settingsBoxName = 'settings';
  static const String _currentSaveKey = 'current_save_id';
  
  static late Box<String> _gameStateBox;
  static late Box<dynamic> _settingsBox;
  
  /// Initialize storage
  static Future<void> initialize() async {
    _gameStateBox = await Hive.openBox<String>(_gameStateBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }
  
  /// Save game state
  static Future<void> saveGameState(GameStateModel state) async {
    final json = jsonEncode(state.toJson());
    await _gameStateBox.put(state.id, json);
    await _settingsBox.put(_currentSaveKey, state.id);
  }
  
  /// Load game state by ID
  static GameStateModel? loadGameState(String id) {
    final json = _gameStateBox.get(id);
    if (json == null) return null;
    
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return GameStateModel.fromJson(map);
    } catch (e) {
      return null;
    }
  }
  
  /// Load current/last played game state
  static GameStateModel? loadCurrentGameState() {
    final currentId = _settingsBox.get(_currentSaveKey) as String?;
    if (currentId == null) return null;
    return loadGameState(currentId);
  }
  
  /// Get all saved games
  static List<SaveGameInfo> getAllSaves() {
    final saves = <SaveGameInfo>[];
    
    for (final key in _gameStateBox.keys) {
      final json = _gameStateBox.get(key);
      if (json != null) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          saves.add(SaveGameInfo(
            id: key as String,
            saveName: map['saveName'] as String,
            characterName: (map['character'] as Map<String, dynamic>)['name'] as String,
            characterLevel: (map['character'] as Map<String, dynamic>)['level'] as int,
            lastPlayedAt: DateTime.parse(map['lastPlayedAt'] as String),
            totalPlayTime: Duration(seconds: map['totalPlayTime'] as int? ?? 0),
          ));
        } catch (e) {
          // Skip corrupted saves
        }
      }
    }
    
    // Sort by last played
    saves.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    return saves;
  }
  
  /// Delete a save game
  static Future<void> deleteSave(String id) async {
    await _gameStateBox.delete(id);
    
    // If this was the current save, clear it
    final currentId = _settingsBox.get(_currentSaveKey);
    if (currentId == id) {
      await _settingsBox.delete(_currentSaveKey);
    }
  }
  
  /// Check if any saves exist
  static bool hasSaves() => _gameStateBox.isNotEmpty;
  
  /// Get setting value
  static T? getSetting<T>(String key) {
    return _settingsBox.get(key) as T?;
  }
  
  /// Set setting value
  static Future<void> setSetting<T>(String key, T value) async {
    await _settingsBox.put(key, value);
  }
  
  /// Clear all settings
  static Future<void> clearSettings() async {
    await _settingsBox.clear();
  }
  
  /// Clear all data (for debug/reset)
  static Future<void> clearAllData() async {
    await _gameStateBox.clear();
    await _settingsBox.clear();
  }
}

/// Info about a saved game
class SaveGameInfo {
  final String id;
  final String saveName;
  final String characterName;
  final int characterLevel;
  final DateTime lastPlayedAt;
  final Duration totalPlayTime;
  
  const SaveGameInfo({
    required this.id,
    required this.saveName,
    required this.characterName,
    required this.characterLevel,
    required this.lastPlayedAt,
    required this.totalPlayTime,
  });
  
  String get formattedPlayTime {
    final hours = totalPlayTime.inHours;
    final minutes = totalPlayTime.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}

/// Settings keys
class SettingsKeys {
  static const String aiProvider = 'ai_provider';
  static const String aiApiKey = 'ai_api_key';
  static const String aiModel = 'ai_model';
  static const String ollamaUrl = 'ollama_url';
  static const String ollamaModel = 'ollama_model';
  static const String soundEnabled = 'sound_enabled';
  static const String musicEnabled = 'music_enabled';
  static const String vibrationEnabled = 'vibration_enabled';
  static const String textSize = 'text_size';
  static const String autoSave = 'auto_save';
  static const String autoSaveInterval = 'auto_save_interval';
  static const String showDiceRolls = 'show_dice_rolls';
  static const String darkMode = 'dark_mode';
}


