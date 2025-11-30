import 'package:equatable/equatable.dart';
import '../../core/constants/game_constants.dart';

/// Represents an item in the game
class ItemModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final ItemType type;
  final ItemRarity rarity;
  final double weight;
  final int value; // in gold pieces
  final bool isEquippable;
  final bool isConsumable;
  final bool isStackable;
  final int quantity;
  final int? maxStack;
  final Map<String, dynamic>? properties;
  final String? iconAsset;
  final bool isQuestItem;

  const ItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.rarity = ItemRarity.common,
    this.weight = 0,
    this.value = 0,
    this.isEquippable = false,
    this.isConsumable = false,
    this.isStackable = false,
    this.quantity = 1,
    this.maxStack,
    this.properties,
    this.iconAsset,
    this.isQuestItem = false,
  });

  ItemModel copyWith({
    String? id,
    String? name,
    String? description,
    ItemType? type,
    ItemRarity? rarity,
    double? weight,
    int? value,
    bool? isEquippable,
    bool? isConsumable,
    bool? isStackable,
    int? quantity,
    int? maxStack,
    Map<String, dynamic>? properties,
    String? iconAsset,
    bool? isQuestItem,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      weight: weight ?? this.weight,
      value: value ?? this.value,
      isEquippable: isEquippable ?? this.isEquippable,
      isConsumable: isConsumable ?? this.isConsumable,
      isStackable: isStackable ?? this.isStackable,
      quantity: quantity ?? this.quantity,
      maxStack: maxStack ?? this.maxStack,
      properties: properties ?? this.properties,
      iconAsset: iconAsset ?? this.iconAsset,
      isQuestItem: isQuestItem ?? this.isQuestItem,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'rarity': rarity.name,
      'weight': weight,
      'value': value,
      'isEquippable': isEquippable,
      'isConsumable': isConsumable,
      'isStackable': isStackable,
      'quantity': quantity,
      'maxStack': maxStack,
      'properties': properties,
      'iconAsset': iconAsset,
      'isQuestItem': isQuestItem,
    };
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: ItemType.values.firstWhere((t) => t.name == json['type']),
      rarity: ItemRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => ItemRarity.common,
      ),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      value: json['value'] as int? ?? 0,
      isEquippable: json['isEquippable'] as bool? ?? false,
      isConsumable: json['isConsumable'] as bool? ?? false,
      isStackable: json['isStackable'] as bool? ?? false,
      quantity: json['quantity'] as int? ?? 1,
      maxStack: json['maxStack'] as int?,
      properties: json['properties'] as Map<String, dynamic>?,
      iconAsset: json['iconAsset'] as String?,
      isQuestItem: json['isQuestItem'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id, name, description, type, rarity, weight, value,
    isEquippable, isConsumable, isStackable, quantity, maxStack,
    properties, iconAsset, isQuestItem,
  ];
}

/// Represents a weapon item
class WeaponModel extends ItemModel {
  final WeaponType weaponType;
  final String damage; // e.g., "1d8"
  final DamageType damageType;
  final List<WeaponProperty> weaponProperties;
  final int? range;
  final int? longRange;

  const WeaponModel({
    required super.id,
    required super.name,
    required super.description,
    super.rarity,
    super.weight,
    super.value,
    super.properties,
    super.iconAsset,
    required this.weaponType,
    required this.damage,
    required this.damageType,
    this.weaponProperties = const [],
    this.range,
    this.longRange,
  }) : super(
    type: ItemType.weapon,
    isEquippable: true,
    isConsumable: false,
    isStackable: false,
  );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'weaponType': weaponType.name,
      'damage': damage,
      'damageType': damageType.name,
      'weaponProperties': weaponProperties.map((p) => p.name).toList(),
      'range': range,
      'longRange': longRange,
    });
    return json;
  }

  factory WeaponModel.fromJson(Map<String, dynamic> json) {
    return WeaponModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      rarity: ItemRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => ItemRarity.common,
      ),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      value: json['value'] as int? ?? 0,
      properties: json['properties'] as Map<String, dynamic>?,
      iconAsset: json['iconAsset'] as String?,
      weaponType: WeaponType.values.firstWhere((t) => t.name == json['weaponType']),
      damage: json['damage'] as String,
      damageType: DamageType.values.firstWhere((d) => d.name == json['damageType']),
      weaponProperties: (json['weaponProperties'] as List<dynamic>?)
          ?.map((p) => WeaponProperty.values.firstWhere((wp) => wp.name == p))
          .toList() ?? [],
      range: json['range'] as int?,
      longRange: json['longRange'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    weaponType, damage, damageType, weaponProperties, range, longRange,
  ];
}

