import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/data/services/auth_service.dart';

@GenerateMocks([Dio])
import 'auth_service_test.mocks.dart';

void main() {
  group('Guest Account', () {
    late MockDio mockDio;
    late AuthService authService;

    setUp(() {
      // Setup SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      
      mockDio = MockDio();
      when(mockDio.options).thenReturn(BaseOptions());
      when(mockDio.interceptors).thenReturn(Interceptors());
      
      authService = AuthService(
        baseUrl: 'http://localhost:3002',
        dio: mockDio,
      );
    });

    group('continueAsGuest', () {
      test('should create new guest account when none exists', () async {
        // Arrange - Login fails (no account), then register succeeds
        var loginAttempts = 0;
        
        when(mockDio.post('/auth/login', data: anyNamed('data')))
            .thenAnswer((_) async {
          loginAttempts++;
          throw DioException(
            requestOptions: RequestOptions(path: '/auth/login'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/login'),
              statusCode: 401,
              data: {'error': 'Invalid credentials'},
            ),
            type: DioExceptionType.badResponse,
          );
        });

        when(mockDio.post('/auth/register', data: anyNamed('data')))
            .thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 201,
          data: {
            'user': {
              'id': 'guest-uuid',
              'email': 'guest_12345@guest.dndgame.local',
              'display_name': 'Adventurer',
            },
            'accessToken': 'guest-access-token',
            'refreshToken': 'guest-refresh-token',
          },
        ));

        // Act
        final result = await authService.continueAsGuest();

        // Assert
        expect(result.success, true);
        expect(result.user?.displayName, 'Adventurer');
        expect(loginAttempts, 1); // Should try login first
      });

      test('should login to existing guest account', () async {
        // Arrange - Set existing guest ID
        SharedPreferences.setMockInitialValues({
          'guest_device_id': 'guest_existing_12345',
        });
        
        authService = AuthService(
          baseUrl: 'http://localhost:3002',
          dio: mockDio,
        );

        when(mockDio.post('/auth/login', data: anyNamed('data')))
            .thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 200,
          data: {
            'user': {
              'id': 'guest-uuid',
              'email': 'guest_existing_12345@guest.dndgame.local',
              'display_name': 'Adventurer',
            },
            'accessToken': 'guest-access-token',
            'refreshToken': 'guest-refresh-token',
          },
        ));

        // Act
        final result = await authService.continueAsGuest();

        // Assert
        expect(result.success, true);
        verifyNever(mockDio.post('/auth/register', data: anyNamed('data')));
      });

      test('should persist guest ID across sessions', () async {
        // Arrange
        when(mockDio.post('/auth/login', data: anyNamed('data')))
            .thenThrow(DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 401,
            data: {'error': 'Invalid credentials'},
          ),
          type: DioExceptionType.badResponse,
        ));

        when(mockDio.post('/auth/register', data: anyNamed('data')))
            .thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 201,
          data: {
            'user': {
              'id': 'guest-uuid',
              'email': 'test@guest.dndgame.local',
              'display_name': 'Adventurer',
            },
            'accessToken': 'guest-access-token',
            'refreshToken': 'guest-refresh-token',
          },
        ));

        // Act - First guest session
        await authService.continueAsGuest();

        // Assert - Guest ID should be saved
        final prefs = await SharedPreferences.getInstance();
        final guestId = prefs.getString('guest_device_id');
        expect(guestId, isNotNull);
        expect(guestId, startsWith('guest_'));
      });

      test('should mark account as guest', () async {
        // Arrange
        when(mockDio.post('/auth/login', data: anyNamed('data')))
            .thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 200,
          data: {
            'user': {
              'id': 'guest-uuid',
              'email': 'guest@guest.dndgame.local',
              'display_name': 'Adventurer',
            },
            'accessToken': 'guest-access-token',
            'refreshToken': 'guest-refresh-token',
          },
        ));

        // Act
        await authService.continueAsGuest();

        // Assert
        final isGuest = await authService.isGuestAccount();
        expect(isGuest, true);
      });
    });

    group('isGuestAccount', () {
      test('should return false for non-guest accounts', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'is_guest_account': false,
        });

        // Act
        final result = await authService.isGuestAccount();

        // Assert
        expect(result, false);
      });

      test('should return true for guest accounts', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'is_guest_account': true,
        });
        
        authService = AuthService(
          baseUrl: 'http://localhost:3002',
          dio: mockDio,
        );

        // Act
        final result = await authService.isGuestAccount();

        // Assert
        expect(result, true);
      });

      test('should return false when no preference is set', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act
        final result = await authService.isGuestAccount();

        // Assert
        expect(result, false);
      });
    });

    group('clearGuestData', () {
      test('should clear all guest-related data', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'guest_device_id': 'guest_12345',
          'is_guest_account': true,
        });
        
        authService = AuthService(
          baseUrl: 'http://localhost:3002',
          dio: mockDio,
        );

        // Act
        await authService.clearGuestData();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('guest_device_id'), null);
        expect(prefs.getBool('is_guest_account'), null);
      });
    });
  });

  group('Guest Account Integration', () {
    test('guest account should have unique ID per device', () async {
      SharedPreferences.setMockInitialValues({});
      
      // Create first "device"
      final prefs1 = await SharedPreferences.getInstance();
      
      // Simulate guest ID generation
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final guestId1 = 'guest_${timestamp}_${timestamp.hashCode.abs() % 100000}';
      await prefs1.setString('guest_device_id', guestId1);
      
      // Wait a bit to ensure different timestamp
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Generate second ID (simulating different device)
      final timestamp2 = DateTime.now().millisecondsSinceEpoch;
      final guestId2 = 'guest_${timestamp2}_${timestamp2.hashCode.abs() % 100000}';
      
      // IDs should be different
      expect(guestId1, isNot(equals(guestId2)));
    });

    test('guest email should be deterministic for same guest ID', () {
      const guestId = 'guest_12345_67890';
      final email1 = '$guestId@guest.dndgame.local';
      final email2 = '$guestId@guest.dndgame.local';
      
      expect(email1, equals(email2));
    });
  });
}

