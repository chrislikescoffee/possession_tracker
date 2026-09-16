import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/image_cropper.dart';
import '../../core/widgets/image_picker_bottom_sheet.dart';
import '../../models/item_model.dart';
import '../../models/library_model.dart';
import '../../models/polygon_region.dart';
import '../../models/storage_location_model.dart';
import '../../state/item_state.dart';
import '../../state/library_state.dart';
import '../../state/repository_provider.dart';
import '../../state/storage_state.dart';
import '../items/add_edit_item_dialog.dart';
import '../items/quick_tag_item_dialog.dart';
import '../polygon_canvas/polygon_canvas_widget.dart';
import '../polygon_canvas/polygon_editor_sheet.dart';
import 'add_edit_location_dialog.dart';
import 'reparent_location_dialog.dart';

class StorageLocationDetailScreen extends ConsumerStatefulWidget {
  final String locationId;

  const StorageLocationDetailScreen({super.key, required this.locationId});

  @override
  ConsumerState<StorageLocationDetailScreen> createState() =>
      _StorageLocationDetailScreenState();
}

class _StorageLocationDetailScreenState
    extends ConsumerState<StorageLocationDetailScreen> {
  CanvasMode _canvasMode = CanvasMode.view;
  bool _isIdentifyingItems = false;
  bool _snappingEnabled = true;

  void _onRegionTapped(PolygonRegion region) {
    if (region.isLinkedToLocation) {
      context.go('/storage/${region.targetLocationId}');
    } else if (region.isLinkedToItem) {
      context.go('/items/${region.targetItemId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Region: ${region.label} (Not linked)')),
      );
    }
  }

  Future<void> _handlePolygonCompleted(
    List<NormalizedPoint> points,
    StorageLocation location,
    List<StorageLocation> childLocations,
    List<Item> items,
  ) async {
    final repo = ref.read(repositoryProvider);
    final selectedLib = ref.read(selectedLibraryProvider).value;

    // Optional cropped image preview
    String? croppedImageUrl;
    final effectiveImageUrl = location.imageUrl;
    if (effectiveImageUrl != null && effectiveImageUrl.isNotEmpty) {
      croppedImageUrl = await ImageCropperUtils.cropRegionFromImage(
        sourceImageUrl: effectiveImageUrl,
        points: points,
      );
    }
    if (!mounted) return;

    // Fetch all library items to partition into:
    // 1. Existing unlinked items in that storage area (listed first)
    // 2. Existing unlinked items that have no allocated location (listed second)
    final allLibraryItems = await repo.getItems(location.libraryId);
    final inAreaUnlinkedItems = items
        .where((it) =>
            !location.regions.any((r) => r.targetItemId == it.id) &&
            it.polygonPoints.isEmpty)
        .toList();
    final unallocatedUnlinkedItems = allLibraryItems
        .where((it) =>
            (it.storageLocationId == null || it.storageLocationId!.isEmpty) &&
            it.polygonPoints.isEmpty)
        .toList();
    final unlinkedItems = [
      ...inAreaUnlinkedItems,
      ...unallocatedUnlinkedItems,
    ];

    if (_isIdentifyingItems) {
      // 1. Multi-Item Tagging Mode
      if (selectedLib == null) return;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => QuickTagItemDialog(
          libraryId: selectedLib.id,
          storageLocationId: location.id,
          points: points,
          croppedImageUrl: croppedImageUrl,
          unlinkedItems: unlinkedItems,
        ),
      );

      if (result != null) {
        final isExisting = result['isExisting'] == true;
        String finalItemId;
        String finalItemName;

        if (isExisting) {
          final Item existingItem = result['item'] as Item;
          final updatedItem = existingItem.copyWith(
            storageLocationId: location.id,
            polygonPoints: points,
            primaryImageUrl: (existingItem.primaryImageUrl == null || existingItem.primaryImageUrl!.isEmpty) &&
                    croppedImageUrl != null
                ? croppedImageUrl
                : existingItem.primaryImageUrl,
            updatedAt: DateTime.now(),
          );
          await repo.saveItem(updatedItem);
          finalItemId = updatedItem.id;
          finalItemName = updatedItem.name;
        } else {
          final Item newItem = result['item'] as Item;
          await repo.saveItem(newItem);
          finalItemId = newItem.id;
          finalItemName = newItem.name;
        }

        final newRegion = PolygonRegion(
          id: const Uuid().v4(),
          label: finalItemName,
          points: points,
          targetItemId: finalItemId,
          colorHex: 0xFF10B981,
        );

        final updatedLocation = location.copyWith(
          regions: [...location.regions, newRegion],
        );
        await repo.saveStorageLocation(updatedLocation);

        setState(() {
          _canvasMode = CanvasMode.edit;
        });

        ref.invalidate(storageLocationDetailProvider(location.id));
        ref.invalidate(locationItemsProvider(location.id));
        ref.invalidate(libraryItemsProvider);
      } else {
        setState(() => _canvasMode = CanvasMode.edit);
      }
      return;
    }

    // 2. Standard Draw Mode: Sub-location or Item via PolygonEditorSheet
    setState(() => _canvasMode = CanvasMode.edit);

    // Filter unlinked entities for easy assignment
    final unlinkedLocations = childLocations
        .where((loc) => !location.regions.any((r) => r.targetLocationId == loc.id))
        .toList();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PolygonEditorSheet(
        points: points,
        unlinkedLocations: unlinkedLocations,
        unlinkedItems: unlinkedItems,
      ),
    );

    if (result != null) {
      final PolygonRegion newRegion = result['region'] as PolygonRegion;
      final String linkType = result['linkType'] as String;
      final bool useCropped = result['useCroppedAsDefault'] as bool? ?? true;
      final bool isAssigningExisting = result['isAssigningExisting'] as bool? ?? false;
      final String? existingId = (result['selectedExistingLocationId'] ??
          result['selectedExistingItemId'] ??
          result['existingId']) as String?;

      String? targetLocId;
      String? targetItemId;

      if (linkType == 'location') {
        final String? effectiveLocId = newRegion.targetLocationId ??
            (isAssigningExisting ? existingId : null) ??
            result['selectedExistingLocationId'] as String?;

        if (effectiveLocId != null && effectiveLocId.isNotEmpty) {
          // Assign to existing unlinked sub-location - NEVER create a duplicate location!
          targetLocId = effectiveLocId;
          if (useCropped && croppedImageUrl != null) {
            final existingIndex = childLocations.indexWhere((l) => l.id == effectiveLocId);
            if (existingIndex != -1) {
              final existing = childLocations[existingIndex];
              if (existing.imageUrl == null || existing.imageUrl!.isEmpty) {
                await repo.saveStorageLocation(existing.copyWith(imageUrl: croppedImageUrl));
              }
            }
          }
        } else {
          // Create new child location
          final childLoc = StorageLocation(
            id: const Uuid().v4(),
            libraryId: location.libraryId,
            parentId: location.id,
            name: newRegion.label,
            description: 'Sub-container in ${location.name}',
            imageUrl: useCropped ? croppedImageUrl : null,
            createdAt: DateTime.now(),
          );
          await repo.saveStorageLocation(childLoc);
          targetLocId = childLoc.id;
        }
      } else {
        final String? effectiveItemId = newRegion.targetItemId ??
            (isAssigningExisting ? existingId : null) ??
            result['selectedExistingItemId'] as String?;

        if (effectiveItemId != null && effectiveItemId.isNotEmpty) {
          // Assign to existing unlinked item - NEVER create a duplicate item!
          targetItemId = effectiveItemId;
          final existing = allLibraryItems.firstWhere(
            (i) => i.id == effectiveItemId,
            orElse: () => items.firstWhere((i) => i.id == effectiveItemId),
          );
          final updatedItem = existing.copyWith(
            storageLocationId: location.id,
            polygonPoints: points,
            primaryImageUrl: (existing.primaryImageUrl == null || existing.primaryImageUrl!.isEmpty) &&
                    useCropped
                ? croppedImageUrl
                : existing.primaryImageUrl,
            updatedAt: DateTime.now(),
          );
          await repo.saveItem(updatedItem);
        } else if (selectedLib != null) {
          // Create new item
          final childItem = Item(
            id: const Uuid().v4(),
            libraryId: location.libraryId,
            storageLocationId: location.id,
            name: newRegion.label,
            polygonPoints: points,
            primaryImageUrl: useCropped ? croppedImageUrl : null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await repo.saveItem(childItem);
          targetItemId = childItem.id;
        }
      }

      final updatedRegion = newRegion.copyWith(
        targetLocationId: targetLocId,
        targetItemId: targetItemId,
      );

      final updatedLocation = location.copyWith(
        regions: [...location.regions, updatedRegion],
      );

      await repo.saveStorageLocation(updatedLocation);
      setState(() => _canvasMode = CanvasMode.edit);
      ref.invalidate(storageLocationDetailProvider(location.id));
      ref.invalidate(storageLocationsProvider(location.id));
      ref.invalidate(locationItemsProvider(location.id));
      ref.invalidate(libraryItemsProvider);
    } else {
      setState(() => _canvasMode = CanvasMode.edit);
    }
  }

  Future<void> _handleDeleteRegion(
      PolygonRegion region, StorageLocation location) async {
    final repo = ref.read(repositoryProvider);

    if (region.isLinkedToLocation) {
      final subLocId = region.targetLocationId!;
      // Check if this sub-location contains items or child storage locations
      final childSubs = await repo.getStorageLocations(location.libraryId,
          parentId: subLocId);
      final childItems = await repo.getItems(location.libraryId,
          storageLocationId: subLocId);
      final isPopulated = childSubs.isNotEmpty || childItems.isNotEmpty;

      if (!mounted) return;

      if (isPopulated) {
        // Populated container prompt
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Remove Storage Mapping?',
                style: TextStyle(color: Colors.white)),
            content: const Text(
              'Mapping on this image will be removed however the storage area will not be deleted.',
              style: TextStyle(color: Color(0xFFCBD5E1)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B)),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes, Remove Mapping'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          final updatedRegions =
              location.regions.where((r) => r.id != region.id).toList();
          final updatedLocation = location.copyWith(regions: updatedRegions);
          await repo.saveStorageLocation(updatedLocation);
          ref.invalidate(storageLocationDetailProvider(location.id));
        }
      } else {
        // Empty container prompt
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Delete Storage?',
                style: TextStyle(color: Colors.white)),
            content: const Text(
              'This storage will be removed.',
              style: TextStyle(color: Color(0xFFCBD5E1)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444)),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Yes, Delete'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          final updatedRegions =
              location.regions.where((r) => r.id != region.id).toList();
          final updatedLocation = location.copyWith(regions: updatedRegions);
          await repo.saveStorageLocation(updatedLocation);
          await repo.deleteStorageLocation(subLocId);
          ref.invalidate(storageLocationDetailProvider(location.id));
          ref.invalidate(storageLocationsProvider(location.id));
          ref.invalidate(allStorageLocationsProvider);
        }
      }
    } else if (region.isLinkedToItem) {
      final itemId = region.targetItemId!;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Delete Item or Mapping?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Do you want to delete the image map or the item record?',
            style: TextStyle(color: Color(0xFFCBD5E1)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('image'),
              child: const Text('Delete Image Map'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444)),
              onPressed: () => Navigator.of(ctx).pop('item'),
              child: const Text('Delete Item Record'),
            ),
          ],
        ),
      );

      if (choice == 'image') {
        // Unlink polygon only
        final updatedRegions =
            location.regions.where((r) => r.id != region.id).toList();
        final updatedLocation = location.copyWith(regions: updatedRegions);
        await repo.saveStorageLocation(updatedLocation);

        final item = await repo.getItem(itemId);
        if (item != null) {
          await repo.saveItem(item.copyWith(polygonPoints: []));
        }
        ref.invalidate(storageLocationDetailProvider(location.id));
        ref.invalidate(locationItemsProvider(location.id));
        ref.invalidate(libraryItemsProvider);
      } else if (choice == 'item') {
        // Delete item record completely
        final updatedRegions =
            location.regions.where((r) => r.id != region.id).toList();
        final updatedLocation = location.copyWith(regions: updatedRegions);
        await repo.saveStorageLocation(updatedLocation);
        await repo.deleteItem(itemId);

        ref.invalidate(storageLocationDetailProvider(location.id));
        ref.invalidate(locationItemsProvider(location.id));
        ref.invalidate(libraryItemsProvider);
      }
    } else {
      // Unlinked polygon
      final updatedRegions =
          location.regions.where((r) => r.id != region.id).toList();
      final updatedLocation = location.copyWith(regions: updatedRegions);
      await repo.saveStorageLocation(updatedLocation);
      ref.invalidate(storageLocationDetailProvider(location.id));
    }
  }

  Future<void> _handleRenameRegion(
      PolygonRegion region, String newLabel, StorageLocation location) async {
    final repo = ref.read(repositoryProvider);
    final updatedRegions = location.regions.map((r) {
      if (r.id == region.id) {
        return r.copyWith(label: newLabel);
      }
      return r;
    }).toList();

    final updatedLocation = location.copyWith(regions: updatedRegions);
    await repo.saveStorageLocation(updatedLocation);

    if (region.isLinkedToLocation) {
      final targetLoc = await repo.getStorageLocation(region.targetLocationId!);
      if (targetLoc != null) {
        await repo.saveStorageLocation(targetLoc.copyWith(name: newLabel));
        ref.invalidate(storageLocationsProvider(location.id));
        ref.invalidate(allStorageLocationsProvider);
      }
    } else if (region.isLinkedToItem) {
      final targetItem = await repo.getItem(region.targetItemId!);
      if (targetItem != null) {
        await repo.saveItem(targetItem.copyWith(name: newLabel));
        ref.invalidate(locationItemsProvider(location.id));
        ref.invalidate(libraryItemsProvider);
      }
    }

    ref.invalidate(storageLocationDetailProvider(location.id));
  }

  Future<void> _handleRegionUpdated(
      PolygonRegion updatedRegion, StorageLocation location) async {
    final repo = ref.read(repositoryProvider);
    final updatedRegions = location.regions.map((r) {
      if (r.id == updatedRegion.id) {
        return updatedRegion;
      }
      return r;
    }).toList();

    final updatedLocation = location.copyWith(regions: updatedRegions);
    await repo.saveStorageLocation(updatedLocation);

    if (updatedRegion.isLinkedToItem) {
      final targetItem = await repo.getItem(updatedRegion.targetItemId!);
      if (targetItem != null) {
        await repo.saveItem(
            targetItem.copyWith(polygonPoints: updatedRegion.points));
        ref.invalidate(locationItemsProvider(location.id));
      }
    }

    ref.invalidate(storageLocationDetailProvider(location.id));
  }

  void _showEditAndMapSheet({
    required BuildContext context,
    required StorageLocation location,
    required Library? selectedLib,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: Color(0xFF334155), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF818CF8), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit & Map Storage',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          location.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Option 1: Draw Storage
              _buildDrawerActionTile(
                icon: Icons.crop_free,
                iconColor: const Color(0xFF6366F1),
                title: 'Draw Storage',
                subtitle: 'Map a shelf, cabinet, or compartment on this photo',
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _isIdentifyingItems = false;
                    _canvasMode = CanvasMode.edit;
                  });
                },
              ),
              const SizedBox(height: 8),

              // Option 2: Draw Items
              _buildDrawerActionTile(
                icon: Icons.tag,
                iconColor: const Color(0xFF10B981),
                title: 'Draw Items',
                subtitle:
                    'Quickly tag and outline multiple items on the photo',
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _isIdentifyingItems = true;
                    _canvasMode = CanvasMode.edit;
                  });
                },
              ),
              const SizedBox(height: 8),

              // Option 3: Replace Image
              _buildDrawerActionTile(
                icon: Icons.camera_alt_outlined,
                iconColor: const Color(0xFF38BDF8),
                title: location.imageUrl == null || location.imageUrl!.isEmpty
                    ? 'Take Location Photo'
                    : 'Replace / Retake Photo',
                subtitle: 'Capture with camera or pick from gallery',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picked = await ImagePickerBottomSheet.show(
                    context,
                    currentImageUrl: location.imageUrl,
                  );
                  if (picked != null) {
                    final repo = ref.read(repositoryProvider);
                    final updated = location.copyWith(imageUrl: picked);
                    await repo.saveStorageLocation(updated);
                    ref.invalidate(storageLocationDetailProvider(location.id));
                  }
                },
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 12),

              // Option 4: Edit Details
              _buildDrawerActionTile(
                icon: Icons.edit_outlined,
                iconColor: const Color(0xFF94A3B8),
                title: 'Edit Details',
                subtitle: 'Rename container or change description',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final edited = await showDialog<StorageLocation>(
                    context: context,
                    builder: (dCtx) => AddEditLocationDialog(
                      libraryId: location.libraryId,
                      locationToEdit: location,
                    ),
                  );
                  if (edited != null) {
                    final repo = ref.read(repositoryProvider);
                    await repo.saveStorageLocation(edited);
                    ref.invalidate(storageLocationDetailProvider(location.id));
                    ref.invalidate(storageLocationsProvider(null));
                    ref.invalidate(allStorageLocationsProvider);
                  }
                },
              ),
              const SizedBox(height: 8),

              // Option 5: Add Level Above
              _buildDrawerActionTile(
                icon: Icons.drive_folder_upload_outlined,
                iconColor: const Color(0xFF38BDF8),
                title: 'Add Level Above...',
                subtitle: 'Insert a parent container above this location',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final allLocs = ref.read(allStorageLocationsProvider).value ?? [];
                  final reparented = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => ReparentLocationDialog(
                      currentLocation: location,
                      allLocations: allLocs,
                    ),
                  );
                  if (reparented == true) {
                    ref.invalidate(storageLocationDetailProvider(location.id));
                    ref.invalidate(storageLocationsProvider(null));
                    ref.invalidate(allStorageLocationsProvider);
                    ref.invalidate(locationBreadcrumbsProvider(location.id));
                  }
                },
              ),
              const SizedBox(height: 8),

              // Option 6: Delete Location
              _buildDrawerActionTile(
                icon: Icons.delete_outline,
                iconColor: const Color(0xFFEF4444),
                title: 'Delete Location',
                subtitle: 'Permanently remove this area and all contents',
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      title: const Text('Delete Location?'),
                      content: Text(
                        'Are you sure you want to delete "${location.name}" and all child sub-containers?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dCtx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                          onPressed: () => Navigator.of(dCtx).pop(true),
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
                    if (context.mounted) {
                      context.go('/storage');
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedSlidingPanel({
    required StorageLocation location,
    required List<StorageLocation> childLocations,
    required List<Item> items,
    required Library? selectedLib,
  }) {
    return DraggableScrollableSheet(
      initialChildSize: 0.08,
      minChildSize: 0.08,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.08, 0.45, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: const Border(
              top: BorderSide(color: Color(0xFF334155), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Drag Handle Bar
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Header bar when collapsed / preview
              Row(
                children: [
                  const Icon(Icons.layers_outlined,
                      color: Color(0xFF818CF8), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Storage (${childLocations.length})  •  Items (${items.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.unfold_more,
                      size: 18, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF1E293B), height: 1),

              // Section 1: Storage (Collapsed by default)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_open,
                      size: 20, color: Color(0xFF06B6D4)),
                  title: Text(
                    'Storage (${childLocations.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF38BDF8),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Storage',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final newSub = await showDialog<StorageLocation>(
                            context: context,
                            builder: (ctx) => AddEditLocationDialog(
                              libraryId: location.libraryId,
                              parentId: location.id,
                            ),
                          );
                          if (newSub != null) {
                            final repo = ref.read(repositoryProvider);
                            await repo.saveStorageLocation(newSub);
                            ref.invalidate(
                                storageLocationsProvider(location.id));
                            ref.invalidate(allStorageLocationsProvider);
                          }
                        },
                      ),
                      const Icon(Icons.expand_more, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  children: [
                    if (childLocations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No nested storage areas yet. Tap + Add Storage or Edit / Map to add.',
                          style:
                              TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: childLocations.map((sub) {
                            final isMapped = location.regions
                                .any((r) => r.targetLocationId == sub.id);
                            return ActionChip(
                              backgroundColor: const Color(0xFF1E293B),
                              side: BorderSide(
                                color: isMapped
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.5),
                              ),
                              avatar: Icon(
                                isMapped
                                    ? Icons.folder_outlined
                                    : Icons.folder_open_outlined,
                                size: 16,
                                color: isMapped
                                    ? const Color(0xFF06B6D4)
                                    : const Color(0xFFF59E0B),
                              ),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(sub.name,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                  if (!isMapped) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Unmapped',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              onPressed: () =>
                                  context.go('/storage/${sub.id}'),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF1E293B), height: 1),

              // Section 2: Items stored here (Collapsed by default)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined,
                      size: 20, color: Color(0xFF10B981)),
                  title: Text(
                    'Items stored here (${items.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF10B981),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Item',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          if (selectedLib == null) return;
                          final newItem = await showDialog<Item>(
                            context: context,
                            builder: (ctx) => AddEditItemDialog(
                              libraryId: selectedLib.id,
                              initialLocationId: location.id,
                            ),
                          );
                          if (newItem != null) {
                            final repo = ref.read(repositoryProvider);
                            await repo.saveItem(newItem);
                            ref.invalidate(
                                locationItemsProvider(location.id));
                            ref.invalidate(libraryItemsProvider);
                          }
                        },
                      ),
                      const Icon(Icons.expand_more, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  children: [
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No items stored directly in this container.',
                          style:
                              TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final it = items[index];
                          final isMapped = location.regions
                                  .any((r) => r.targetItemId == it.id) ||
                              it.polygonPoints.isNotEmpty;

                          return ListTile(
                            dense: true,
                            tileColor: const Color(0xFF182238),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(
                                  color: Color(0xFF263352)),
                            ),
                            leading: const Icon(Icons.inventory_2,
                                color: Color(0xFF818CF8), size: 18),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    it.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ),
                                if (!isMapped)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.2),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Unmapped',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: it.description != null
                                ? Text(
                                    it.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  )
                                : null,
                            trailing: const Icon(Icons.chevron_right,
                                size: 16, color: Color(0xFF64748B)),
                            onTap: () => context.go('/items/${it.id}'),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopInspectorPanel({
    required StorageLocation location,
    required List<StorageLocation> childLocations,
    required List<Item> items,
    required Library? selectedLib,
  }) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF131B2E),
              border: Border(
                bottom: BorderSide(color: Color(0xFF263352), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.dashboard_customize_outlined,
                          size: 20, color: Color(0xFF818CF8)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            location.description?.isNotEmpty == true
                                ? location.description!
                                : 'Storage Inspector Workspace',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Metric badges
                Row(
                  children: [
                    _buildMetricChip(
                      icon: Icons.folder_open,
                      count: childLocations.length,
                      label: 'Areas',
                      color: const Color(0xFF06B6D4),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricChip(
                      icon: Icons.inventory_2_outlined,
                      count: items.length,
                      label: 'Items',
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricChip(
                      icon: Icons.polyline_outlined,
                      count: location.regions.length,
                      label: 'Polygons',
                      color: const Color(0xFF818CF8),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: const Color(0xFF111827),
            child: const TabBar(
              indicatorColor: Color(0xFF6366F1),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFF94A3B8),
              labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Areas'),
                Tab(text: 'Items'),
                Tab(text: 'Polygons'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              children: [
                _buildDesktopAreasTab(
                  location: location,
                  childLocations: childLocations,
                ),
                _buildDesktopItemsTab(
                  location: location,
                  items: items,
                  selectedLib: selectedLib,
                ),
                _buildDesktopRegionsTab(
                  location: location,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopAreasTab({
    required StorageLocation location,
    required List<StorageLocation> childLocations,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Storage Areas (${childLocations.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE2E8F0),
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF38BDF8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Area', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  final newSub = await showDialog<StorageLocation>(
                    context: context,
                    builder: (ctx) => AddEditLocationDialog(
                      libraryId: location.libraryId,
                      parentId: location.id,
                    ),
                  );
                  if (newSub != null) {
                    final repo = ref.read(repositoryProvider);
                    await repo.saveStorageLocation(newSub);
                    ref.invalidate(storageLocationsProvider(location.id));
                    ref.invalidate(allStorageLocationsProvider);
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1E293B), height: 1),
        Expanded(
          child: childLocations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_open, size: 40, color: Color(0xFF334155)),
                        const SizedBox(height: 8),
                        const Text(
                          'No sub-areas yet',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Click "+ Add Area" to create a nested storage space.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: childLocations.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Color(0xFF1E293B), height: 1),
                  itemBuilder: (context, idx) {
                    final sub = childLocations[idx];
                    final isMapped = location.regions
                        .any((r) => r.targetLocationId == sub.id);
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isMapped
                              ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isMapped ? Icons.folder_outlined : Icons.folder_open_outlined,
                          size: 18,
                          color: isMapped
                              ? const Color(0xFF06B6D4)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      title: Text(
                        sub.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: sub.description != null && sub.description!.isNotEmpty
                          ? Text(
                              sub.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8)),
                            )
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMapped
                              ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isMapped ? 'Mapped' : 'Unmapped',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isMapped
                                ? const Color(0xFF06B6D4)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      onTap: () => context.go('/storage/${sub.id}'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopItemsTab({
    required StorageLocation location,
    required List<Item> items,
    required Library? selectedLib,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items Stored Here (${items.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE2E8F0),
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  if (selectedLib == null) return;
                  final newItem = await showDialog<Item>(
                    context: context,
                    builder: (ctx) => AddEditItemDialog(
                      libraryId: selectedLib.id,
                      initialLocationId: location.id,
                    ),
                  );
                  if (newItem != null) {
                    final repo = ref.read(repositoryProvider);
                    await repo.saveItem(newItem);
                    ref.invalidate(locationItemsProvider(location.id));
                    ref.invalidate(libraryItemsProvider);
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1E293B), height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 40, color: Color(0xFF334155)),
                        const SizedBox(height: 8),
                        const Text(
                          'No items here yet',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Click "+ Add Item" or draw an item to tag possessions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Color(0xFF1E293B), height: 1),
                  itemBuilder: (context, idx) {
                    final it = items[idx];
                    final isMapped = location.regions
                        .any((r) => r.targetItemId == it.id);
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      title: Text(
                        it.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: it.description != null && it.description!.isNotEmpty
                          ? Text(
                              it.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8)),
                            )
                          : null,
                      trailing: !isMapped
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Unmapped',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            )
                          : null,
                      onTap: () => context.go('/items/${it.id}'),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopRegionsTab({
    required StorageLocation location,
  }) {
    final isEditing = _canvasMode != CanvasMode.view;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Polygons (${location.regions.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE2E8F0),
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isEditing
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF6366F1).withValues(alpha: 0.15),
                  foregroundColor: isEditing
                      ? const Color(0xFF10B981)
                      : const Color(0xFF818CF8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: Icon(
                  isEditing ? Icons.check : Icons.mode_edit_outline,
                  size: 14,
                ),
                label: Text(
                  isEditing ? 'Done Editing' : 'Edit Polygons',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  setState(() {
                    if (isEditing) {
                      _canvasMode = CanvasMode.view;
                      _isIdentifyingItems = false;
                    } else {
                      _canvasMode = CanvasMode.edit;
                    }
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1E293B), height: 1),
        Expanded(
          child: location.regions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.polyline_outlined,
                            size: 40, color: Color(0xFF334155)),
                        const SizedBox(height: 8),
                        const Text(
                          'No polygons mapped',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Click "Edit" in the top bar to draw storage areas or items on the image.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: location.regions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Color(0xFF1E293B), height: 1),
                  itemBuilder: (context, idx) {
                    final reg = location.regions[idx];
                    final isLocation = reg.isLinkedToLocation;
                    final isItem = reg.isLinkedToItem;

                    final iconData = isLocation
                        ? Icons.folder_outlined
                        : (isItem
                            ? Icons.inventory_2_outlined
                            : Icons.polyline_outlined);
                    final iconColor = isLocation
                        ? const Color(0xFF06B6D4)
                        : (isItem
                            ? const Color(0xFF10B981)
                            : const Color(0xFF818CF8));

                    final typeLabel = isLocation
                        ? 'Storage Area'
                        : (isItem ? 'Item' : 'Unlinked Polygon');

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(iconData, size: 18, color: iconColor),
                      ),
                      title: Text(
                        reg.label.isNotEmpty ? reg.label : 'Polygon #${idx + 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        typeLabel,
                        style: TextStyle(fontSize: 11, color: iconColor),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.drive_file_rename_outline,
                                size: 16, color: Color(0xFF94A3B8)),
                            tooltip: 'Rename',
                            onPressed: () async {
                              final controller =
                                  TextEditingController(text: reg.label);
                              final newLabel = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: const Text('Rename Region',
                                      style: TextStyle(color: Colors.white)),
                                  content: TextField(
                                    controller: controller,
                                    autofocus: true,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      labelText: 'Label',
                                      labelStyle:
                                          TextStyle(color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, controller.text.trim()),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                              if (newLabel != null && newLabel.isNotEmpty) {
                                await _handleRenameRegion(reg, newLabel, location);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: Color(0xFFEF4444)),
                            tooltip: 'Delete Region',
                            onPressed: () => _handleDeleteRegion(reg, location),
                          ),
                        ],
                      ),
                      onTap: () => _onRegionTapped(reg),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync =
        ref.watch(storageLocationDetailProvider(widget.locationId));
    final breadcrumbsAsync =
        ref.watch(locationBreadcrumbsProvider(widget.locationId));
    final childLocationsAsync =
        ref.watch(storageLocationsProvider(widget.locationId));
    final itemsAsync = ref.watch(locationItemsProvider(widget.locationId));
    final selectedLib = ref.watch(selectedLibraryProvider).value;

    return locationAsync.when(
      data: (location) {
        if (location == null) {
          return const Scaffold(
              body: Center(child: Text('Location not found')));
        }

        final childLocations = childLocationsAsync.value ?? [];
        final items = itemsAsync.value ?? [];

        // Sub-Area Viewport Framing inheritance:
        String? displayImageUrl = location.imageUrl;
        List<NormalizedPoint>? focusPolygon;

        if ((displayImageUrl == null || displayImageUrl.isEmpty) &&
            location.parentId != null) {
          final parentLocation =
              ref.watch(storageLocationDetailProvider(location.parentId!)).value;
          if (parentLocation != null &&
              parentLocation.imageUrl != null &&
              parentLocation.imageUrl!.isNotEmpty) {
            for (final r in parentLocation.regions) {
              if (r.targetLocationId == location.id) {
                displayImageUrl = parentLocation.imageUrl;
                focusPolygon = r.points;
                break;
              }
            }
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(location.name),
            actions: [
              // Prominent "Edit" button activating the management panel
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text(
                    'Edit',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showEditAndMapSheet(
                    context: context,
                    location: location,
                    selectedLib: selectedLib,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Breadcrumb Hierarchy Bar
              breadcrumbsAsync.when(
                data: (crumbs) {
                  if (crumbs.isEmpty) return const SizedBox();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    color: const Color(0xFF131B2E),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => context.go('/storage'),
                            child: const Icon(Icons.home,
                                size: 18, color: Color(0xFF818CF8)),
                          ),
                          for (int i = 0; i < crumbs.length; i++) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.chevron_right,
                                  size: 16, color: Color(0xFF64748B)),
                            ),
                            InkWell(
                              onTap: () =>
                                  context.go('/storage/${crumbs[i].id}'),
                              child: Text(
                                crumbs[i].name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: i == crumbs.length - 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: i == crumbs.length - 1
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (error, stackTrace) => const SizedBox(),
              ),

              // 2. Responsive Canvas (Desktop Dual-Pane Workspace vs Mobile Pinned Sliding Panel)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 850;

                    final canvasWidget = PolygonCanvasWidget(
                      imageUrl: displayImageUrl,
                      regions: location.regions,
                      mode: _canvasMode,
                      focusPolygon: focusPolygon,
                      initialSnappingEnabled: _snappingEnabled,
                      newPolygonLabel: _isIdentifyingItems ? 'Draw Item' : 'Draw Storage',
                      onSnappingChanged: (val) {
                        setState(() => _snappingEnabled = val);
                      },
                      onRegionTapped: _onRegionTapped,
                      onPolygonCompleted: (pts) => _handlePolygonCompleted(
                        pts,
                        location,
                        childLocations,
                        items,
                      ),
                      onCancelDrawing: () {},
                      onDeleteRegion: (reg) =>
                          _handleDeleteRegion(reg, location),
                      onRenameRegion: (reg, newLabel) =>
                          _handleRenameRegion(reg, newLabel, location),
                      onRegionUpdated: (reg) =>
                          _handleRegionUpdated(reg, location),
                      onSaveEditSession: () {
                        setState(() {
                          _canvasMode = CanvasMode.view;
                          _isIdentifyingItems = false;
                        });
                      },
                    );

                    if (isDesktop) {
                      // Desktop Layout: Side-by-side Dual Pane
                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              color: const Color(0xFF0B0F19),
                              child: canvasWidget,
                            ),
                          ),
                          Container(
                            width: 380,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F172A),
                              border: Border(
                                left: BorderSide(color: Color(0xFF263352), width: 1.5),
                              ),
                            ),
                            child: _buildDesktopInspectorPanel(
                              location: location,
                              childLocations: childLocations,
                              items: items,
                              selectedLib: selectedLib,
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile Layout (< 850px): Canvas with Pinned Sliding Bottom Sheet
                    return Stack(
                      children: [
                        Positioned.fill(
                          bottom: _canvasMode == CanvasMode.view ? 56.0 : 0.0,
                          child: Container(
                            color: const Color(0xFF0B0F19),
                            child: canvasWidget,
                          ),
                        ),
                        if (_canvasMode == CanvasMode.view)
                          _buildPinnedSlidingPanel(
                            location: location,
                            childLocations: childLocations,
                            items: items,
                            selectedLib: selectedLib,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
