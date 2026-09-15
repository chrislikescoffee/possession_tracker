import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sync_state.dart';

class AuthNotifier extends Notifier<User?> {
  @override
  User? build() {
    final syncService = ref.watch(cloudSyncServiceProvider);
    final client = syncService.client;
    if (client != null) {
      client.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        final wasLoggedIn = state != null;
        state = user;
        ref.read(syncStatusProvider.notifier).checkStatus();

        if (user != null) {
          ref.read(syncStatusProvider.notifier).startRealtime();
          // Automatically trigger sync when user logs in or session refreshes
          if (!wasLoggedIn || data.event == AuthChangeEvent.signedIn) {
            ref.read(syncStatusProvider.notifier).syncNow();
          }
        } else {
          ref.read(syncStatusProvider.notifier).stopRealtime();
        }
      });

      final current = client.auth.currentUser;
      if (current != null) {
        Future.microtask(() {
          ref.read(syncStatusProvider.notifier).startRealtime();
          ref.read(syncStatusProvider.notifier).syncNow();
        });
      }
      return current;
    }
    return null;
  }

  Future<void> signIn({required String email, required String password}) async {
    final syncService = ref.read(cloudSyncServiceProvider);
    await syncService.initializeClient();
    final client = syncService.client;
    if (client == null) throw StateError('Unable to initialize Supabase connection.');
    final res = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    state = res.user;
    if (res.user != null) {
      ref.read(syncStatusProvider.notifier).startRealtime();
      await ref.read(syncStatusProvider.notifier).syncNow();
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    final syncService = ref.read(cloudSyncServiceProvider);
    await syncService.initializeClient();
    final client = syncService.client;
    if (client == null) throw StateError('Unable to initialize Supabase connection.');
    final res = await client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    state = res.user;
    if (res.user != null) {
      ref.read(syncStatusProvider.notifier).startRealtime();
      await ref.read(syncStatusProvider.notifier).syncNow();
    }
  }

  Future<void> signOut() async {
    ref.read(syncStatusProvider.notifier).stopRealtime();
    final client = ref.read(cloudSyncServiceProvider).client;
    if (client != null) {
      await client.auth.signOut();
    }
    state = null;
    await ref.read(syncStatusProvider.notifier).checkStatus();
  }
}

final authProvider = NotifierProvider<AuthNotifier, User?>(AuthNotifier.new);
