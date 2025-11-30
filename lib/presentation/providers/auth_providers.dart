import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/auth_service.dart';

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Cloud save service provider
final cloudSaveServiceProvider = Provider<CloudSaveService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return CloudSaveService(authService: authService);
});

/// Auth state provider
final authStateProvider = FutureProvider<AuthState>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.initialize();
});

/// Current user provider
final currentUserProvider = Provider<AppUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.isAuthenticated;
});

/// User saves provider - fetches saves from cloud
final userSavesProvider = FutureProvider<List<GameSaveInfo>>((ref) async {
  final cloudSaveService = ref.watch(cloudSaveServiceProvider);
  final authState = ref.watch(authStateProvider);
  
  // Only fetch if authenticated
  if (authState.valueOrNull != AuthState.authenticated) {
    return [];
  }
  
  return await cloudSaveService.getSaves();
});

/// Selected save provider for loading
final selectedSaveIdProvider = StateProvider<String?>((ref) => null);

/// Auth notifier for managing auth state changes
class AuthNotifier extends StateNotifier<AsyncValue<AuthState>> {
  final AuthService _authService;
  final Ref _ref;

  AuthNotifier(this._authService, this._ref) : super(const AsyncValue.loading()) {
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      final authState = await _authService.initialize();
      state = AsyncValue.data(authState);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    
    final result = await _authService.signIn(
      email: email,
      password: password,
    );
    
    if (result.success) {
      state = const AsyncValue.data(AuthState.authenticated);
      _ref.invalidate(userSavesProvider);
    } else {
      state = const AsyncValue.data(AuthState.unauthenticated);
    }
    
    return result;
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    
    final result = await _authService.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    
    if (result.success) {
      state = const AsyncValue.data(AuthState.authenticated);
      _ref.invalidate(userSavesProvider);
    } else {
      state = const AsyncValue.data(AuthState.unauthenticated);
    }
    
    return result;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(AuthState.unauthenticated);
    _ref.invalidate(userSavesProvider);
  }
}

/// Auth notifier provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AuthState>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService, ref);
});

