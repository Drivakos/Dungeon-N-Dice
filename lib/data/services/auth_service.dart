import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User model
class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String? ?? json['displayName'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'created_at': createdAt?.toIso8601String(),
  };
}

/// Auth state
enum AuthState {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

/// Auth result
class AuthResult {
  final bool success;
  final AppUser? user;
  final String? error;
  final String? accessToken;
  final String? refreshToken;

  const AuthResult({
    required this.success,
    this.user,
    this.error,
    this.accessToken,
    this.refreshToken,
  });

  factory AuthResult.success({
    required AppUser user,
    required String accessToken,
    required String refreshToken,
  }) {
    return AuthResult(
      success: true,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(
      success: false,
      error: error,
    );
  }
}

/// Authentication service
class AuthService {
  final Dio _dio;
  final String _baseUrl;
  
  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _userKey = 'auth_user';

  String? _accessToken;
  String? _refreshToken;
  AppUser? _currentUser;

  AuthService({
    String? baseUrl,
    Dio? dio,
  }) : _baseUrl = baseUrl ?? 'http://localhost:3002',
       _dio = dio ?? Dio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    
    // Add interceptor for token refresh
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 403 && _refreshToken != null) {
            // Try to refresh token
            final refreshed = await _refreshAccessToken();
            if (refreshed) {
              // Retry the request
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $_accessToken';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Get current user
  AppUser? get currentUser => _currentUser;

  /// Check if authenticated
  bool get isAuthenticated => _accessToken != null && _currentUser != null;

  /// Initialize auth state from storage
  Future<AuthState> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _accessToken = prefs.getString(_accessTokenKey);
      _refreshToken = prefs.getString(_refreshTokenKey);
      final userJson = prefs.getString(_userKey);
      
      if (userJson != null) {
        _currentUser = AppUser.fromJson(jsonDecode(userJson));
      }
      
      if (_accessToken != null) {
        // Verify token is still valid
        try {
          final response = await _dio.get('/auth/me');
          if (response.statusCode == 200 && response.data['user'] != null) {
            _currentUser = AppUser.fromJson(response.data['user']);
            await _saveUserToStorage(_currentUser!);
            return AuthState.authenticated;
          }
        } catch (e) {
          // Token might be expired, try refresh
          if (_refreshToken != null) {
            final refreshed = await _refreshAccessToken();
            if (refreshed) {
              return AuthState.authenticated;
            }
          }
          // Clear invalid tokens
          await signOut();
        }
      }
      
      return AuthState.unauthenticated;
    } catch (e) {
      print('Auth initialization error: $e');
      return AuthState.unauthenticated;
    }
  }

