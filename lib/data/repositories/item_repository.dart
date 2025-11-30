import 'package:uuid/uuid.dart';

import '../models/item_model.dart';
import '../../core/constants/game_constants.dart';

/// Template for creating items
class ItemTemplate {
  final String name;
  final String description;
  final ItemType type;
  final ItemRarity rarity;
  final double weight;
  final int value;
  final String? effect;  // e.g., "heal:2d4+2" for potions
  final Map<String, dynamic>? properties;

  const ItemTemplate({
    required this.name,
    required this.description,
    required this.type,
    this.rarity = ItemRarity.common,
    this.weight = 1.0,
    this.value = 10,
    this.effect,
    this.properties,
  });

  /// Create an ItemModel from this template
  ItemModel toItem() {
    return ItemModel(
      id: const Uuid().v4(),
      name: name,
      description: description,
      type: type,
      rarity: rarity,
      weight: weight,
      value: value,
    );
  }
}

/// Repository of predefined D&D items
/// Used to validate AI-proposed items and create standardized items
class ItemRepository {
  static final _uuid = const Uuid();

  /// Common potions
  static final Map<String, ItemTemplate> potions = {
    'healing_potion': const ItemTemplate(
      name: 'Healing Potion',
      description: 'A red liquid that heals wounds when consumed.',
      type: ItemType.potion,
      rarity: ItemRarity.common,
      weight: 0.5,
      value: 50,
      effect: 'heal:2d4+2',
    ),
    'greater_healing_potion': const ItemTemplate(
      name: 'Potion of Greater Healing',
      description: 'A bright red potion that provides substantial healing.',
      type: ItemType.potion,
      rarity: ItemRarity.uncommon,
      weight: 0.5,
      value: 150,
      effect: 'heal:4d4+4',
    ),
    'superior_healing_potion': const ItemTemplate(
      name: 'Potion of Superior Healing',
      description: 'A deep crimson potion with exceptional healing properties.',
      type: ItemType.potion,
      rarity: ItemRarity.rare,
      weight: 0.5,
      value: 450,
      effect: 'heal:8d4+8',
    ),
    'antidote': const ItemTemplate(
      name: 'Antidote',
      description: 'Cures poison when consumed.',
      type: ItemType.potion,
      rarity: ItemRarity.common,
      weight: 0.5,
      value: 50,
      effect: 'cure:poison',
    ),
    'potion_of_fire_resistance': const ItemTemplate(
      name: 'Potion of Fire Resistance',
      description: 'Grants resistance to fire damage for 1 hour.',
      type: ItemType.potion,
      rarity: ItemRarity.uncommon,
      weight: 0.5,
      value: 250,
      effect: 'resistance:fire',
    ),
  };

  /// Common weapons
  static final Map<String, ItemTemplate> weapons = {
    'longsword': const ItemTemplate(
      name: 'Longsword',
      description: 'A versatile blade favored by warriors.',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      weight: 3.0,
      value: 15,
      properties: {'damage': '1d8', 'damageType': 'slashing', 'versatile': '1d10'},
    ),
    'shortsword': const ItemTemplate(
      name: 'Shortsword',
      description: 'A light, finesse weapon ideal for quick strikes.',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      weight: 2.0,
      value: 10,
      properties: {'damage': '1d6', 'damageType': 'piercing', 'finesse': true},
    ),
    'dagger': const ItemTemplate(
      name: 'Dagger',
      description: 'A simple blade useful for close combat or throwing.',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      weight: 1.0,
      value: 2,
      properties: {'damage': '1d4', 'damageType': 'piercing', 'finesse': true, 'thrown': true},
    ),
    'battleaxe': const ItemTemplate(
      name: 'Battleaxe',
      description: 'A heavy axe designed for war.',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      weight: 4.0,
      value: 10,
      properties: {'damage': '1d8', 'damageType': 'slashing', 'versatile': '1d10'},
    ),
    'greataxe': const ItemTemplate(
      name: 'Greataxe',
      description: 'A massive two-handed axe.',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      weight: 7.0,
      value: 30,
      properties: {'damage': '1d12', 'damageType': 'slashing', 'twoHanded': true},
    ),
    'longbow': const ItemTemplate(
      name: 'Longbow',
      description: 'A powerful ranged weapon.',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      weight: 2.0,
      value: 50,
      properties: {'damage': '1d8', 'damageType': 'piercing', 'ranged': true, 'range': '150/600'},
    ),
    'shortbow': const ItemTemplate(
      name: 'Shortbow',
      description: 'A light bow suitable for hunting and combat.',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      weight: 2.0,
      value: 25,
      properties: {'damage': '1d6', 'damageType': 'piercing', 'ranged': true, 'range': '80/320'},
    ),
    'quarterstaff': const ItemTemplate(
      name: 'Quarterstaff',
      description: 'A simple wooden staff.',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      weight: 4.0,
      value: 2,
      properties: {'damage': '1d6', 'damageType': 'bludgeoning', 'versatile': '1d8'},
    ),
    'mace': const ItemTemplate(
      name: 'Mace',
      description: 'A blunt weapon favored by clerics.',
      type: ItemType.weapon,
      rarity: ItemRarity.common,
      weight: 4.0,
      value: 5,
      properties: {'damage': '1d6', 'damageType': 'bludgeoning'},
    ),
  };

