import 'package:uuid/uuid.dart';

import '../../core/constants/game_constants.dart';
import '../models/character_model.dart';
import '../models/game_state_model.dart';
import '../models/quest_model.dart';
import '../models/item_model.dart';
import '../services/storage_service.dart';

/// Repository for game data operations
abstract class IGameRepository {
  Future<GameStateModel> createNewGame({
    required String saveName,
    required CharacterModel character,
  });
  Future<GameStateModel?> loadGame(String id);
  Future<GameStateModel?> loadCurrentGame();
  Future<void> saveGame(GameStateModel state);
  Future<void> deleteGame(String id);
  List<SaveGameInfo> getAllSaves();
  bool hasSaves();
}

/// Implementation of game repository
class GameRepository implements IGameRepository {
  final Uuid _uuid;
  
  GameRepository() : _uuid = const Uuid();
  
  @override
  Future<GameStateModel> createNewGame({
    required String saveName,
    required CharacterModel character,
  }) async {
    final now = DateTime.now();
    
    // Create initial scene
    final initialScene = SceneModel(
      id: _uuid.v4(),
      name: 'The Crossroads Inn',
      description: '''You find yourself in a cozy tavern at the crossroads of two major trade routes. 
The warm glow of the fireplace casts dancing shadows across worn wooden tables. 
The smell of roasting meat and fresh bread fills the air, mixing with the murmur of 
travelers' conversations. A weathered notice board near the entrance catches your eye, 
covered in various postings and requests for help.''',
      type: SceneType.exploration,
      availableExits: ['North Road', 'South Road', 'Upstairs', 'Outside'],
      ambientDescription: 'The crackling fire and distant laughter create a welcoming atmosphere.',
    );
    
    // Create initial quest
    final initialQuest = QuestModel(
      id: _uuid.v4(),
      title: 'A New Beginning',
      description: 'You\'ve arrived at the Crossroads Inn, a hub for adventurers. Explore, talk to the locals, and find your first adventure.',
      type: QuestType.main,
      status: QuestStatus.active,
      level: 1,
      objectives: [
        QuestObjective(
          id: _uuid.v4(),
          description: 'Explore the Crossroads Inn',
          type: ObjectiveType.explore,
          targetProgress: 1,
        ),
        QuestObjective(
          id: _uuid.v4(),
          description: 'Talk to the innkeeper',
          type: ObjectiveType.talkTo,
          targetProgress: 1,
        ),
        QuestObjective(
          id: _uuid.v4(),
          description: 'Check the notice board for quests',
          type: ObjectiveType.interact,
          targetProgress: 1,
        ),
      ],
      rewards: const QuestRewards(
        experiencePoints: 50,
        gold: 10,
      ),
      giverNpcName: 'Your Journey',
      location: 'The Crossroads Inn',
      startedAt: now,
      isTracked: true,
    );
    
    // Create initial inventory with starter items
    final starterItems = _getStarterItems(character.characterClass);
    final inventory = InventoryModel(
      items: starterItems,
      maxSlots: 30,
    );
    
    // Create game state
    final gameState = GameStateModel(
      id: _uuid.v4(),
      saveName: saveName,
      character: character,
      inventory: inventory,
      quests: [initialQuest],
      currentScene: initialScene,
      storyLog: [],
      gold: 15, // Starting gold
      createdAt: now,
      lastPlayedAt: now,
      difficulty: GameDifficulty.normal,
    );
    
    // Save the new game
    await StorageService.saveGameState(gameState);
    
    return gameState;
  }
  
  @override
  Future<GameStateModel?> loadGame(String id) async {
    return StorageService.loadGameState(id);
  }
  
  @override
  Future<GameStateModel?> loadCurrentGame() async {
    return StorageService.loadCurrentGameState();
  }
  
  @override
  Future<void> saveGame(GameStateModel state) async {
    await StorageService.saveGameState(state);
  }
  
  @override
  Future<void> deleteGame(String id) async {
    await StorageService.deleteSave(id);
  }
  
  @override
  List<SaveGameInfo> getAllSaves() {
    return StorageService.getAllSaves();
  }
  
  @override
  bool hasSaves() {
    return StorageService.hasSaves();
  }
  
