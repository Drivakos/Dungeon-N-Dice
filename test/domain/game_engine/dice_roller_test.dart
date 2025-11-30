import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dnd_ai_game/domain/game_engine/dice_roller.dart';

void main() {
  group('DiceRoller', () {
    late DiceRoller diceRoller;
    
    setUp(() {
      // Use a seeded random for reproducible tests
      diceRoller = DiceRoller(random: Random(42));
    });
    
    group('rollDie', () {
      test('should return value between 1 and sides', () {
        for (int i = 0; i < 100; i++) {
          final result = diceRoller.rollDie(20);
          expect(result, greaterThanOrEqualTo(1));
          expect(result, lessThanOrEqualTo(20));
        }
      });
      
      test('should work for different die types', () {
        expect(diceRoller.rollDie(4), inInclusiveRange(1, 4));
        expect(diceRoller.rollDie(6), inInclusiveRange(1, 6));
        expect(diceRoller.rollDie(8), inInclusiveRange(1, 8));
        expect(diceRoller.rollDie(10), inInclusiveRange(1, 10));
        expect(diceRoller.rollDie(12), inInclusiveRange(1, 12));
        expect(diceRoller.rollDie(100), inInclusiveRange(1, 100));
      });
    });
    
    group('rollDice', () {
      test('should return correct number of rolls', () {
        final result = diceRoller.rollDice(3, 6);
        expect(result.rolls.length, equals(3));
      });
      
      test('should calculate correct total', () {
        final result = diceRoller.rollDice(2, 6);
        expect(result.total, equals(result.rolls.reduce((a, b) => a + b)));
      });
      
      test('should store correct sides value', () {
        final result = diceRoller.rollDice(2, 8);
        expect(result.sides, equals(8));
      });
    });
    
    group('rollNotation', () {
      test('should parse simple notation', () {
        final result = diceRoller.rollNotation('2d6');
        expect(result.rolls.length, equals(2));
        expect(result.modifier, equals(0));
      });
      
      test('should parse notation with positive modifier', () {
        final result = diceRoller.rollNotation('1d8+3');
        expect(result.rolls.length, equals(1));
        expect(result.modifier, equals(3));
        expect(result.total, equals(result.rolls.first + 3));
      });
      
      test('should parse notation with negative modifier', () {
        final result = diceRoller.rollNotation('2d4-1');
        expect(result.rolls.length, equals(2));
        expect(result.modifier, equals(-1));
      });
      
      test('should throw on invalid notation', () {
        expect(() => diceRoller.rollNotation('invalid'), throwsArgumentError);
      });
    });
    
    group('rollD20Check', () {
      test('should return single roll without advantage/disadvantage', () {
        final result = diceRoller.rollD20Check();
        expect(result.roll2, isNull);
        expect(result.hadAdvantage, isFalse);
        expect(result.hadDisadvantage, isFalse);
      });
      
      test('should return higher roll with advantage', () {
        // Run multiple times to verify behavior
        for (int i = 0; i < 10; i++) {
          final result = diceRoller.rollD20Check(advantage: true);
          expect(result.roll2, isNotNull);
          expect(result.hadAdvantage, isTrue);
          expect(result.result, equals(
            result.roll1 > result.roll2! ? result.roll1 : result.roll2!
          ));
        }
      });
      
      test('should return lower roll with disadvantage', () {
        for (int i = 0; i < 10; i++) {
          final result = diceRoller.rollD20Check(disadvantage: true);
          expect(result.roll2, isNotNull);
          expect(result.hadDisadvantage, isTrue);
          expect(result.result, equals(
            result.roll1 < result.roll2! ? result.roll1 : result.roll2!
          ));
        }
      });
      
      test('should cancel out advantage and disadvantage', () {
        final result = diceRoller.rollD20Check(advantage: true, disadvantage: true);
        expect(result.roll2, isNull);
        expect(result.hadAdvantage, isFalse);
        expect(result.hadDisadvantage, isFalse);
      });
    });
    
    group('rollSkillCheck', () {
      test('should correctly determine success', () {
        final result = diceRoller.rollSkillCheck(
          modifier: 5,
          difficultyClass: 10,
        );
        expect(result.isSuccess, equals(result.total >= 10));
      });
      
      test('should identify critical success', () {
        // Force a natural 20 by using specific seed
        final seededRoller = DiceRoller(random: _FakeRandom(20));
        final result = seededRoller.rollSkillCheck(
          modifier: 0,
          difficultyClass: 15,
        );
        expect(result.isCriticalSuccess, isTrue);
      });
      
      test('should identify critical failure', () {
        final seededRoller = DiceRoller(random: _FakeRandom(1));
        final result = seededRoller.rollSkillCheck(
          modifier: 10,
          difficultyClass: 5,
        );
        expect(result.isCriticalFailure, isTrue);
      });
    });
    
    group('rollAttack', () {
      test('should hit on natural 20 regardless of AC', () {
        final seededRoller = DiceRoller(random: _FakeRandom(20));
        final result = seededRoller.rollAttack(
          attackBonus: -10,
          targetAC: 30,
        );
        expect(result.isHit, isTrue);
        expect(result.isCriticalHit, isTrue);
      });
      
      test('should miss on natural 1 regardless of bonus', () {
        final seededRoller = DiceRoller(random: _FakeRandom(1));
        final result = seededRoller.rollAttack(
          attackBonus: 100,
          targetAC: 10,
        );
        expect(result.isHit, isFalse);
        expect(result.isCriticalMiss, isTrue);
      });
    });
    
    group('rollDamage', () {
      test('should double dice on critical hit', () {
        final result = diceRoller.rollDamage(
          damageNotation: '1d8+3',
          isCritical: true,
        );
        expect(result.rolls.length, equals(2)); // 2d8 instead of 1d8
        expect(result.isCritical, isTrue);
      });
    });
    
    group('rollAbilityScore', () {
      test('should roll 4 dice and keep highest 3', () {
        final result = diceRoller.rollAbilityScore();
        expect(result.allRolls.length, equals(4));
        expect(result.keptRolls.length, equals(3));
        expect(result.total, equals(result.keptRolls.reduce((a, b) => a + b)));
      });
      
      test('should drop the lowest roll', () {
        final result = diceRoller.rollAbilityScore();
        final minKept = result.keptRolls.reduce((a, b) => a < b ? a : b);
        expect(result.droppedRoll, lessThanOrEqualTo(minKept));
      });
    });
  });
}

/// Fake random that always returns a specific value
class _FakeRandom implements Random {
  final int _value;
  
  _FakeRandom(this._value);
  
  @override
  int nextInt(int max) => _value - 1; // -1 because nextInt is 0-based
  
  @override
  double nextDouble() => _value / 20;
  
  @override
  bool nextBool() => _value > 10;
}