  /// Register new user
  Future<AuthResult> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      });

      if (response.statusCode == 201 && response.data != null) {
        final data = response.data;
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        _currentUser = AppUser.fromJson(data['user']);
        
        await _saveToStorage();
        
        return AuthResult.success(
          user: _currentUser!,
          accessToken: _accessToken!,
          refreshToken: _refreshToken!,
        );
      }
      
      return AuthResult.failure('Registration failed');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ?? 'Registration failed';
      return AuthResult.failure(errorMsg);
    } catch (e) {
      return AuthResult.failure('Registration failed: $e');
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('AuthService: Attempting login for $email to $_baseUrl');
      
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      print('AuthService: Response status ${response.statusCode}');
      print('AuthService: Response data ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'];
        _currentUser = AppUser.fromJson(data['user']);
        
        await _saveToStorage();
        
        print('AuthService: Login successful, user: ${_currentUser?.email}');
        
        return AuthResult.success(
          user: _currentUser!,
          accessToken: _accessToken!,
          refreshToken: _refreshToken!,
        );
      }
      
      print('AuthService: Login failed - unexpected response');
      return AuthResult.failure('Sign in failed');
    } on DioException catch (e) {
      print('AuthService: DioException - ${e.type} - ${e.message}');
      print('AuthService: Response: ${e.response?.data}');
      final errorMsg = e.response?.data?['error'] ?? 'Invalid credentials';
      return AuthResult.failure(errorMsg);
    } catch (e) {
      print('AuthService: Exception - $e');
      return AuthResult.failure('Sign in failed: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (_accessToken != null) {
        await _dio.post('/auth/logout', data: {
          'refreshToken': _refreshToken,
        });
      }
    } catch (e) {
      // Ignore errors during logout
    }
    
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    
    await _clearStorage();
  }

  /// Refresh access token
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    
    try {
      final response = await Dio().post(
        '$_baseUrl/auth/refresh',
        data: {'refreshToken': _refreshToken},
      );
      
      if (response.statusCode == 200 && response.data['accessToken'] != null) {
        _accessToken = response.data['accessToken'];
        await _saveToStorage();
        return true;
      }
    } catch (e) {
      print('Token refresh failed: $e');
    }
    
    return false;
  }

  /// Save auth data to storage
  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (_accessToken != null) {
      await prefs.setString(_accessTokenKey, _accessToken!);
    }
    if (_refreshToken != null) {
      await prefs.setString(_refreshTokenKey, _refreshToken!);
    }
    if (_currentUser != null) {
      await _saveUserToStorage(_currentUser!);
    }
  }

  Future<void> _saveUserToStorage(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// Clear storage
  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
  }

  /// Get access token for API calls
  String? get accessToken => _accessToken;

  // =====================================================
  // GUEST ACCOUNT FUNCTIONALITY
  // =====================================================
  
  static const String _guestIdKey = 'guest_device_id';
  static const String _isGuestKey = 'is_guest_account';
  
  /// Check if current user is a guest
  Future<bool> isGuestAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isGuestKey) ?? false;
  }

  /// Get or create a persistent guest device ID
  Future<String> _getOrCreateGuestId() async {
    final prefs = await SharedPreferences.getInstance();
    String? guestId = prefs.getString(_guestIdKey);
    
    if (guestId == null) {
      // Generate a unique guest ID based on timestamp and random
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = timestamp.hashCode.abs() % 100000;
      guestId = 'guest_${timestamp}_$random';
      await prefs.setString(_guestIdKey, guestId);
    }
    
    return guestId;
  }

  /// Continue as guest - creates or logs into a persistent guest account
  /// This ensures the user never loses progress even without signing up
  Future<AuthResult> continueAsGuest() async {
    try {
      final guestId = await _getOrCreateGuestId();
      final guestEmail = '$guestId@guest.dndgame.local';
      final guestPassword = 'guest_${guestId}_secure';
      
      print('AuthService: Attempting guest login for $guestEmail');
      
      // First try to login (existing guest account)
      try {
        final loginResult = await signIn(
          email: guestEmail,
          password: guestPassword,
        );
        
        if (loginResult.success) {
          // Mark as guest account
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_isGuestKey, true);
          
          print('AuthService: Guest login successful');
          return loginResult;
        }
      } on DioException catch (e) {
        // If 401, account doesn't exist - create it
        if (e.response?.statusCode != 401) {
          rethrow;
        }
        print('AuthService: Guest account not found, creating new one');
      }
      
      // Create new guest account
      final registerResult = await register(
        email: guestEmail,
        password: guestPassword,
        displayName: 'Adventurer',
      );
      
      if (registerResult.success) {
        // Mark as guest account
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isGuestKey, true);
        
        print('AuthService: Guest account created successfully');
      }
      
      return registerResult;
    } catch (e) {
      print('AuthService: Guest auth failed - $e');
      return AuthResult.failure('Failed to continue as guest: $e');
    }
  }

  /// Convert guest account to full account
  /// This allows guests to "claim" their account with a real email
  Future<AuthResult> convertGuestToFullAccount({
    required String newEmail,
    required String newPassword,
    String? displayName,
  }) async {
    if (!await isGuestAccount()) {
      return AuthResult.failure('Not a guest account');
    }
    
    if (_currentUser == null || _accessToken == null) {
      return AuthResult.failure('No active session');
    }
    
    try {
      // Call API to update email/password
      final response = await _dio.put('/auth/convert-guest', data: {
        'newEmail': newEmail,
        'newPassword': newPassword,
        'displayName': displayName,
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        _currentUser = AppUser.fromJson(data['user']);
        
        // Clear guest flag
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isGuestKey, false);
        
        await _saveToStorage();
        
        return AuthResult.success(
          user: _currentUser!,
          accessToken: _accessToken!,
          refreshToken: _refreshToken!,
        );
      }
      
      return AuthResult.failure('Failed to convert account');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ?? 'Conversion failed';
      return AuthResult.failure(errorMsg);
    } catch (e) {
      return AuthResult.failure('Failed to convert account: $e');
    }
  }

  /// Clear guest account data (for testing or reset)
  Future<void> clearGuestData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestIdKey);
    await prefs.remove(_isGuestKey);
  }
}