  /// Common armor
  static final Map<String, ItemTemplate> armor = {
    'leather_armor': const ItemTemplate(
      name: 'Leather Armor',
      description: 'Light armor made from hardened leather.',
      type: ItemType.armor,
      rarity: ItemRarity.common,
      weight: 10.0,
      value: 10,
      properties: {'ac': 11, 'armorType': 'light'},
    ),
    'studded_leather': const ItemTemplate(
      name: 'Studded Leather Armor',
      description: 'Leather armor reinforced with metal studs.',
      type: ItemType.armor,
      rarity: ItemRarity.common,
      weight: 13.0,
      value: 45,
      properties: {'ac': 12, 'armorType': 'light'},
    ),
    'chain_shirt': const ItemTemplate(
      name: 'Chain Shirt',
      description: 'A shirt of interlocking metal rings.',
      type: ItemType.armor,
      rarity: ItemRarity.common,
      weight: 20.0,
      value: 50,
      properties: {'ac': 13, 'armorType': 'medium', 'maxDex': 2},
    ),
    'scale_mail': const ItemTemplate(
      name: 'Scale Mail',
      description: 'Armor made of overlapping metal scales.',
      type: ItemType.armor,
      rarity: ItemRarity.common,
      weight: 45.0,
      value: 50,
      properties: {'ac': 14, 'armorType': 'medium', 'maxDex': 2, 'stealthDisadvantage': true},
    ),
    'chain_mail': const ItemTemplate(
      name: 'Chain Mail',
      description: 'Full suit of interlocking metal rings.',
      type: ItemType.armor,
      rarity: ItemRarity.common,
      weight: 55.0,
      value: 75,
      properties: {'ac': 16, 'armorType': 'heavy', 'strRequirement': 13, 'stealthDisadvantage': true},
    ),
    'plate_armor': const ItemTemplate(
      name: 'Plate Armor',
      description: 'Full plate armor offering the best protection.',
      type: ItemType.armor,
      rarity: ItemRarity.common,
      weight: 65.0,
      value: 1500,
      properties: {'ac': 18, 'armorType': 'heavy', 'strRequirement': 15, 'stealthDisadvantage': true},
    ),
    'shield': const ItemTemplate(
      name: 'Shield',
      description: 'A wooden or metal shield.',
      type: ItemType.armor,
      rarity: ItemRarity.common,
      weight: 6.0,
      value: 10,
      properties: {'acBonus': 2},
    ),
  };

  /// Adventuring gear
  static final Map<String, ItemTemplate> gear = {
    'torch': const ItemTemplate(
      name: 'Torch',
      description: 'Provides light for 1 hour.',
      type: ItemType.tool,
      rarity: ItemRarity.common,
      weight: 1.0,
      value: 1,
    ),
    'rope': const ItemTemplate(
      name: 'Rope (50 ft)',
      description: 'Hemp rope, useful for climbing and binding.',
      type: ItemType.tool,
      rarity: ItemRarity.common,
      weight: 10.0,
      value: 1,
    ),
    'rations': const ItemTemplate(
      name: 'Rations (1 day)',
      description: 'Dried food for one day.',
      type: ItemType.consumable,
      rarity: ItemRarity.common,
      weight: 2.0,
      value: 5,
    ),
    'waterskin': const ItemTemplate(
      name: 'Waterskin',
      description: 'Holds water for a day of travel.',
      type: ItemType.tool,
      rarity: ItemRarity.common,
      weight: 5.0,
      value: 2,
    ),
    'thieves_tools': const ItemTemplate(
      name: "Thieves' Tools",
      description: 'Tools for picking locks and disabling traps.',
      type: ItemType.tool,
      rarity: ItemRarity.common,
      weight: 1.0,
      value: 25,
    ),
    'bedroll': const ItemTemplate(
      name: 'Bedroll',
      description: 'A basic bedroll for camping.',
      type: ItemType.misc,
      rarity: ItemRarity.common,
      weight: 7.0,
      value: 1,
    ),
    'backpack': const ItemTemplate(
      name: 'Backpack',
      description: 'A leather backpack.',
      type: ItemType.misc,
      rarity: ItemRarity.common,
      weight: 5.0,
      value: 2,
    ),
    'lantern': const ItemTemplate(
      name: 'Lantern',
      description: 'A hooded lantern that burns oil.',
      type: ItemType.tool,
      rarity: ItemRarity.common,
      weight: 2.0,
      value: 5,
    ),
  };