/// Weapon properties
enum WeaponProperty {
  ammunition('Ammunition'),
  finesse('Finesse'),
  heavy('Heavy'),
  light('Light'),
  loading('Loading'),
  reach('Reach'),
  special('Special'),
  thrown('Thrown'),
  twoHanded('Two-Handed'),
  versatile('Versatile');

  final String displayName;
  const WeaponProperty(this.displayName);
}

/// Represents an armor item
class ArmorModel extends ItemModel {
  final ArmorType armorType;
  final int baseArmorClass;
  final int? maxDexBonus;
  final int? strengthRequirement;
  final bool stealthDisadvantage;

  const ArmorModel({
    required super.id,
    required super.name,
    required super.description,
    super.rarity,
    super.weight,
    super.value,
    super.properties,
    super.iconAsset,
    required this.armorType,
    required this.baseArmorClass,
    this.maxDexBonus,
    this.strengthRequirement,
    this.stealthDisadvantage = false,
  }) : super(
    type: ItemType.armor,
    isEquippable: true,
    isConsumable: false,
    isStackable: false,
  );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'armorType': armorType.name,
      'baseArmorClass': baseArmorClass,
      'maxDexBonus': maxDexBonus,
      'strengthRequirement': strengthRequirement,
      'stealthDisadvantage': stealthDisadvantage,
    });
    return json;
  }

  factory ArmorModel.fromJson(Map<String, dynamic> json) {
    return ArmorModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      rarity: ItemRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => ItemRarity.common,
      ),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      value: json['value'] as int? ?? 0,
      properties: json['properties'] as Map<String, dynamic>?,
      iconAsset: json['iconAsset'] as String?,
      armorType: ArmorType.values.firstWhere((t) => t.name == json['armorType']),
      baseArmorClass: json['baseArmorClass'] as int,
      maxDexBonus: json['maxDexBonus'] as int?,
      strengthRequirement: json['strengthRequirement'] as int?,
      stealthDisadvantage: json['stealthDisadvantage'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    armorType, baseArmorClass, maxDexBonus, strengthRequirement, stealthDisadvantage,
  ];
}

/// Represents a potion item
class PotionModel extends ItemModel {
  final PotionEffect effect;
  final String? effectValue;
  final int? duration; // in rounds

  const PotionModel({
    required super.id,
    required super.name,
    required super.description,
    super.rarity,
    super.weight = 0.5,
    super.value,
    super.iconAsset,
    required this.effect,
    this.effectValue,
    this.duration,
  }) : super(
    type: ItemType.potion,
    isEquippable: false,
    isConsumable: true,
    isStackable: true,
    maxStack: 10,
  );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'effect': effect.name,
      'effectValue': effectValue,
      'duration': duration,
    });
    return json;
  }

  factory PotionModel.fromJson(Map<String, dynamic> json) {
    return PotionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      rarity: ItemRarity.values.firstWhere(
        (r) => r.name == json['rarity'],
        orElse: () => ItemRarity.common,
      ),
      weight: (json['weight'] as num?)?.toDouble() ?? 0.5,
      value: json['value'] as int? ?? 0,
      iconAsset: json['iconAsset'] as String?,
      effect: PotionEffect.values.firstWhere((e) => e.name == json['effect']),
      effectValue: json['effectValue'] as String?,
      duration: json['duration'] as int?,
    );
  }

  @override
  List<Object?> get props => [...super.props, effect, effectValue, duration];
}

/// Potion effects
enum PotionEffect {
  healing('Healing'),
  greaterHealing('Greater Healing'),
  superiorHealing('Superior Healing'),
  supremeHealing('Supreme Healing'),
  strength('Strength'),
  speed('Speed'),
  invisibility('Invisibility'),
  fireResistance('Fire Resistance'),
  coldResistance('Cold Resistance'),
  waterBreathing('Water Breathing'),
  heroism('Heroism'),
  giantStrength('Giant Strength');

  final String displayName;
  const PotionEffect(this.displayName);
}


