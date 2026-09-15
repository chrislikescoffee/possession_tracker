import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_type_model.dart';
import 'library_state.dart';
import 'repository_provider.dart';

/// Provider for all available Item Types for a specific library
final itemTypesForLibraryProvider =
    FutureProvider.family<List<ItemType>, String>((ref, libraryId) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getItemTypes(libraryId);
});

/// Provider for all available Item Types in the currently selected library
final itemTypesProvider = FutureProvider<List<ItemType>>((ref) async {
  final library = ref.watch(selectedLibraryProvider).value;
  if (library == null) return [];
  final repo = ref.watch(repositoryProvider);
  return repo.getItemTypes(library.id);
});

/// Provider for a specific ItemType by id
final itemTypeDetailProvider =
    FutureProvider.family<ItemType?, String>((ref, itemTypeId) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getItemType(itemTypeId);
});
