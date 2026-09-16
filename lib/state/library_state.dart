import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/library_model.dart';
import 'repository_provider.dart';

class LibraryQuota {
  final int current;
  final int max;
  const LibraryQuota({required this.current, required this.max});
}

/// Provider for list of all libraries the user belongs to
final librariesProvider = FutureProvider<List<Library>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getLibraries();
});

/// AsyncNotifier to track the currently selected library
class SelectedLibraryNotifier extends AsyncNotifier<Library?> {
  @override
  Future<Library?> build() async {
    final repo = ref.watch(repositoryProvider);
    final list = await repo.getLibraries();
    if (list.isEmpty) {
      return repo.createLibrary('My Primary Library');
    }

    // When signed in, prioritize user's cloud library over local seed demo
    try {
      if (Supabase.instance.isInitialized) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          final ownedNonSeed = list
              .where((l) => l.ownerId == currentUser.id && l.id != 'lib-workshop-01')
              .firstOrNull;
          if (ownedNonSeed != null) return ownedNonSeed;

          final nonSeed = list.where((l) => l.id != 'lib-workshop-01').firstOrNull;
          if (nonSeed != null) return nonSeed;
        }
      }
    } catch (_) {}

    final nonSeed = list.where((l) => l.id != 'lib-workshop-01').firstOrNull;
    if (nonSeed != null) return nonSeed;

    return list.first;
  }

  void selectLibrary(Library library) {
    state = AsyncValue.data(library);
  }

  Future<void> createAndSelect(String name) async {
    final repo = ref.read(repositoryProvider);
    final created = await repo.createLibrary(name);
    ref.invalidate(librariesProvider);
    state = AsyncValue.data(created);
  }
}

final selectedLibraryProvider =
    AsyncNotifierProvider<SelectedLibraryNotifier, Library?>(SelectedLibraryNotifier.new);

/// Item count and quota for the selected library
final libraryQuotaProvider = FutureProvider.autoDispose<LibraryQuota>((ref) async {
  final selectedLib = ref.watch(selectedLibraryProvider).value;
  if (selectedLib == null) return const LibraryQuota(current: 0, max: 50);
  final repo = ref.watch(repositoryProvider);
  final count = await repo.getItemCount(selectedLib.id);
  return LibraryQuota(current: count, max: selectedLib.itemLimit);
});
