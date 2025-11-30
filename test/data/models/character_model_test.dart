import 'package:flutter_test/flutter_test.dart';
import 'package:dnd_ai_game/data/models/character_model.dart';
import 'package:dnd_ai_game/core/constants/game_constants.dart';

void main() {
  group('CharacterModel', () {
    late CharacterModel character;
    
    setUp(() {
      character = CharacterModel(
        id: 'test-id',
        name: 'Test Hero',
        race: CharacterRace.human,
        characterClass: CharacterClass.fighter,
        level: 5,
        experiencePoints: 6500,
        abilityScores: const AbilityScores(
          strength: 16,
          dexterity: 14,
          constitution: 15,
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        currentHitPoints: 45,
        maxHitPoints: 50,
        armorClass: 18,
        proficientSkills: {Skill.athletics, Skill.perception},
        hitDiceRemaining: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });
    
    group('proficiencyBonus', () {
      test('should return correct bonus for level 1-4', () {
        final lowLevel = character.copyWith(level: 3);
        expect(lowLevel.proficiencyBonus, equals(2));
      });
      
      test('should return correct bonus for level 5-8', () {
        expect(character.proficiencyBonus, equals(3));
      });
      
      test('should return correct bonus for level 17-20', () {
        final highLevel = character.copyWith(level: 18);
        expect(highLevel.proficiencyBonus, equals(6));
      });
    });
    
    group('getAbilityModifier', () {
      test('should calculate modifier correctly for 16 STR', () {
        expect(character.getAbilityModifier(Ability.strength), equals(3));
      });
      
      test('should calculate modifier correctly for 10 INT', () {
        expect(character.getAbilityModifier(Ability.intelligence), equals(0));
      });
      
      test('should calculate modifier correctly for 8 CHA', () {
        expect(character.getAbilityModifier(Ability.charisma), equals(-1));
      });
    });
    
    group('getSkillModifier', () {
      test('should add proficiency bonus for proficient skills', () {
        // Athletics uses STR (+3) and character is proficient (+3)
        expect(character.getSkillModifier(Skill.athletics), equals(6));
      });
      
      test('should not add proficiency for non-proficient skills', () {
        // Stealth uses DEX (+2) but character is not proficient
        expect(character.getSkillModifier(Skill.stealth), equals(2));
      });
      
      test('should double proficiency for expertise skills', () {
        final expert = character.copyWith(
          expertiseSkills: {Skill.athletics},
        );
        // Athletics uses STR (+3) and character has expertise (+6)
        expect(expert.getSkillModifier(Skill.athletics), equals(9));
      });
    });
    
    group('initiativeModifier', () {
      test('should equal dexterity modifier', () {
        expect(character.initiativeModifier, equals(2)); // DEX 14 = +2
      });
    });
    
    group('passivePerception', () {
      test('should be 10 + perception modifier', () {
        // Perception uses WIS (+1) and character is proficient (+3)
        expect(character.passivePerception, equals(14)); // 10 + 1 + 3
      });
    });
    
    group('xpToNextLevel', () {
      test('should calculate remaining XP correctly', () {
        // Level 5 needs 6500 XP, level 6 needs 14000
        expect(character.xpToNextLevel, equals(14000 - 6500));
      });
      
      test('should return 0 at max level', () {
        final maxLevel = character.copyWith(level: 20);
        expect(maxLevel.xpToNextLevel, equals(0));
      });
    });
    
    group('isAlive', () {
      test('should return true when HP > 0', () {
        expect(character.isAlive, isTrue);
      });
      
      test('should return true when HP = 0 but death saves not failed', () {
        final downed = character.copyWith(currentHitPoints: 0);
        expect(downed.isAlive, isTrue);
      });
      
      test('should return false when death saves failed', () {
        final dead = character.copyWith(
          currentHitPoints: 0,
          deathSaveFailures: 3,
        );
        expect(dead.isAlive, isFalse);
      });
    });
    
    group('serialization', () {
      test('should serialize to JSON correctly', () {
        final json = character.toJson();
        expect(json['name'], equals('Test Hero'));
        expect(json['level'], equals(5));
        expect(json['race'], equals('human'));
        expect(json['characterClass'], equals('fighter'));
      });
      
      test('should deserialize from JSON correctly', () {
        final json = character.toJson();
        final restored = CharacterModel.fromJson(json);
        expect(restored.name, equals(character.name));
        expect(restored.level, equals(character.level));
        expect(restored.abilityScores.strength, equals(character.abilityScores.strength));
      });
    });
  });
  
  group('AbilityScores', () {
    test('getScore should return correct values', () {
      const scores = AbilityScores(
        strength: 18,
        dexterity: 14,
        constitution: 16,
        intelligence: 10,
        wisdom: 12,
        charisma: 8,
      );
      
      expect(scores.getScore(Ability.strength), equals(18));
      expect(scores.getScore(Ability.dexterity), equals(14));
      expect(scores.getScore(Ability.constitution), equals(16));
      expect(scores.getScore(Ability.intelligence), equals(10));
      expect(scores.getScore(Ability.wisdom), equals(12));
      expect(scores.getScore(Ability.charisma), equals(8));
    });
    
    test('getModifier should calculate correctly', () {
      const scores = AbilityScores(
        strength: 18,
        dexterity: 14,
        constitution: 16,
        intelligence: 10,
        wisdom: 12,
        charisma: 8,
      );
      
      expect(scores.getModifier(Ability.strength), equals(4));
      expect(scores.getModifier(Ability.dexterity), equals(2));
      expect(scores.getModifier(Ability.constitution), equals(3));
      expect(scores.getModifier(Ability.intelligence), equals(0));
      expect(scores.getModifier(Ability.wisdom), equals(1));
      expect(scores.getModifier(Ability.charisma), equals(-1));
    });
    
    test('standard factory should create all 10s', () {
      final standard = AbilityScores.standard();
      expect(standard.strength, equals(10));
      expect(standard.dexterity, equals(10));
      expect(standard.constitution, equals(10));
      expect(standard.intelligence, equals(10));
      expect(standard.wisdom, equals(10));
      expect(standard.charisma, equals(10));
    });
  });
}


