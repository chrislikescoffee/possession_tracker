import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/utils/field_query_utils.dart';
import '../../core/widgets/app_image_view.dart';
import '../../core/widgets/barcode_scanner_dialog.dart';
import '../../core/widgets/image_picker_bottom_sheet.dart';
import '../../models/item_model.dart';
import '../../state/item_state.dart';
import '../../state/repository_provider.dart';
import '../../state/storage_state.dart';
import '../lending/lend_item_sheet.dart';
import 'add_edit_item_dialog.dart';
import 'relocation_dialog.dart';

class ItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemDetailProvider(itemId));
    final lendingRecordsAsync = ref.watch(lendingRecordsProvider);

    return itemAsync.when(
      data: (item) {
        if (item == null) {
          return const Scaffold(body: Center(child: Text('Item not found')));
        }

        final breadcrumbsAsync = item.storageLocationId != null
            ? ref.watch(locationBreadcrumbsProvider(item.storageLocationId!))
            : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(item.name),
            actions: [
              IconButton(
                tooltip: 'Locate Visually',
                icon: const Icon(Icons.my_location, color: Color(0xFF06B6D4)),
                onPressed: () => context.go('/locator?itemId=${item.id}'),
              ),
              PopupMenuButton<String>(
                onSelected: (val) async {
                  final repo = ref.read(repositoryProvider);
                  if (val == 'edit') {
                    final edited = await showDialog<Item>(
                      context: context,
                      builder: (ctx) => AddEditItemDialog(
                        libraryId: item.libraryId,
                        itemToEdit: item,
                      ),
                    );
                    if (edited != null) {
                      await repo.saveItem(edited);
                      ref.invalidate(itemDetailProvider(item.id));
                      ref.invalidate(libraryItemsProvider);
                    }
                  } else if (val == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Item?'),
                        content: Text('Are you sure you want to delete "${item.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await repo.deleteItem(item.id);
                      ref.invalidate(libraryItemsProvider);
                      if (context.mounted) {
                        context.go('/items');
                      }
                    }
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit Item')),
                  PopupMenuItem(value: 'delete', child: Text('Delete Item')),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Photo Card with Camera Snap Action
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    AppImageView(
                      imageUrl: item.primaryImageUrl,
                      height: 220,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(16),
                      fallbackWidget: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF263352)),
                        ),
                        child: const Center(
                          child: Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: FloatingActionButton.small(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        tooltip: 'Take / Update Photo',
                        child: const Icon(Icons.camera_alt, size: 18),
                        onPressed: () async {
                          final picked = await ImagePickerBottomSheet.show(
                            context,
                            currentImageUrl: item.primaryImageUrl,
                          );
                          if (picked != null) {
                            final repo = ref.read(repositoryProvider);
                            final updated = item.copyWith(primaryImageUrl: picked);
                            await repo.saveItem(updated);
                            ref.invalidate(itemDetailProvider(item.id));
                            ref.invalidate(libraryItemsProvider);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name and Description
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description!,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  ),
                ],
                if (item.mustScanIn) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 14, color: Color(0xFF10B981)),
                        SizedBox(width: 6),
                        Text(
                          'Must scan in to return',
                          style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.tags.map((tag) => Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.label_outline, size: 14),
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                    )).toList(),
                  ),
                ],

                const SizedBox(height: 16),

                // 2. Canonical Storage Location Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, color: Color(0xFF06B6D4), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Canonical Storage Location',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06B6D4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.my_location, size: 16),
                              label: const Text('Locate on Map', style: TextStyle(fontSize: 13)),
                              onPressed: () => context.go('/locator?itemId=${item.id}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (breadcrumbsAsync != null)
                          breadcrumbsAsync.when(
                            data: (crumbs) {
                              if (crumbs.isEmpty) {
                                return const Text('No location assigned');
                              }
                              return Wrap(
                                spacing: 4,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  for (int i = 0; i < crumbs.length; i++) ...[
                                    if (i > 0)
                                      const Icon(Icons.chevron_right,
                                          size: 14, color: Color(0xFF64748B)),
                                    ActionChip(
                                      label: Text(crumbs[i].name, style: const TextStyle(fontSize: 12)),
                                      onPressed: () => context.go('/storage/${crumbs[i].id}'),
                                    ),
                                  ],
                                ],
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const Text('Error loading location path'),
                          )
                        else
                          const Text('Not assigned to a storage container'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Relocation Status Card (Temporary vs Permanent)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              item.isTemporarilyRelocated ? Icons.alt_route : Icons.check_circle_outline,
                              color: item.isTemporarilyRelocated ? Colors.amber : const Color(0xFF10B981),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.isTemporarilyRelocated
                                  ? 'Temporarily Relocated'
                                  : 'Stored in Primary Location',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: item.isTemporarilyRelocated ? Colors.amber : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (item.isTemporarilyRelocated) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Current Note: "${item.temporaryLocationNote ?? "Away from storage"}"',
                                    style: const TextStyle(fontSize: 13, color: Colors.amber),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                                icon: const Icon(Icons.home, size: 18),
                                label: const Text('Return to Home Location'),
                                onPressed: () async {
                                  String? scanned;
                                  if (item.mustScanIn) {
                                    scanned = await BarcodeScannerDialog.show(
                                      context,
                                      title: 'Scan Barcode to Return "${item.name}"',
                                    );
                                    if (scanned == null) return;
                                  }
                                  try {
                                    final repo = ref.read(repositoryProvider);
                                    await repo.returnItemToPermanentLocation(item.id, scannedBarcode: scanned);
                                    ref.invalidate(itemDetailProvider(item.id));
                                    ref.invalidate(libraryItemsProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${item.name} returned to home location.')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                child: const Text('Edit Note'),
                                onPressed: () async {
                                  final res = await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (ctx) => RelocationDialog(item: item),
                                  );
                                  if (res != null) {
                                    final repo = ref.read(repositoryProvider);
                                    if (res['isTemporary'] == true) {
                                      await repo.temporarilyRelocateItem(item.id, res['note']);
                                    } else {
                                      final oldLocationId = item.storageLocationId;
                                      final newLocationId = res['newLocationId'] as String;
                                      await repo.permanentlyRelocateItem(item.id, newLocationId);
                                      if (oldLocationId != null) {
                                        ref.invalidate(storageLocationDetailProvider(oldLocationId));
                                        ref.invalidate(locationItemsProvider(oldLocationId));
                                      }
                                      ref.invalidate(storageLocationDetailProvider(newLocationId));
                                      ref.invalidate(locationItemsProvider(newLocationId));
                                    }
                                    ref.invalidate(itemDetailProvider(item.id));
                                    ref.invalidate(libraryItemsProvider);
                                  }
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Item is currently sitting in its recorded primary storage container.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.alt_route, size: 18),
                            label: const Text('Relocate Item (Temp or Perm)'),
                            onPressed: () async {
                              final res = await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (ctx) => RelocationDialog(item: item),
                              );
                              if (res != null) {
                                final repo = ref.read(repositoryProvider);
                                if (res['isTemporary'] == true) {
                                  await repo.temporarilyRelocateItem(item.id, res['note']);
                                } else {
                                  final oldLocationId = item.storageLocationId;
                                  final newLocationId = res['newLocationId'] as String;
                                  await repo.permanentlyRelocateItem(item.id, newLocationId);
                                  if (oldLocationId != null) {
                                    ref.invalidate(storageLocationDetailProvider(oldLocationId));
                                    ref.invalidate(locationItemsProvider(oldLocationId));
                                  }
                                  ref.invalidate(storageLocationDetailProvider(newLocationId));
                                  ref.invalidate(locationItemsProvider(newLocationId));
                                }
                                ref.invalidate(itemDetailProvider(item.id));
                                ref.invalidate(libraryItemsProvider);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Lending & Custody Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.handshake_outlined, color: Colors.purpleAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              item.isLentOut ? 'Item is Lent Out' : 'Lending Custody',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (item.isLentOut) ...[
                          lendingRecordsAsync.when(
                            data: (records) {
                              final activeRecord = records.firstWhere(
                                (r) => r.itemId == item.id && r.isActive,
                                orElse: () => records.first,
                              );
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Borrower: ${activeRecord.borrowerName}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (activeRecord.borrowerContact != null)
                                    Text('Contact: ${activeRecord.borrowerContact!}'),
                                  Text('Lent on: ${DateFormat.yMMMd().format(activeRecord.lentAt)}'),
                                  if (activeRecord.expectedReturnAt != null)
                                    Text(
                                      'Expected return: ${DateFormat.yMMMd().format(activeRecord.expectedReturnAt!)}',
                                      style: const TextStyle(color: Colors.amber),
                                    ),
                                  if (activeRecord.notes != null)
                                    Text('Notes: ${activeRecord.notes!}'),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purpleAccent.shade700,
                                    ),
                                    icon: const Icon(Icons.assignment_turned_in, size: 18),
                                    label: const Text('Mark as Returned'),
                                    onPressed: () async {
                                      String? scanned;
                                      if (item.mustScanIn) {
                                        scanned = await BarcodeScannerDialog.show(
                                          context,
                                          title: 'Scan Barcode to Return "${item.name}"',
                                        );
                                        if (scanned == null) return;
                                      }
                                      try {
                                        final repo = ref.read(repositoryProvider);
                                        await repo.returnLentItem(activeRecord.id, scannedBarcode: scanned);
                                        ref.invalidate(itemDetailProvider(item.id));
                                        ref.invalidate(libraryItemsProvider);
                                        ref.invalidate(lendingRecordsProvider);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('${item.name} returned from lending.')),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                              backgroundColor: Theme.of(context).colorScheme.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const Text('Error loading loan info'),
                          ),
                        ] else ...[
                          const Text(
                            'Item is in your custody. You can lend it to friends or colleagues and track its return.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.person_add_outlined, size: 18),
                            label: const Text('Lend Item Out'),
                            onPressed: () async {
                              final res = await showModalBottomSheet<Map<String, dynamic>>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => LendItemSheet(item: item),
                              );
                              if (res != null) {
                                final repo = ref.read(repositoryProvider);
                                await repo.lendItem(
                                  itemId: item.id,
                                  libraryId: item.libraryId,
                                  borrowerName: res['borrowerName'],
                                  borrowerContact: res['borrowerContact'],
                                  expectedReturnAt: res['expectedReturnAt'],
                                  notes: res['notes'],
                                );
                                ref.invalidate(itemDetailProvider(item.id));
                                ref.invalidate(libraryItemsProvider);
                                ref.invalidate(lendingRecordsProvider);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 5. Dynamic Custom Attributes Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, color: Color(0xFF6366F1), size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Dynamic Attributes',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (item.customFields.isEmpty)
                          const Text(
                            'No custom fields added yet. Edit the item to add attributes like Brand, Size, Serial No, or Color.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          )
                        else
                          Table(
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: const Color(0xFF263352).withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            columnWidths: const {
                              0: FlexColumnWidth(2),
                              1: FlexColumnWidth(3),
                            },
                            children: item.customFields.entries.map((entry) {
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E293B),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF334155)),
                                        ),
                                        child: Text(
                                          FieldQueryUtils.formatFieldValue(entry.value),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xFFF1F5F9),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
