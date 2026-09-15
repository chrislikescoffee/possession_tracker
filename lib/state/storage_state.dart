import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/storage_location_model.dart';
import 'library_state.dart';
import 'repository_provider.dart';

/// Provider for storage locations under a given parent (null = root locations)
final storageLocationsProvider =
    FutureProvider.family<List<StorageLocation>, String?>((ref, parentId) async {
  final library = ref.watch(selectedLibraryProvider).value;
  if (library == null) return [];
  final repo = ref.watch(repositoryProvider);
  return repo.getStorageLocations(library.id, parentId: parentId);
});

/// Provider for all storage locations in the selected library
final allStorageLocationsProvider =
    FutureProvider<List<StorageLocation>>((ref) async {
  final library = ref.watch(selectedLibraryProvider).value;
  if (library == null) return [];
  final repo = ref.watch(repositoryProvider);
  return repo.getAllStorageLocations(library.id);
});

/// Provider for a specific storage location's details
final storageLocationDetailProvider =
    FutureProvider.family<StorageLocation?, String>((ref, locationId) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getStorageLocation(locationId);
});

/// Provider for breadcrumb trail of storage locations from root down to current location
final locationBreadcrumbsProvider =
    FutureProvider.family<List<StorageLocation>, String>((ref, locationId) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getLocationBreadcrumbs(locationId);
});