  /// Quest/key items (unique)
  static final Map<String, ItemTemplate> questItems = {
    'rusty_key': const ItemTemplate(
      name: 'Rusty Key',
      description: 'An old, rusted key. It might open something.',
      type: ItemType.questItem,
      rarity: ItemRarity.common,
      weight: 0.1,
      value: 0,
    ),
    'mysterious_amulet': const ItemTemplate(
      name: 'Mysterious Amulet',
      description: 'An amulet that pulses with faint magical energy.',
      type: ItemType.questItem,
      rarity: ItemRarity.uncommon,
      weight: 0.2,
      value: 100,
    ),
    'ancient_map': const ItemTemplate(
      name: 'Ancient Map',
      description: 'A worn map showing locations of interest.',
      type: ItemType.questItem,
      rarity: ItemRarity.common,
      weight: 0.1,
      value: 0,
    ),
  };

  /// Magic items
  static final Map<String, ItemTemplate> magicItems = {
    'ring_of_protection': const ItemTemplate(
      name: 'Ring of Protection',
      description: 'A ring that grants +1 to AC and saving throws.',
      type: ItemType.ring,
      rarity: ItemRarity.rare,
      weight: 0.1,
      value: 3500,
      properties: {'acBonus': 1, 'savingThrowBonus': 1},
    ),
    'cloak_of_elvenkind': const ItemTemplate(
      name: 'Cloak of Elvenkind',
      description: 'A cloak that grants advantage on Stealth checks.',
      type: ItemType.armor,
      rarity: ItemRarity.uncommon,
      weight: 1.0,
      value: 500,
      properties: {'stealthAdvantage': true},
    ),
    'bag_of_holding': const ItemTemplate(
      name: 'Bag of Holding',
      description: 'A magical bag that holds far more than it should.',
      type: ItemType.misc,
      rarity: ItemRarity.uncommon,
      weight: 15.0,
      value: 500,
      properties: {'extraCapacity': 500},
    ),
  };

  /// All items combined for lookup
  static Map<String, ItemTemplate> get allItems => {
    ...potions,
    ...weapons,
    ...armor,
    ...gear,
    ...questItems,
    ...magicItems,
  };

  /// Find an item template by name (case-insensitive)
  static ItemTemplate? findByName(String name) {
    final normalizedName = _normalizeItemName(name);
    
    for (final entry in allItems.entries) {
      if (_normalizeItemName(entry.value.name) == normalizedName) {
        return entry.value;
      }
      if (entry.key == normalizedName) {
        return entry.value;
      }
    }
    return null;
  }

  /// Find items by type
  static List<ItemTemplate> findByType(ItemType type) {
    return allItems.values.where((item) => item.type == type).toList();
  }

  /// Find items by rarity
  static List<ItemTemplate> findByRarity(ItemRarity rarity) {
    return allItems.values.where((item) => item.rarity == rarity).toList();
  }

  /// Validate an AI-proposed item name and return a validated template
  /// If the item is known, returns the template
  /// If unknown but name is reasonable, creates a basic template
  /// If the name seems invalid, returns null
  static ItemTemplate? validateItem(String proposedName, {ItemRarity? maxRarity}) {
    // First, check if we have this exact item
    final knownItem = findByName(proposedName);
    if (knownItem != null) {
      // Check rarity constraint
      if (maxRarity != null && knownItem.rarity.index > maxRarity.index) {
        // Item exists but is too rare - downgrade or reject
        return null;
      }
      return knownItem;
    }

    // Unknown item - create a basic template based on keywords
    return _createDynamicTemplate(proposedName, maxRarity);
  }

