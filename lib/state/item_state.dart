import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_model.dart';
import '../models/lending_record_model.dart';
import 'library_state.dart';
import 'repository_provider.dart';

/// Filter query for items list
class ItemSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
}

final itemSearchQueryProvider =
    NotifierProvider<ItemSearchQueryNotifier, String>(ItemSearchQueryNotifier.new);

/// All items in the selected library, optionally filtered by search
final libraryItemsProvider = FutureProvider<List<Item>>((ref) async {
  final library = ref.watch(selectedLibraryProvider).value;
  if (library == null) return [];
  final repo = ref.watch(repositoryProvider);
  final query = ref.watch(itemSearchQueryProvider);
  return repo.getItems(library.id, searchQuery: query);
});

/// Items located directly in a specific storage location
final locationItemsProvider =
    FutureProvider.family<List<Item>, String>((ref, locationId) async {
  final library = ref.watch(selectedLibraryProvider).value;
  if (library == null) return [];
  final repo = ref.watch(repositoryProvider);
  return repo.getItems(library.id, storageLocationId: locationId);
});

/// Single item detail provider
final itemDetailProvider = FutureProvider.family<Item?, String>((ref, itemId) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getItem(itemId);
});

/// Lending history records provider
final lendingRecordsProvider = FutureProvider<List<LendingRecord>>((ref) async {
  final library = ref.watch(selectedLibraryProvider).value;
  if (library == null) return [];
  final repo = ref.watch(repositoryProvider);
  return repo.getLendingRecords(library.id);
});
