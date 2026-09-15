import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    if (list.isNotEmpty) {
      return list.first;
    }
    return repo.createLibrary('My Primary Library');
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