/// Game save model for listing
class GameSaveInfo {
  final String id;
  final String saveName;
  final String characterName;
  final String characterClass;
  final int characterLevel;
  final DateTime createdAt;
  final DateTime lastPlayedAt;
  final int totalPlayTimeSeconds;
  final String? thumbnailUrl;

  const GameSaveInfo({
    required this.id,
    required this.saveName,
    required this.characterName,
    required this.characterClass,
    required this.characterLevel,
    required this.createdAt,
    required this.lastPlayedAt,
    required this.totalPlayTimeSeconds,
    this.thumbnailUrl,
  });

  factory GameSaveInfo.fromJson(Map<String, dynamic> json) {
    return GameSaveInfo(
      id: json['id'] as String,
      saveName: json['save_name'] as String,
      characterName: json['character_name'] as String? ?? 'Unknown',
      characterClass: json['character_class'] as String? ?? 'Adventurer',
      characterLevel: json['character_level'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastPlayedAt: DateTime.parse(json['last_played_at'] as String),
      totalPlayTimeSeconds: json['total_play_time_seconds'] as int? ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }

  String get playTimeFormatted {
    final hours = totalPlayTimeSeconds ~/ 3600;
    final minutes = (totalPlayTimeSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Cloud save service
class CloudSaveService {
  final Dio _dio;
  final String _baseUrl;
  final AuthService _authService;

  CloudSaveService({
    required AuthService authService,
    String? baseUrl,
    Dio? dio,
  }) : _authService = authService,
       _baseUrl = baseUrl ?? 'http://localhost:3002',
       _dio = dio ?? Dio() {
    _dio.options.baseUrl = _baseUrl;
    
    // Add auth header
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _authService.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Get all saves for current user
  Future<List<GameSaveInfo>> getSaves() async {
    try {
      final response = await _dio.get('/saves');
      
      if (response.statusCode == 200 && response.data['saves'] != null) {
        final saves = (response.data['saves'] as List)
            .map((s) => GameSaveInfo.fromJson(s as Map<String, dynamic>))
            .toList();
        return saves;
      }
      
      return [];
    } catch (e) {
      print('Get saves error: $e');
      return [];
    }
  }

  /// Get full save data
  Future<Map<String, dynamic>?> loadSave(String saveId) async {
    try {
      final response = await _dio.get('/saves/$saveId');
      
      if (response.statusCode == 200 && response.data['save'] != null) {
        return response.data['save'] as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Load save error: $e');
      return null;
    }
  }

  /// Create new save
  Future<String?> createSave({
    required String saveName,
    required Map<String, dynamic> characterData,
    required Map<String, dynamic> gameState,
  }) async {
    try {
      final response = await _dio.post('/saves', data: {
        'saveName': saveName,
        'characterData': characterData,
        'gameState': gameState,
      });
      
      if (response.statusCode == 201 && response.data['save'] != null) {
        return response.data['save']['id'] as String;
      }
      
      return null;
    } catch (e) {
      print('Create save error: $e');
      return null;
    }
  }

  /// Update save
  Future<bool> updateSave({
    required String saveId,
    String? saveName,
    Map<String, dynamic>? characterData,
    Map<String, dynamic>? gameState,
    int? totalPlayTimeSeconds,
  }) async {
    try {
      final response = await _dio.put('/saves/$saveId', data: {
        if (saveName != null) 'saveName': saveName,
        if (characterData != null) 'characterData': characterData,
        if (gameState != null) 'gameState': gameState,
        if (totalPlayTimeSeconds != null) 'totalPlayTimeSeconds': totalPlayTimeSeconds,
      });
      
      return response.statusCode == 200;
    } catch (e) {
      print('Update save error: $e');
      return false;
    }
  }

  /// Delete save
  Future<bool> deleteSave(String saveId) async {
    try {
      final response = await _dio.delete('/saves/$saveId');
      return response.statusCode == 200;
    } catch (e) {
      print('Delete save error: $e');
      return false;
    }
  }
}

