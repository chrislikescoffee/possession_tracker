import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/local_inventory_repository.dart';

/// Provider for the active inventory repository (offline-first persistent storage)
final repositoryProvider = Provider<InventoryRepository>((ref) {
  return LocalInventoryRepository();
});