  /// Create a dynamic item template based on name keywords
  static ItemTemplate? _createDynamicTemplate(String name, ItemRarity? maxRarity) {
    final lowerName = name.toLowerCase();
    
    // Determine type from name
    ItemType type = ItemType.misc;
    int baseValue = 10;
    double weight = 1.0;
    String? effect;
    
    if (lowerName.contains('potion') || lowerName.contains('elixir')) {
      type = ItemType.potion;
      weight = 0.5;
      baseValue = 50;
      if (lowerName.contains('heal')) {
        effect = 'heal:2d4+2';
      }
    } else if (lowerName.contains('scroll')) {
      type = ItemType.scroll;
      weight = 0.1;
      baseValue = 25;
    } else if (_isWeaponName(lowerName)) {
      type = ItemType.weapon;
      weight = 3.0;
      baseValue = 15;
    } else if (_isArmorName(lowerName)) {
      type = ItemType.armor;
      weight = 10.0;
      baseValue = 30;
    } else if (lowerName.contains('key')) {
      type = ItemType.questItem;
      weight = 0.1;
      baseValue = 0;
    } else if (lowerName.contains('ring')) {
      type = ItemType.ring;
      weight = 0.1;
      baseValue = 50;
    } else if (lowerName.contains('amulet') || lowerName.contains('necklace')) {
      type = ItemType.amulet;
      weight = 0.1;
      baseValue = 50;
    }
    
    // Determine rarity from name
    ItemRarity rarity = ItemRarity.common;
    if (lowerName.contains('legendary') || lowerName.contains('epic')) {
      rarity = ItemRarity.legendary;
      baseValue *= 100;
    } else if (lowerName.contains('very rare')) {
      rarity = ItemRarity.veryRare;
      baseValue *= 50;
    } else if (lowerName.contains('rare') || lowerName.contains('enchanted')) {
      rarity = ItemRarity.rare;
      baseValue *= 20;
    } else if (lowerName.contains('uncommon') || lowerName.contains('magic') || 
               lowerName.contains('+1')) {
      rarity = ItemRarity.uncommon;
      baseValue *= 5;
    }
    
    // Apply rarity cap
    if (maxRarity != null && rarity.index > maxRarity.index) {
      rarity = maxRarity;
    }
    
    return ItemTemplate(
      name: name,
      description: 'A $name.',
      type: type,
      rarity: rarity,
      weight: weight,
      value: baseValue,
      effect: effect,
    );
  }

  static bool _isWeaponName(String name) {
    final weaponKeywords = [
      'sword', 'axe', 'mace', 'hammer', 'dagger', 'bow', 'crossbow',
      'spear', 'halberd', 'staff', 'wand', 'blade', 'club', 'flail',
    ];
    return weaponKeywords.any((keyword) => name.contains(keyword));
  }

  static bool _isArmorName(String name) {
    final armorKeywords = [
      'armor', 'mail', 'plate', 'leather', 'shield', 'helm', 'helmet',
      'gauntlet', 'boots', 'greaves', 'breastplate',
    ];
    return armorKeywords.any((keyword) => name.contains(keyword));
  }

  /// Normalize item name for comparison
  static String _normalizeItemName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// Create an ItemModel from a template or name
  static ItemModel createItem(String name, {int quantity = 1}) {
    final template = findByName(name) ?? _createDynamicTemplate(name, null);
    if (template == null) {
      // Fallback - create basic miscellaneous item
      return ItemModel(
        id: _uuid.v4(),
        name: name,
        description: 'A $name.',
        type: ItemType.misc,
        rarity: ItemRarity.common,
        weight: 1.0,
        value: 1,
      );
    }
    return template.toItem();
  }

  /// Get random loot appropriate for a given player level
  static List<ItemTemplate> getRandomLoot(int playerLevel, {int count = 1}) {
    final loot = <ItemTemplate>[];
    final availableItems = allItems.values.toList();
    
    // Filter by level-appropriate rarity
    ItemRarity maxRarity;
    if (playerLevel < 5) {
      maxRarity = ItemRarity.uncommon;
    } else if (playerLevel < 10) {
      maxRarity = ItemRarity.rare;
    } else if (playerLevel < 15) {
      maxRarity = ItemRarity.veryRare;
    } else {
      maxRarity = ItemRarity.legendary;
    }
    
    final eligible = availableItems
        .where((item) => item.rarity.index <= maxRarity.index)
        .toList();
    
    if (eligible.isEmpty) return loot;
    
    // Simple random selection (could be weighted by rarity)
    eligible.shuffle();
    for (var i = 0; i < count && i < eligible.length; i++) {
      loot.add(eligible[i]);
    }
    
    return loot;
  }
}

