import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/item_model.dart';
import '../../models/polygon_region.dart';
import '../../state/item_state.dart';
import '../../state/storage_state.dart';
import '../polygon_canvas/polygon_canvas_widget.dart';

class ItemLocatorScreen extends ConsumerStatefulWidget {
  final String? initialItemId;

  const ItemLocatorScreen({super.key, this.initialItemId});

  @override
  ConsumerState<ItemLocatorScreen> createState() => _ItemLocatorScreenState();
}

class _ItemLocatorScreenState extends ConsumerState<ItemLocatorScreen> {
  String? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _selectedItemId = widget.initialItemId;
  }

  @override
  Widget build(BuildContext context) {
    final allItemsAsync = ref.watch(libraryItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Item Locator'),
      ),
      body: allItemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No items in this library yet.'));
          }

          // If no item selected yet, default to initialItemId or first item
          final activeItem = items.firstWhere(
            (it) => it.id == (_selectedItemId ?? widget.initialItemId),
            orElse: () => items.first,
          );

          return Column(
            children: [
              // Item Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF131B2E),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: Color(0xFF06B6D4), size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'Locating:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: activeItem.id,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          items: items.map((it) {
                            return DropdownMenuItem(
                              value: it.id,
                              child: Text(
                                it.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (newId) {
                            if (newId != null) {
                              setState(() => _selectedItemId = newId);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Active Item Locator View
              Expanded(
                child: _ItemLocatorDetailView(item: activeItem),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _ItemLocatorDetailView extends ConsumerWidget {
  final Item item;

  const _ItemLocatorDetailView({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.storageLocationId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 56, color: Color(0xFF64748B)),
              const SizedBox(height: 16),
              Text(
                '${item.name} has no assigned storage container',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Assign a canonical storage location to view its guided visual hierarchy.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      );
    }

    final locationAsync = ref.watch(storageLocationDetailProvider(item.storageLocationId!));
    final breadcrumbsAsync = ref.watch(locationBreadcrumbsProvider(item.storageLocationId!));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Relocation / Lending Warning Banner
          if (item.isTemporarilyRelocated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.amber.withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Temporarily Displaced!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Canonical home is shown below, but the item is currently: "${item.temporaryLocationNote ?? "Away"}"',
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else if (item.isLentOut)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: Colors.purple.withOpacity(0.2),
              child: const Row(
                children: [
                  Icon(Icons.handshake, color: Colors.purpleAccent, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notice: This item is currently lent out to a borrower. Its home storage place is shown below.',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                    ),
                  ),
                ],
              ),
            ),

          // 2. Guided Breadcrumb Path
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF0F172A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NAVIGATION PATHWAY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                breadcrumbsAsync.when(
                  data: (crumbs) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < crumbs.length; i++) ...[
                            if (i > 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(Icons.arrow_forward, size: 14, color: Color(0xFF64748B)),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: i == crumbs.length - 1
                                    ? const Color(0xFF06B6D4).withOpacity(0.2)
                                    : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: i == crumbs.length - 1
                                      ? const Color(0xFF06B6D4)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              child: Text(
                                crumbs[i].name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: i == crumbs.length - 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: i == crumbs.length - 1
                                      ? const Color(0xFF06B6D4)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Error loading pathway'),
                ),
              ],
            ),
          ),

          // 3. Storage Container Photo with Pulsing Polygon Highlight
          locationAsync.when(
            data: (location) {
              if (location == null) return const Text('Location details unavailable');

              // Find if this container has a polygon linked to our item
              final matchingRegion = location.regions.firstWhere(
                (r) => r.targetItemId == item.id,
                orElse: () => PolygonRegion(
                  id: 'item-mapped-${item.id}',
                  label: item.name,
                  points: item.polygonPoints,
                  targetItemId: item.id,
                  colorHex: 0xFFF59E0B, // Pulsing Gold
                ),
              );

              final effectiveRegions = [...location.regions];
              if (!effectiveRegions.any((r) => r.targetItemId == item.id) &&
                  item.hasPolygon) {
                effectiveRegions.add(matchingRegion);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 320,
                    width: double.infinity,
                    color: Colors.black,
                    child: PolygonCanvasWidget(
                      imageUrl: location.imageUrl,
                      regions: effectiveRegions,
                      highlightedRegionId: matchingRegion.id,
                      mode: CanvasMode.highlight,
                    ),
                  ),

                  // Guided description footer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.pin_drop, color: Color(0xFFF59E0B)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Look inside: ${location.name}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (location.description != null)
                                        Text(
                                          location.description!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'The exact storage spot is marked above with the glowing amber pulsing halo.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }
}
