/// Game constants for D&D 5e mechanics
class GameConstants {
  // Dice types
  static const int d4 = 4;
  static const int d6 = 6;
  static const int d8 = 8;
  static const int d10 = 10;
  static const int d12 = 12;
  static const int d20 = 20;
  static const int d100 = 100;
  
  // Base stats range
  static const int minStatValue = 1;
  static const int maxStatValue = 20;
  static const int defaultStatValue = 10;
  
  // Level range
  static const int minLevel = 1;
  static const int maxLevel = 20;
  
  // XP thresholds per level
  static const List<int> xpThresholds = [
    0,      // Level 1
    300,    // Level 2
    900,    // Level 3
    2700,   // Level 4
    6500,   // Level 5
    14000,  // Level 6
    23000,  // Level 7
    34000,  // Level 8
    48000,  // Level 9
    64000,  // Level 10
    85000,  // Level 11
    100000, // Level 12
    120000, // Level 13
    140000, // Level 14
    165000, // Level 15
    195000, // Level 16
    225000, // Level 17
    265000, // Level 18
    305000, // Level 19
    355000, // Level 20
  ];
  
  // Proficiency bonus by level
  static const List<int> proficiencyBonus = [
    2, 2, 2, 2,  // Levels 1-4
    3, 3, 3, 3,  // Levels 5-8
    4, 4, 4, 4,  // Levels 9-12
    5, 5, 5, 5,  // Levels 13-16
    6, 6, 6, 6,  // Levels 17-20
  ];
  
  // Hit dice by class
  static const Map<String, int> hitDiceByClass = {
    'barbarian': d12,
    'fighter': d10,
    'paladin': d10,
    'ranger': d10,
    'bard': d8,
    'cleric': d8,
    'druid': d8,
    'monk': d8,
    'rogue': d8,
    'warlock': d8,
    'sorcerer': d6,
    'wizard': d6,
  };
  
  // Ability score modifier calculation
  static int getModifier(int abilityScore) {
    return ((abilityScore - 10) / 2).floor();
  }
  
  // Difficulty classes
  static const int dcVeryEasy = 5;
  static const int dcEasy = 10;
  static const int dcMedium = 15;
  static const int dcHard = 20;
  static const int dcVeryHard = 25;
  static const int dcNearlyImpossible = 30;
  
  // Combat constants
  static const int criticalHitThreshold = 20;
  static const int criticalFailThreshold = 1;
  
  // Armor class base
  static const int baseArmorClass = 10;
  
  // Movement speeds (in feet)
  static const int defaultSpeed = 30;
  
  // Carry capacity multiplier (strength score * this)
  static const int carryCapacityMultiplier = 15;
}

/// Ability scores enum
enum Ability {
  strength('STR', 'Strength'),
  dexterity('DEX', 'Dexterity'),
  constitution('CON', 'Constitution'),
  intelligence('INT', 'Intelligence'),
  wisdom('WIS', 'Wisdom'),
  charisma('CHA', 'Charisma');
  
  final String abbreviation;
  final String fullName;
  
  const Ability(this.abbreviation, this.fullName);
}

/// Skills enum with associated ability
enum Skill {
  // Strength skills
  athletics(Ability.strength, 'Athletics'),
  
  // Dexterity skills
  acrobatics(Ability.dexterity, 'Acrobatics'),
  sleightOfHand(Ability.dexterity, 'Sleight of Hand'),
  stealth(Ability.dexterity, 'Stealth'),
  
  // Intelligence skills
  arcana(Ability.intelligence, 'Arcana'),
  history(Ability.intelligence, 'History'),
  investigation(Ability.intelligence, 'Investigation'),
  nature(Ability.intelligence, 'Nature'),
  religion(Ability.intelligence, 'Religion'),
  
  // Wisdom skills
  animalHandling(Ability.wisdom, 'Animal Handling'),
  insight(Ability.wisdom, 'Insight'),
  medicine(Ability.wisdom, 'Medicine'),
  perception(Ability.wisdom, 'Perception'),
  survival(Ability.wisdom, 'Survival'),
  
  // Charisma skills
  deception(Ability.charisma, 'Deception'),
  intimidation(Ability.charisma, 'Intimidation'),
  performance(Ability.charisma, 'Performance'),
  persuasion(Ability.charisma, 'Persuasion');
  
  final Ability ability;
  final String displayName;
  
