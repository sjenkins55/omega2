import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/caregiver.dart';
import '../models/sync_types.dart';
import 'supabase_service.dart';

enum AuthState { loading, anonymous, authenticated }

class AuthNotifier extends StateNotifier<AuthState> {
  final AppDatabase _db;
  final SupabaseService _supabase;

  /// The caregiver for the current device. Null only before [resolveInitialState]
  /// completes or after [signOut].
  Caregiver? currentCaregiver;

  AuthNotifier(this._db, this._supabase) : super(AuthState.loading);

  /// Called once at app startup (e.g. in main.dart after ProviderScope is live).
  Future<void> resolveInitialState() async {
    final dbCaregiver = await _db.getCurrentCaregiver();
    if (dbCaregiver != null) {
      currentCaregiver = Caregiver(
        id: dbCaregiver.id,
        displayName: dbCaregiver.displayName,
        email: dbCaregiver.email,
        supabaseUserId: dbCaregiver.supabaseUserId,
        role: CaregiverRole.values.byName(dbCaregiver.role),
        isCurrentDevice: true,
        syncStatus: SyncStatus.values.byName(dbCaregiver.syncStatus),
        remoteId: dbCaregiver.remoteId,
        createdAt: dbCaregiver.createdAt,
        updatedAt: dbCaregiver.updatedAt,
      );
      state = dbCaregiver.supabaseUserId != null
          ? AuthState.authenticated
          : AuthState.anonymous;
    } else {
      state = AuthState.anonymous;
    }
  }

  /// Sign in with Apple (iOS only). The raw [identityToken] comes from
  /// the sign_in_with_apple package.
  Future<void> signInWithApple(String identityToken) async {
    final nonce = _generateNonce();
    final hashedNonce = _sha256(nonce);
    final userId = await _supabase.signInWithApple(
      identityToken: identityToken,
      nonce: hashedNonce,
    );
    if (userId != null && currentCaregiver != null) {
      currentCaregiver = Caregiver(
        id: currentCaregiver!.id,
        displayName: currentCaregiver!.displayName,
        email: currentCaregiver!.email,
        supabaseUserId: userId,
        role: currentCaregiver!.role,
        isCurrentDevice: true,
        syncStatus: SyncStatus.pending,
        remoteId: currentCaregiver!.remoteId,
        createdAt: currentCaregiver!.createdAt,
        updatedAt: DateTime.now(),
      );
      // Persist the updated supabaseUserId to the local DB.
      await _db.upsertCaregiver(
        CaregiversCompanion(
          id: Value(currentCaregiver!.id),
          displayName: Value(currentCaregiver!.displayName),
          email: Value(currentCaregiver!.email),
          supabaseUserId: Value(userId),
          role: Value(currentCaregiver!.role.name),
          isCurrentDevice: const Value(true),
          syncStatus: const Value('pending'),
          remoteId: Value(currentCaregiver!.remoteId),
          createdAt: Value(currentCaregiver!.createdAt),
          updatedAt: Value(currentCaregiver!.updatedAt),
        ),
      );
      state = AuthState.authenticated;
    }
  }

  Future<void> signOut() async {
    await _supabase.signOut();
    currentCaregiver = null;
    state = AuthState.anonymous;
  }

  bool get isAuthenticated => state == AuthState.authenticated;
  bool get isLoading => state == AuthState.loading;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _generateNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
