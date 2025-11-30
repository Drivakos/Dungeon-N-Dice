import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/data/repositories/item_repository.dart';
import 'package:dnd_ai_game/data/models/item_model.dart';
import 'package:dnd_ai_game/core/constants/game_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ItemTemplate', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should create with required fields', () {
      const template = ItemTemplate(
        name: 'Test Item',
        description: 'A test item',
        type: ItemType.misc,
      );

      expect(template.name, 'Test Item');
      expect(template.description, 'A test item');
      expect(template.type, ItemType.misc);
      expect(template.rarity, ItemRarity.common);
      expect(template.weight, 1.0);
      expect(template.value, 10);
    });

    test('toItem should create ItemModel with new ID', () {
      const template = ItemTemplate(
        name: 'Healing Potion',
        description: 'Heals wounds',
        type: ItemType.potion,
        rarity: ItemRarity.common,
        weight: 0.5,
        value: 50,
        effect: 'heal:2d4+2',
      );

      final item = template.toItem();

      expect(item.id, isNotEmpty);
      expect(item.name, 'Healing Potion');
      expect(item.description, 'Heals wounds');
      expect(item.type, ItemType.potion);
      expect(item.rarity, ItemRarity.common);
    });
  });

  group('ItemRepository Potions', () {
    test('should contain healing potion', () {
      expect(ItemRepository.potions.containsKey('healing_potion'), isTrue);
      
      final potion = ItemRepository.potions['healing_potion']!;
      expect(potion.name, 'Healing Potion');
      expect(potion.type, ItemType.potion);
      expect(potion.effect, 'heal:2d4+2');
    });

    test('should contain greater healing potion', () {
      expect(ItemRepository.potions.containsKey('greater_healing_potion'), isTrue);
      
      final potion = ItemRepository.potions['greater_healing_potion']!;
      expect(potion.rarity, ItemRarity.uncommon);
      expect(potion.effect, 'heal:4d4+4');
    });

    test('should contain antidote', () {
      expect(ItemRepository.potions.containsKey('antidote'), isTrue);
      
      final potion = ItemRepository.potions['antidote']!;
      expect(potion.effect, 'cure:poison');
    });
  });

  group('ItemRepository Weapons', () {
    test('should contain longsword', () {
      expect(ItemRepository.weapons.containsKey('longsword'), isTrue);
      
      final weapon = ItemRepository.weapons['longsword']!;
      expect(weapon.name, 'Longsword');
      expect(weapon.type, ItemType.weapon);
      expect(weapon.properties?['damage'], '1d8');
      expect(weapon.properties?['damageType'], 'slashing');
    });

    test('should contain dagger', () {
      expect(ItemRepository.weapons.containsKey('dagger'), isTrue);
      
      final weapon = ItemRepository.weapons['dagger']!;
      expect(weapon.properties?['finesse'], isTrue);
      expect(weapon.properties?['thrown'], isTrue);
    });

    test('should contain longbow', () {
      expect(ItemRepository.weapons.containsKey('longbow'), isTrue);
      
      final weapon = ItemRepository.weapons['longbow']!;
      expect(weapon.properties?['ranged'], isTrue);
      expect(weapon.properties?['range'], '150/600');
    });
  });

  group('ItemRepository Armor', () {
    test('should contain leather armor', () {
      expect(ItemRepository.armor.containsKey('leather_armor'), isTrue);
      
      final armor = ItemRepository.armor['leather_armor']!;
      expect(armor.name, 'Leather Armor');
      expect(armor.type, ItemType.armor);
      expect(armor.properties?['ac'], 11);
      expect(armor.properties?['armorType'], 'light');
    });

    test('should contain plate armor', () {
      expect(ItemRepository.armor.containsKey('plate_armor'), isTrue);
      
      final armor = ItemRepository.armor['plate_armor']!;
      expect(armor.properties?['ac'], 18);
      expect(armor.properties?['armorType'], 'heavy');
      expect(armor.properties?['strRequirement'], 15);
    });

    test('should contain shield', () {
      expect(ItemRepository.armor.containsKey('shield'), isTrue);
      
      final armor = ItemRepository.armor['shield']!;
      expect(armor.properties?['acBonus'], 2);
    });
  });

  group('ItemRepository Gear', () {
    test('should contain torch', () {
      expect(ItemRepository.gear.containsKey('torch'), isTrue);
      
      final gear = ItemRepository.gear['torch']!;
      expect(gear.name, 'Torch');
      expect(gear.type, ItemType.tool);
    });

    test('should contain thieves tools', () {
      expect(ItemRepository.gear.containsKey('thieves_tools'), isTrue);
      
      final gear = ItemRepository.gear['thieves_tools']!;
      expect(gear.name, "Thieves' Tools");
    });
  });

  group('ItemRepository Magic Items', () {
    test('should contain ring of protection', () {
      expect(ItemRepository.magicItems.containsKey('ring_of_protection'), isTrue);
      
      final item = ItemRepository.magicItems['ring_of_protection']!;
      expect(item.rarity, ItemRarity.rare);
      expect(item.properties?['acBonus'], 1);
    });

    test('should contain bag of holding', () {
      expect(ItemRepository.magicItems.containsKey('bag_of_holding'), isTrue);
      
      final item = ItemRepository.magicItems['bag_of_holding']!;
      expect(item.rarity, ItemRarity.uncommon);
    });
  });

  group('ItemRepository findByName', () {
    test('should find item by exact name', () {
      final template = ItemRepository.findByName('Healing Potion');

      expect(template, isNotNull);
      expect(template!.name, 'Healing Potion');
    });

    test('should find item case-insensitively', () {
      final template = ItemRepository.findByName('healing potion');

      expect(template, isNotNull);
      expect(template!.name, 'Healing Potion');
    });

    test('should find item by key', () {
      final template = ItemRepository.findByName('healing_potion');

      expect(template, isNotNull);
      expect(template!.name, 'Healing Potion');
    });

    test('should return null for unknown item', () {
      final template = ItemRepository.findByName('Nonexistent Item');

      expect(template, isNull);
    });
  });

  group('ItemRepository findByType', () {
    test('should find all potions', () {
      final potions = ItemRepository.findByType(ItemType.potion);

      expect(potions, isNotEmpty);
      expect(potions.every((p) => p.type == ItemType.potion), isTrue);
    });

    test('should find all weapons', () {
      final weapons = ItemRepository.findByType(ItemType.weapon);

      expect(weapons, isNotEmpty);
      expect(weapons.every((w) => w.type == ItemType.weapon), isTrue);
    });
  });

  group('ItemRepository findByRarity', () {
    test('should find common items', () {
      final items = ItemRepository.findByRarity(ItemRarity.common);

      expect(items, isNotEmpty);
      expect(items.every((i) => i.rarity == ItemRarity.common), isTrue);
    });

    test('should find rare items', () {
      final items = ItemRepository.findByRarity(ItemRarity.rare);

      expect(items, isNotEmpty);
      expect(items.every((i) => i.rarity == ItemRarity.rare), isTrue);
    });
  });

  group('ItemRepository validateItem', () {
    test('should return known item template', () {
      final template = ItemRepository.validateItem('Healing Potion');

      expect(template, isNotNull);
      expect(template!.name, 'Healing Potion');
      expect(template.effect, 'heal:2d4+2');
    });

    test('should enforce rarity cap', () {
      final template = ItemRepository.validateItem(
        'Ring of Protection',
        maxRarity: ItemRarity.uncommon,
      );

      // Ring of Protection is rare, should be rejected with uncommon cap
      expect(template, isNull);
    });

    test('should create dynamic template for unknown potion', () {
      final template = ItemRepository.validateItem('Mystery Healing Elixir');

      expect(template, isNotNull);
      expect(template!.type, ItemType.potion);
    });

    test('should create dynamic template for unknown weapon', () {
      final template = ItemRepository.validateItem('Ancient Sword');

      expect(template, isNotNull);
      expect(template!.type, ItemType.weapon);
    });

    test('should detect rarity from name', () {
      final template = ItemRepository.validateItem('Rare Enchanted Ring');

      expect(template, isNotNull);
      expect(template!.rarity, ItemRarity.rare);
    });
  });

  group('ItemRepository createItem', () {
    test('should create item from known template', () {
      final item = ItemRepository.createItem('Longsword');

      expect(item.name, 'Longsword');
      expect(item.type, ItemType.weapon);
      expect(item.id, isNotEmpty);
    });

    test('should create item from dynamic template', () {
      final item = ItemRepository.createItem('Custom Dagger');

      expect(item.name, 'Custom Dagger');
      expect(item.type, ItemType.weapon);
      expect(item.id, isNotEmpty);
    });

    test('should create fallback item for unknown', () {
      final item = ItemRepository.createItem('Random Thing');

      expect(item.name, 'Random Thing');
      expect(item.type, ItemType.misc);
    });
  });

  group('ItemRepository getRandomLoot', () {
    test('should return items for low level', () {
      final loot = ItemRepository.getRandomLoot(1, count: 3);

      expect(loot, hasLength(lessThanOrEqualTo(3)));
      for (final item in loot) {
        expect(item.rarity.index, lessThanOrEqualTo(ItemRarity.uncommon.index));
      }
    });

    test('should return items for high level', () {
      final loot = ItemRepository.getRandomLoot(15, count: 3);

      expect(loot, hasLength(lessThanOrEqualTo(3)));
    });

    test('should return empty list for count 0', () {
      final loot = ItemRepository.getRandomLoot(1, count: 0);

      expect(loot, isEmpty);
    });
  });

  group('AllItems', () {
    test('should contain all item categories', () {
      final allItems = ItemRepository.allItems;

      // Check that we have items from each category
      expect(allItems.values.any((i) => i.type == ItemType.potion), isTrue);
      expect(allItems.values.any((i) => i.type == ItemType.weapon), isTrue);
      expect(allItems.values.any((i) => i.type == ItemType.armor), isTrue);
      expect(allItems.values.any((i) => i.type == ItemType.tool), isTrue);
      expect(allItems.values.any((i) => i.type == ItemType.ring), isTrue);
    });

    test('should have unique keys', () {
      final allItems = ItemRepository.allItems;
      final keys = allItems.keys.toList();
      final uniqueKeys = keys.toSet();

      expect(keys.length, uniqueKeys.length);
    });
  });
}

