import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_list_model.dart';
import 'library_state.dart';
import 'repository_provider.dart';

/// All item lists in the currently selected library
final itemListsProvider = FutureProvider<List<ItemList>>((ref) async {
  final library = ref.watch(selectedLibraryProvider).value;
  if (library == null) return [];
  final repo = ref.watch(repositoryProvider);
  return repo.getItemLists(library.id);
});

/// Single item list detail provider by ID
final itemListDetailProvider =
    FutureProvider.family<ItemList?, String>((ref, listId) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getItemList(listId);
});
