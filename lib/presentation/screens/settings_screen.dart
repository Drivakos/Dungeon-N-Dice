import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/storage_service.dart';
import '../providers/game_providers.dart';

/// Settings screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _ollamaUrlController = TextEditingController();
  final _ollamaModelController = TextEditingController();
  AIProvider _selectedProvider = AIProvider.ollama;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final provider = StorageService.getSetting<String>(SettingsKeys.aiProvider);
    final apiKey = StorageService.getSetting<String>(SettingsKeys.aiApiKey);
    final ollamaUrl = StorageService.getSetting<String>(SettingsKeys.ollamaUrl);
    final ollamaModel = StorageService.getSetting<String>(SettingsKeys.ollamaModel);
    
    if (provider != null) {
      _selectedProvider = AIProvider.values.firstWhere(
        (p) => p.name == provider,
        orElse: () => AIProvider.ollama,
      );
    }
    if (apiKey != null) {
      _apiKeyController.text = apiKey;
    }
    _ollamaUrlController.text = ollamaUrl ?? 'http://localhost:11434';
    _ollamaModelController.text = ollamaModel ?? 'qwen2.5:3b-instruct';
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _ollamaUrlController.dispose();
    _ollamaModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soundEnabled = ref.watch(soundEnabledProvider);
    final musicEnabled = ref.watch(musicEnabledProvider);
    final showDiceRolls = ref.watch(showDiceRollsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // AI Configuration
          _buildSection(
            context,
            title: 'AI Configuration',
            icon: Icons.psychology,
            children: [
              _buildDropdownSetting(
                context,
                label: 'AI Provider',
                value: _selectedProvider,
                items: AIProvider.values,
                onChanged: (value) {
                  setState(() => _selectedProvider = value!);
                  StorageService.setSetting(SettingsKeys.aiProvider, value!.name);
                  _saveAIConfig();
                },
                itemBuilder: (provider) => provider.displayName,
              ),
              const SizedBox(height: 16),
              
              // Show different fields based on provider
              if (_selectedProvider == AIProvider.ollama) ...[
                _buildOllamaFields(context),
              ] else ...[
                _buildApiKeyField(context),
                const SizedBox(height: 8),
                Text(
                  'Your API key is stored locally and never sent to our servers.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchmentDark,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Audio Settings
          _buildSection(
            context,
            title: 'Audio',
            icon: Icons.volume_up,
            children: [
              _buildSwitchSetting(
                context,
                label: 'Sound Effects',
                value: soundEnabled,
                onChanged: (value) {
                  ref.read(soundEnabledProvider.notifier).state = value;
                  StorageService.setSetting(SettingsKeys.soundEnabled, value);
                },
              ),
              _buildSwitchSetting(
                context,
                label: 'Background Music',
                value: musicEnabled,
                onChanged: (value) {
                  ref.read(musicEnabledProvider.notifier).state = value;
                  StorageService.setSetting(SettingsKeys.musicEnabled, value);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Gameplay Settings
          _buildSection(
            context,
            title: 'Gameplay',
            icon: Icons.gamepad,
            children: [
              _buildSwitchSetting(
                context,
                label: 'Show Dice Rolls',
                subtitle: 'Display detailed dice roll results',
                value: showDiceRolls,
                onChanged: (value) {
                  ref.read(showDiceRollsProvider.notifier).state = value;
                  StorageService.setSetting(SettingsKeys.showDiceRolls, value);
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // About
          _buildSection(
            context,
            title: 'About',
            icon: Icons.info_outline,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Version',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                trailing: Text(
                  '1.0.0',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.parchmentDark,
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Game Engine',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                trailing: Text(
                  'D&D 5e Rules',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.parchmentDark,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Danger Zone
          _buildSection(
            context,
            title: 'Danger Zone',
            icon: Icons.warning,
            color: AppColors.error,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Clear All Data',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
                subtitle: Text(
                  'Delete all saves and settings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.parchmentDark,
                  ),
                ),
                trailing: const Icon(Icons.delete_forever, color: AppColors.error),
                onTap: () => _showClearDataDialog(context),
              ),
            ],
          ),
          
          const SizedBox(height: 100), // Bottom padding for nav bar
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
  }) {
    final sectionColor = color ?? AppColors.dragonGold;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgMedium.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sectionColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: sectionColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: sectionColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(
    BuildContext context, {
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.parchmentDark,
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.dragonGold,
      ),
    );
  }

  Widget _buildDropdownSetting<T>(
    BuildContext context, {
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.dragonGold.withValues(alpha: 0.3)),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: AppColors.bgDark,
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(itemBuilder(item)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildOllamaFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No API key required! Ollama runs locally on your machine.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ollama URL',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ollamaUrlController,
          decoration: const InputDecoration(
            hintText: 'http://localhost:11434',
          ),
          onChanged: (_) => _saveAIConfig(),
        ),
        const SizedBox(height: 16),
        Text(
          'Model Name',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ollamaModelController,
          decoration: const InputDecoration(
            hintText: 'qwen2.5:3b-instruct',
          ),
          onChanged: (_) => _saveAIConfig(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _testOllamaConnection,
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Test Connection'),
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'API Key',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKeyController,
          obscureText: _obscureApiKey,
          decoration: InputDecoration(
            hintText: 'Enter your API key',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.parchmentDark,
                  ),
                  onPressed: () {
                    setState(() => _obscureApiKey = !_obscureApiKey);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.save, color: AppColors.dragonGold),
                  onPressed: _saveAIConfig,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _saveAIConfig() {
    StorageService.setSetting(SettingsKeys.aiProvider, _selectedProvider.name);
    
    AIServiceConfig? config;
    
    switch (_selectedProvider) {
      case AIProvider.ollama:
        final url = _ollamaUrlController.text.isNotEmpty 
            ? _ollamaUrlController.text 
            : 'http://localhost:11434';
        final model = _ollamaModelController.text.isNotEmpty 
            ? _ollamaModelController.text 
            : 'qwen2.5:3b-instruct';
        StorageService.setSetting(SettingsKeys.ollamaUrl, url);
        StorageService.setSetting(SettingsKeys.ollamaModel, model);
        config = AIServiceConfig.ollama(baseUrl: url, model: model);
        break;
      case AIProvider.openai:
        StorageService.setSetting(SettingsKeys.aiApiKey, _apiKeyController.text);
        if (_apiKeyController.text.isNotEmpty) {
          config = AIServiceConfig.openai(apiKey: _apiKeyController.text);
        }
        break;
      case AIProvider.anthropic:
        StorageService.setSetting(SettingsKeys.aiApiKey, _apiKeyController.text);
        if (_apiKeyController.text.isNotEmpty) {
          config = AIServiceConfig.anthropic(apiKey: _apiKeyController.text);
        }
        break;
    }
    
    if (config != null) {
      ref.read(aiConfigProvider.notifier).state = config;
    }
  }

  Future<void> _testOllamaConnection() async {
    final url = _ollamaUrlController.text.isNotEmpty 
        ? _ollamaUrlController.text 
        : 'http://localhost:11434';
    
    try {
      final dio = Dio();
      final response = await dio.get(
        '$url/api/tags',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      
      if (response.statusCode == 200) {
        final models = (response.data['models'] as List?)
            ?.map((m) => m['name'] as String)
            .toList() ?? [];
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected! Available models: ${models.take(3).join(", ")}${models.length > 3 ? "..." : ""}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: Make sure Ollama is running on $url'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.error),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.error),
            SizedBox(width: 8),
            Text('Clear All Data'),
          ],
        ),
        content: const Text(
          'This will permanently delete all your saved games and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () async {
              await StorageService.clearAllData();
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data cleared'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
}


