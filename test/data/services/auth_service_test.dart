import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dnd_ai_game/data/services/auth_service.dart';

@GenerateMocks([Dio])
import 'auth_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('AuthService', () {
    late MockDio mockDio;
    late AuthService authService;

    setUp(() async {
      // Initialize SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      
      mockDio = MockDio();
      
      // Setup default options
      when(mockDio.options).thenReturn(BaseOptions());
      when(mockDio.interceptors).thenReturn(Interceptors());
      
      authService = AuthService(
        baseUrl: 'http://localhost:3002',
        dio: mockDio,
      );
    });

    group('register', () {
      test('should return success when registration succeeds', () async {
        // Arrange
        when(mockDio.post(
          '/auth/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/auth/register'),
          statusCode: 201,
          data: {
            'user': {
              'id': 'test-uuid',
              'email': 'test@example.com',
              'display_name': 'TestUser',
            },
            'accessToken': 'mock-access-token',
            'refreshToken': 'mock-refresh-token',
            'expiresIn': 86400,
          },
        ));

        // Act
        final result = await authService.register(
          email: 'test@example.com',
          password: 'password123',
          displayName: 'TestUser',
        );

        // Assert
        expect(result.success, true);
        expect(result.user?.email, 'test@example.com');
        expect(result.user?.displayName, 'TestUser');
        expect(result.accessToken, 'mock-access-token');
      });

      test('should return failure when email already exists', () async {
        // Arrange
        when(mockDio.post(
          '/auth/register',
          data: anyNamed('data'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/auth/register'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/register'),
            statusCode: 409,
            data: {'error': 'Email already registered'},
          ),
          type: DioExceptionType.badResponse,
        ));

        // Act
        final result = await authService.register(
          email: 'existing@example.com',
          password: 'password123',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, 'Email already registered');
      });

      test('should return failure when password is missing', () async {
        // Arrange
        when(mockDio.post(
          '/auth/register',
          data: anyNamed('data'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/auth/register'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/register'),
            statusCode: 400,
            data: {'error': 'Email and password required'},
          ),
          type: DioExceptionType.badResponse,
        ));

        // Act
        final result = await authService.register(
          email: 'test@example.com',
          password: '',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, 'Email and password required');
      });
    });

    group('signIn', () {
      test('should return success when login succeeds', () async {
        // Arrange
        when(mockDio.post(
          '/auth/login',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 200,
          data: {
            'user': {
              'id': 'test-uuid',
              'email': 'test@example.com',
              'display_name': 'TestUser',
            },
            'accessToken': 'mock-access-token',
            'refreshToken': 'mock-refresh-token',
            'expiresIn': 86400,
          },
        ));

        // Act
        final result = await authService.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(result.success, true);
        expect(result.user?.email, 'test@example.com');
        expect(authService.isAuthenticated, true);
      });

      test('should return failure when credentials are invalid', () async {
        // Arrange
        when(mockDio.post(
          '/auth/login',
          data: anyNamed('data'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 401,
            data: {'error': 'Invalid credentials'},
          ),
          type: DioExceptionType.badResponse,
        ));

        // Act
        final result = await authService.signIn(
          email: 'test@example.com',
          password: 'wrongpassword',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, 'Invalid credentials');
      });

      test('should return failure when server is unavailable', () async {
        // Arrange
        when(mockDio.post(
          '/auth/login',
          data: anyNamed('data'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        ));

        // Act
        final result = await authService.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, contains('Invalid credentials'));
      });
    });

    group('signOut', () {
      test('should clear authentication state', () async {
        // Arrange - First login
        when(mockDio.post(
          '/auth/login',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 200,
          data: {
            'user': {
              'id': 'test-uuid',
              'email': 'test@example.com',
              'display_name': 'TestUser',
            },
            'accessToken': 'mock-access-token',
            'refreshToken': 'mock-refresh-token',
          },
        ));

        when(mockDio.post(
          '/auth/logout',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          requestOptions: RequestOptions(path: '/auth/logout'),
          statusCode: 200,
          data: {'message': 'Logged out successfully'},
        ));

        await authService.signIn(
          email: 'test@example.com',
          password: 'password123',
        );
        expect(authService.isAuthenticated, true);

        // Act
        await authService.signOut();

        // Assert
        expect(authService.isAuthenticated, false);
        expect(authService.currentUser, null);
      });
    });
  });

  group('AppUser', () {
    test('should create from JSON correctly', () {
      final json = {
        'id': 'test-uuid',
        'email': 'test@example.com',
        'display_name': 'TestUser',
        'avatar_url': 'https://example.com/avatar.png',
        'created_at': '2024-01-01T00:00:00Z',
      };

      final user = AppUser.fromJson(json);

      expect(user.id, 'test-uuid');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'TestUser');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
    });

    test('should handle missing optional fields', () {
      final json = {
        'id': 'test-uuid',
        'email': 'test@example.com',
      };

      final user = AppUser.fromJson(json);

      expect(user.id, 'test-uuid');
      expect(user.email, 'test@example.com');
      expect(user.displayName, '');
      expect(user.avatarUrl, null);
    });
  });

  group('AuthResult', () {
    test('should create success result', () {
      final user = AppUser(
        id: 'test-uuid',
        email: 'test@example.com',
        displayName: 'TestUser',
      );

      final result = AuthResult.success(
        user: user,
        accessToken: 'token',
        refreshToken: 'refresh',
      );

      expect(result.success, true);
      expect(result.user, user);
      expect(result.error, null);
    });

    test('should create failure result', () {
      final result = AuthResult.failure('Something went wrong');

      expect(result.success, false);
      expect(result.user, null);
      expect(result.error, 'Something went wrong');
    });
  });
}

