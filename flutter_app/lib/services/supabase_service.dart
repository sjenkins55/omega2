import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

class SupabaseService {
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String?> signInWithApple({
    required String identityToken,
    required String nonce,
  }) async {
    // final res = await _client!.auth.signInWithIdToken(
    //   provider: OAuthProvider.apple,
    //   idToken: identityToken,
    //   nonce: nonce,
    // );
    // return res.user?.id;
    return null;
  }

  Future<String?> signInAnonymously() async {
    // final res = await _client!.auth.signInAnonymously();
    // return res.user?.id;
    return null;
  }

  Future<void> signOut() async {
    // await _client?.auth.signOut();
  }

  String? get currentUserId {
    // return _client?.auth.currentUser?.id;
    return null;
  }

  bool get isSignedIn => currentUserId != null;

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> upsert(String table, Map<String, dynamic> data) async {
    // await _client?.from(table).upsert(data);
  }

  Future<void> delete(String table, String remoteId) async {
    // await _client?.from(table).delete().eq('id', remoteId);
  }

  Future<List<Map<String, dynamic>>> fetchAll(
    String table,
    String babyId,
  ) async {
    // return await _client?.from(table).select().eq('baby_id', babyId) ?? [];
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchSince(
    String table,
    String babyId,
    DateTime since,
  ) async {
    // return await _client
    //     ?.from(table)
    //     .select()
    //     .eq('baby_id', babyId)
    //     .gte('updated_at', since.toIso8601String()) ?? [];
    return [];
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  void subscribeToTable(
    String table,
    String babyId,
    void Function(Map<String, dynamic>) onInsertUpdate,
    void Function(String) onDelete,
  ) {
    // _client?.from(table).stream(primaryKey: ['id']).eq('baby_id', babyId).listen((rows) {
    //   for (final row in rows) { onInsertUpdate(row); }
    // });
  }

  void unsubscribeAll() {
    // _client?.removeAllChannels();
  }
}