  const Skill(this.ability, this.displayName);
}

/// Character classes
enum CharacterClass {
  barbarian('Barbarian', 'A fierce warrior of primitive background'),
  bard('Bard', 'An inspiring magician whose power echoes the music of creation'),
  cleric('Cleric', 'A priestly champion who wields divine magic'),
  druid('Druid', 'A priest of the Old Faith, wielding nature powers'),
  fighter('Fighter', 'A master of martial combat'),
  monk('Monk', 'A master of martial arts, harnessing body power'),
  paladin('Paladin', 'A holy warrior bound to a sacred oath'),
  ranger('Ranger', 'A warrior who combats threats on civilization edges'),
  rogue('Rogue', 'A scoundrel who uses stealth and trickery'),
  sorcerer('Sorcerer', 'A spellcaster who draws on inherent magic'),
  warlock('Warlock', 'A wielder of magic derived from a bargain'),
  wizard('Wizard', 'A scholarly magic-user');
  
  final String displayName;
  final String description;
  
  const CharacterClass(this.displayName, this.description);
}

/// Character races
enum CharacterRace {
  human('Human', 'Versatile and ambitious'),
  elf('Elf', 'Magical people of otherworldly grace'),
  dwarf('Dwarf', 'Bold and hardy, known as skilled warriors'),
  halfling('Halfling', 'Small folk who enjoy peace and comfort'),
  dragonborn('Dragonborn', 'Born of dragons, walking proudly'),
  gnome('Gnome', 'A people of boundless enthusiasm'),
  halfElf('Half-Elf', 'Walking in two worlds'),
  halfOrc('Half-Orc', 'Combining human and orc heritage'),
  tiefling('Tiefling', 'Bearing the infernal bloodline');
  
  final String displayName;
  final String description;
  
  const CharacterRace(this.displayName, this.description);
}

/// Damage types
enum DamageType {
  slashing('Slashing'),
  piercing('Piercing'),
  bludgeoning('Bludgeoning'),
  fire('Fire'),
  cold('Cold'),
  lightning('Lightning'),
  thunder('Thunder'),
  acid('Acid'),
  poison('Poison'),
  necrotic('Necrotic'),
  radiant('Radiant'),
  force('Force'),
  psychic('Psychic');
  
  final String displayName;
  
  const DamageType(this.displayName);
}

/// Item rarity
enum ItemRarity {
  common('Common', 0xFFFFFFFF),
  uncommon('Uncommon', 0xFF1EFF00),
  rare('Rare', 0xFF0070DD),
  veryRare('Very Rare', 0xFFA335EE),
  legendary('Legendary', 0xFFFF8000),
  artifact('Artifact', 0xFFE6CC80);
  
  final String displayName;
  final int colorValue;
  
  const ItemRarity(this.displayName, this.colorValue);
}

/// Item types
enum ItemType {
  weapon('Weapon'),
  armor('Armor'),
  shield('Shield'),
  potion('Potion'),
  scroll('Scroll'),
  wand('Wand'),
  ring('Ring'),
  amulet('Amulet'),
  tool('Tool'),
  consumable('Consumable'),
  treasure('Treasure'),
  questItem('Quest Item'),
  misc('Miscellaneous');
  
  final String displayName;
  
  const ItemType(this.displayName);
}

/// Weapon types
enum WeaponType {
  simpleMelee('Simple Melee'),
  simpleRanged('Simple Ranged'),
  martialMelee('Martial Melee'),
  martialRanged('Martial Ranged');
  
  final String displayName;
  
  const WeaponType(this.displayName);
}

/// Armor types
enum ArmorType {
  light('Light Armor'),
  medium('Medium Armor'),
  heavy('Heavy Armor');
  
  final String displayName;
  
  const ArmorType(this.displayName);
}

/// Condition effects
enum Condition {
  blinded('Blinded'),
  charmed('Charmed'),
  deafened('Deafened'),
  frightened('Frightened'),
  grappled('Grappled'),
  incapacitated('Incapacitated'),
  invisible('Invisible'),
  paralyzed('Paralyzed'),
  petrified('Petrified'),
  poisoned('Poisoned'),
  prone('Prone'),
  restrained('Restrained'),
  stunned('Stunned'),
  unconscious('Unconscious'),
  exhaustion('Exhaustion');
  
  final String displayName;
  
  const Condition(this.displayName);
}


