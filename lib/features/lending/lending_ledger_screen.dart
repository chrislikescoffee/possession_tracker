import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../state/item_state.dart';
import '../../state/repository_provider.dart';

class LendingLedgerScreen extends ConsumerWidget {
  const LendingLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lendingRecordsAsync = ref.watch(lendingRecordsProvider);
    final itemsAsync = ref.watch(libraryItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lending & Custody Ledger'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(lendingRecordsProvider),
          ),
        ],
      ),
      body: lendingRecordsAsync.when(
        data: (records) {
          final itemsMap = {
            for (final it in (itemsAsync.value ?? [])) it.id: it
          };

          final activeLoans = records.where((r) => r.isActive).toList();
          final returnedLoans = records.where((r) => !r.isActive).toList();

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.handshake_outlined, size: 56, color: Color(0xFF64748B)),
                  SizedBox(height: 16),
                  Text(
                    'No lending records yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lend out items from an item’s detail page to track custody.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Active Loans Section
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.purpleAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Loans (${activeLoans.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (activeLoans.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'All items are currently in your possession.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              else
                ...activeLoans.map((record) {
                  final itemName = itemsMap[record.itemId]?.name ?? 'Item ${record.itemId}';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
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
                                  color: Colors.purple.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.handshake, color: Colors.purpleAccent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Borrower: ${record.borrowerName}',
                                      style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (record.borrowerContact != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('Contact: ${record.borrowerContact!}',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                            ),
                          Text(
                            'Lent on: ${DateFormat.yMMMd().format(record.lentAt)}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                          if (record.expectedReturnAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Due back: ${DateFormat.yMMMd().format(record.expectedReturnAt!)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          if (record.notes != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('Note: "${record.notes!}"',
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Mark Returned'),
                              onPressed: () async {
                                final repo = ref.read(repositoryProvider);
                                await repo.returnLentItem(record.id);
                                ref.invalidate(lendingRecordsProvider);
                                ref.invalidate(libraryItemsProvider);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // Past History Section
              if (returnedLoans.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF64748B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Past Loan History (${returnedLoans.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...returnedLoans.map((record) {
                  final itemName = itemsMap[record.itemId]?.name ?? 'Item ${record.itemId}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, color: Color(0xFF64748B)),
                    title: Text('$itemName returned by ${record.borrowerName}'),
                    subtitle: Text(
                      'Returned: ${record.returnedAt != null ? DateFormat.yMMMd().format(record.returnedAt!) : "Yes"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  );
                }),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