  /// Get starter items based on character class
  List<ItemModel> _getStarterItems(CharacterClass characterClass) {
    final items = <ItemModel>[];
    
    // Common items for all classes
    items.add(ItemModel(
      id: _uuid.v4(),
      name: 'Traveler\'s Pack',
      description: 'A sturdy backpack containing basic adventuring supplies.',
      type: ItemType.misc,
      weight: 5,
      value: 2,
    ));
    
    items.add(PotionModel(
      id: _uuid.v4(),
      name: 'Potion of Healing',
      description: 'A red liquid that restores 2d4+2 hit points when consumed.',
      rarity: ItemRarity.common,
      value: 50,
      effect: PotionEffect.healing,
      effectValue: '2d4+2',
    ));
    
    items.add(ItemModel(
      id: _uuid.v4(),
      name: 'Rations',
      description: 'Enough food for several days of travel.',
      type: ItemType.consumable,
      weight: 2,
      value: 1,
      isStackable: true,
      quantity: 5,
      maxStack: 20,
    ));
    
    // Class-specific starter weapon
    switch (characterClass) {
      case CharacterClass.barbarian:
      case CharacterClass.fighter:
      case CharacterClass.paladin:
        items.add(WeaponModel(
          id: _uuid.v4(),
          name: 'Longsword',
          description: 'A versatile blade favored by warriors.',
          value: 15,
          weight: 3,
          weaponType: WeaponType.martialMelee,
          damage: '1d8',
          damageType: DamageType.slashing,
          weaponProperties: [WeaponProperty.versatile],
        ));
        break;
        
      case CharacterClass.ranger:
        items.add(WeaponModel(
          id: _uuid.v4(),
          name: 'Longbow',
          description: 'A tall bow for ranged combat.',
          value: 50,
          weight: 2,
          weaponType: WeaponType.martialRanged,
          damage: '1d8',
          damageType: DamageType.piercing,
          range: 150,
          longRange: 600,
        ));
        break;
        
      case CharacterClass.rogue:
        items.add(WeaponModel(
          id: _uuid.v4(),
          name: 'Shortsword',
          description: 'A quick blade perfect for precise strikes.',
          value: 10,
          weight: 2,
          weaponType: WeaponType.martialMelee,
          damage: '1d6',
          damageType: DamageType.piercing,
          weaponProperties: [WeaponProperty.finesse, WeaponProperty.light],
        ));
        break;
        
      case CharacterClass.monk:
        items.add(WeaponModel(
          id: _uuid.v4(),
          name: 'Quarterstaff',
          description: 'A simple but effective weapon.',
          value: 2,
          weight: 4,
          weaponType: WeaponType.simpleMelee,
          damage: '1d6',
          damageType: DamageType.bludgeoning,
          weaponProperties: [WeaponProperty.versatile],
        ));
        break;
        
      case CharacterClass.wizard:
      case CharacterClass.sorcerer:
      case CharacterClass.warlock:
        items.add(WeaponModel(
          id: _uuid.v4(),
          name: 'Dagger',
          description: 'A small blade, useful in a pinch.',
          value: 2,
          weight: 1,
          weaponType: WeaponType.simpleMelee,
          damage: '1d4',
          damageType: DamageType.piercing,
          weaponProperties: [WeaponProperty.finesse, WeaponProperty.light, WeaponProperty.thrown],
          range: 20,
          longRange: 60,
        ));
        items.add(ItemModel(
          id: _uuid.v4(),
          name: 'Spellbook',
          description: 'A leather-bound tome containing arcane knowledge.',
          type: ItemType.misc,
          weight: 3,
          value: 50,
        ));
        break;
        
      case CharacterClass.cleric:
      case CharacterClass.druid:
        items.add(WeaponModel(
          id: _uuid.v4(),
          name: 'Mace',
          description: 'A sturdy weapon blessed for battle.',
          value: 5,
          weight: 4,
          weaponType: WeaponType.simpleMelee,
          damage: '1d6',
          damageType: DamageType.bludgeoning,
        ));
        items.add(ItemModel(
          id: _uuid.v4(),
          name: 'Holy Symbol',
          description: 'A symbol of your faith, used as a spellcasting focus.',
          type: ItemType.misc,
          weight: 0,
          value: 5,
        ));
        break;
        
      case CharacterClass.bard:
        items.add(WeaponModel(
          id: _uuid.v4(),
          name: 'Rapier',
          description: 'An elegant weapon for an elegant warrior.',
          value: 25,
          weight: 2,
          weaponType: WeaponType.martialMelee,
          damage: '1d8',
          damageType: DamageType.piercing,
          weaponProperties: [WeaponProperty.finesse],
        ));
        items.add(ItemModel(
          id: _uuid.v4(),
          name: 'Lute',
          description: 'A well-crafted instrument, your spellcasting focus.',
          type: ItemType.tool,
          weight: 2,
          value: 35,
        ));
        break;
    }
    
    return items;
  }
}

