import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_image_view.dart';
import '../../models/storage_location_model.dart';
import '../../state/library_state.dart';
import '../../state/repository_provider.dart';
import '../../state/storage_state.dart';
import 'add_edit_location_dialog.dart';

class StorageTreeScreen extends ConsumerWidget {
  const StorageTreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLib = ref.watch(selectedLibraryProvider).value;
    final locationsAsync = ref.watch(storageLocationsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Storage Hierarchy'),
            if (selectedLib != null)
              Text(
                selectedLib.name,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(storageLocationsProvider(null));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Root Location'),
        onPressed: () async {
          if (selectedLib == null) return;
          final newLoc = await showDialog<StorageLocation>(
            context: context,
            builder: (ctx) => AddEditLocationDialog(libraryId: selectedLib.id),
          );
          if (newLoc != null) {
            final repo = ref.read(repositoryProvider);
            await repo.saveStorageLocation(newLoc);
            ref.invalidate(storageLocationsProvider(null));
          }
        },
      ),
      body: locationsAsync.when(
        data: (locations) {
          if (locations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.folder_open, size: 48, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No storage locations yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first storage area (e.g. Workshop, Living Room, Attic)',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(storageLocationsProvider(null)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: locations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final loc = locations[index];
                return _StorageLocationCard(location: loc);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _StorageLocationCard extends ConsumerWidget {
  final StorageLocation location;

  const _StorageLocationCard({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = location.imageUrl != null && location.imageUrl!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.go('/storage/${location.id}');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image with gradient overlay
            if (hasImage)
              SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImageView(
                      imageUrl: location.imageUrl,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC0B0F19)],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          if (location.regions.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.crop_square, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${location.regions.length} Polygons Mapped',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.folder_outlined, color: Color(0xFF818CF8), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            if (location.description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                location.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                        onSelected: (val) async {
                          if (val == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: const Text('Delete Location?'),
                                content: Text(
                                  'Are you sure you want to delete "${location.name}" and all child sub-containers?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                    ),
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final repo = ref.read(repositoryProvider);
                              await repo.deleteStorageLocation(location.id);
                              ref.invalidate(storageLocationsProvider(null));
                              ref.invalidate(storageLocationsProvider(location.parentId));
                              ref.invalidate(allStorageLocationsProvider);
                              ref.invalidate(storageLocationDetailProvider(location.id));
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                SizedBox(width: 8),
                                Text('Delete Location', style: TextStyle(color: Color(0xFFEF4444))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
