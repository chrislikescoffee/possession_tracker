import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/item_list_model.dart';
import '../../state/item_list_state.dart';
import '../../state/library_state.dart';
import '../../state/repository_provider.dart';
import 'add_edit_list_dialog.dart';

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  Future<void> _createNewList(BuildContext context, WidgetRef ref, String libraryId) async {
    final newList = await showDialog<ItemList>(
      context: context,
      builder: (ctx) => AddEditListDialog(libraryId: libraryId),
    );
    if (newList != null) {
      final repo = ref.read(repositoryProvider);
      await repo.saveItemList(newList);
      ref.invalidate(itemListsProvider);
      if (context.mounted) {
        context.go('/lists/${newList.id}');
      }
    }
  }

  Future<void> _editList(BuildContext context, WidgetRef ref, ItemList list) async {
    final updated = await showDialog<ItemList>(
      context: context,
      builder: (ctx) => AddEditListDialog(
        libraryId: list.libraryId,
        listToEdit: list,
      ),
    );
    if (updated != null) {
      final repo = ref.read(repositoryProvider);
      await repo.saveItemList(updated);
      ref.invalidate(itemListsProvider);
      ref.invalidate(itemListDetailProvider(list.id));
    }
  }

  Future<void> _deleteList(BuildContext context, WidgetRef ref, ItemList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete List?'),
        content: Text('Are you sure you want to delete "${list.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(repositoryProvider);
      await repo.deleteItemList(list.id);
      ref.invalidate(itemListsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted list "${list.name}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedLib = ref.watch(selectedLibraryProvider).value;

    if (selectedLib == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lists')),
        body: const Center(child: Text('Please select or create a library.')),
      );
    }

    final listsAsync = ref.watch(itemListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(itemListsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New List'),
        onPressed: () => _createNewList(context, ref, selectedLib.id),
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading lists: $e')),
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.checklist_rounded, size: 64, color: colorScheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Lists Yet',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create packing lists, maintenance batches, or tool lending lists with items from any storage area.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create First List'),
                      onPressed: () => _createNewList(context, ref, selectedLib.id),
                    ),
                  ],
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final crossAxisCount = constraints.maxWidth >= 1080 ? 3 : (isWide ? 2 : 1);

              if (crossAxisCount > 1) {
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 220,
                  ),
                  itemCount: lists.length,
                  itemBuilder: (ctx, idx) => _buildListCard(context, ref, lists[idx]),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lists.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) => _buildListCard(context, ref, lists[idx]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildListCard(BuildContext context, WidgetRef ref, ItemList list) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: () => context.go('/lists/${list.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.format_list_bulleted_rounded, color: colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          list.destinationType.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _editList(context, ref, list);
                      } else if (val == 'delete') {
                        _deleteList(context, ref, list);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit List')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
              ),
              if (list.description != null && list.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  list.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ],
              const Spacer(),

              // Progress info
              Row(
                children: [
                  Text(
                    '${list.collectedCount} of ${list.totalCount} collected',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (list.isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Complete',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '${(list.progress * 100).toInt()}%',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: list.progress,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    list.isComplete ? const Color(0xFF10B981) : colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