/// Factory for creating new characters
class CharacterFactory {
  final Uuid _uuid = const Uuid();
  
  /// Create a new character
  CharacterModel createCharacter({
    required String name,
    required CharacterRace race,
    required CharacterClass characterClass,
    required AbilityScores abilityScores,
    Set<Skill>? proficientSkills,
    String? backgroundStory,
  }) {
    final now = DateTime.now();
    
    // Calculate starting HP
    final hitDice = GameConstants.hitDiceByClass[characterClass.name] ?? GameConstants.d8;
    final conModifier = GameConstants.getModifier(abilityScores.constitution);
    final startingHP = hitDice + conModifier;
    
    // Calculate AC (base 10 + DEX modifier)
    final dexModifier = GameConstants.getModifier(abilityScores.dexterity);
    final baseAC = GameConstants.baseArmorClass + dexModifier;
    
    // Get default proficient skills for class
    final skills = proficientSkills ?? _getDefaultSkills(characterClass);
    
    // Apply racial bonuses (simplified)
    final adjustedScores = _applyRacialBonuses(abilityScores, race);
    
    return CharacterModel(
      id: _uuid.v4(),
      name: name,
      race: race,
      characterClass: characterClass,
      level: 1,
      experiencePoints: 0,
      abilityScores: adjustedScores,
      currentHitPoints: startingHP,
      maxHitPoints: startingHP,
      armorClass: baseAC,
      proficientSkills: skills,
      backgroundStory: backgroundStory,
      hitDiceRemaining: 1,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  /// Get default proficient skills for a class
  Set<Skill> _getDefaultSkills(CharacterClass characterClass) {
    switch (characterClass) {
      case CharacterClass.barbarian:
        return {Skill.athletics, Skill.intimidation};
      case CharacterClass.bard:
        return {Skill.performance, Skill.persuasion, Skill.deception};
      case CharacterClass.cleric:
        return {Skill.medicine, Skill.religion};
      case CharacterClass.druid:
        return {Skill.nature, Skill.survival};
      case CharacterClass.fighter:
        return {Skill.athletics, Skill.perception};
      case CharacterClass.monk:
        return {Skill.acrobatics, Skill.stealth};
      case CharacterClass.paladin:
        return {Skill.athletics, Skill.persuasion};
      case CharacterClass.ranger:
        return {Skill.nature, Skill.survival, Skill.perception};
      case CharacterClass.rogue:
        return {Skill.stealth, Skill.sleightOfHand, Skill.acrobatics, Skill.perception};
      case CharacterClass.sorcerer:
        return {Skill.arcana, Skill.persuasion};
      case CharacterClass.warlock:
        return {Skill.arcana, Skill.deception};
      case CharacterClass.wizard:
        return {Skill.arcana, Skill.history, Skill.investigation};
    }
  }
  
  /// Apply racial ability score bonuses
  AbilityScores _applyRacialBonuses(AbilityScores base, CharacterRace race) {
    switch (race) {
      case CharacterRace.human:
        // +1 to all stats
        return AbilityScores(
          strength: base.strength + 1,
          dexterity: base.dexterity + 1,
          constitution: base.constitution + 1,
          intelligence: base.intelligence + 1,
          wisdom: base.wisdom + 1,
          charisma: base.charisma + 1,
        );
      case CharacterRace.elf:
        return base.copyWith(dexterity: base.dexterity + 2);
      case CharacterRace.dwarf:
        return base.copyWith(constitution: base.constitution + 2);
      case CharacterRace.halfling:
        return base.copyWith(dexterity: base.dexterity + 2);
      case CharacterRace.dragonborn:
        return base.copyWith(
          strength: base.strength + 2,
          charisma: base.charisma + 1,
        );
      case CharacterRace.gnome:
        return base.copyWith(intelligence: base.intelligence + 2);
      case CharacterRace.halfElf:
        return base.copyWith(charisma: base.charisma + 2);
      case CharacterRace.halfOrc:
        return base.copyWith(
          strength: base.strength + 2,
          constitution: base.constitution + 1,
        );
      case CharacterRace.tiefling:
        return base.copyWith(
          intelligence: base.intelligence + 1,
          charisma: base.charisma + 2,
        );
    }
  }
}


