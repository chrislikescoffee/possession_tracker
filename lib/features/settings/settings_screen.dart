import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../models/field_definition_model.dart';
import '../../models/item_type_model.dart';
import '../../models/library_model.dart';
import '../../models/sync_model.dart';
import '../../state/auth_state.dart';
import '../../state/item_state.dart';
import '../../state/item_type_state.dart';
import '../../state/library_state.dart';
import '../../state/repository_provider.dart';
import '../../state/storage_state.dart';
import '../../state/sync_state.dart';
import '../items/item_type_manager_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showCreateLibraryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Library'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Library Name',
            hintText: 'e.g. Vacation Home, Work Studio, Storage Unit',
            prefixIcon: Icon(Icons.book_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                ref.read(selectedLibraryProvider.notifier).createAndSelect(name);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, Library library) {
    final inviteToken = 'pt_inv_${const Uuid().v4().substring(0, 8)}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.person_add_alt_1, color: Color(0xFF6366F1)),
            SizedBox(width: 10),
            Text('Invite Collaborator'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite users to collaborate on "${library.name}".',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Zero-knowledge isolation: Invited users will only be granted access to this library. Uninvited users cannot detect the existence of your libraries.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'https://possessiontracker.app/join/$inviteToken',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF06B6D4),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy link',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: 'https://possessiontracker.app/join/$inviteToken'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite link copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  IconData _getItemTypeIcon(String? iconName) {
    switch (iconName) {
      case 'build':
        return Icons.build;
      case 'palette':
        return Icons.palette;
      case 'terrain':
        return Icons.terrain;
      case 'home':
        return Icons.home;
      case 'kitchen':
        return Icons.kitchen;
      case 'sports':
        return Icons.sports_tennis;
      case 'devices':
        return Icons.devices;
      case 'inventory_2':
      default:
        return Icons.inventory_2;
    }
  }

  void _confirmDeleteItemType(BuildContext context, WidgetRef ref, ItemType type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item Type'),
        content: Text(
          'Are you sure you want to delete "${type.name}"? Existing items will retain their data, but this template will no longer be available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final repo = ref.read(repositoryProvider);
              await repo.deleteItemType(type.id);
              ref.invalidate(itemTypesProvider);
              ref.invalidate(itemTypesForLibraryProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Item type "${type.name}" deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAuthDialog(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var isSignUp = false;
    var isLoading = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              Icon(isSignUp ? Icons.person_add : Icons.login, color: const Color(0xFF38BDF8), size: 22),
              const SizedBox(width: 8),
              Text(isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSignUp
                      ? 'Create an account to securely sync and access your storage inventory from any device.'
                      : 'Sign in to access your synchronized inventory.',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isSignUp = !isSignUp;
                      errorText = null;
                    });
                  },
                  child: Text(
                    isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Create one",
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              onPressed: isLoading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();
                      if (email.isEmpty || password.isEmpty) {
                        setState(() => errorText = 'Please enter both email and password.');
                        return;
                      }

                      setState(() {
                        isLoading = true;
                        errorText = null;
                      });

                      try {
                        if (isSignUp) {
                          await ref.read(authProvider.notifier).signUp(email: email, password: password);
                        } else {
                          await ref.read(authProvider.notifier).signIn(email: email, password: password);
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isSignUp
                                    ? 'Account created! Inventory synced to cloud.'
                                    : 'Signed in successfully!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          isLoading = false;
                          errorText = e.toString().replaceAll('Exception:', '').trim();
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isSignUp ? 'Create Account' : 'Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteLibraryDialog(
    BuildContext context,
    WidgetRef ref,
    Library library,
    bool isSelected,
    List<Library> allLibs,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Row(
              children: [
                Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 22),
                SizedBox(width: 8),
                Text('Delete Library?', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete "${library.name}"?\nAll storage containers, mapped polygons, and item records inside this library will be permanently removed.',
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cloud_outlined, color: Color(0xFF38BDF8), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete Online Backup?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Do you also want to delete the online backup of this library from the database?',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDeleting) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
            actions: isDeleting
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_off, size: 15),
                      label: const Text('No, Keep Backup'),
                      onPressed: () async {
                        setDialogState(() => isDeleting = true);
                        await _handleDeleteLibrary(
                          context,
                          ref,
                          library,
                          isSelected,
                          allLibs,
                          deleteOnline: false,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                      icon: const Icon(Icons.delete_forever, size: 15),
                      label: const Text('Yes, Delete from Database'),
                      onPressed: () async {
                        setDialogState(() => isDeleting = true);
                        await _handleDeleteLibrary(
                          context,
                          ref,
                          library,
                          isSelected,
                          allLibs,
                          deleteOnline: true,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                  ],
          ),
        );
      },
    );
  }

  Future<void> _handleDeleteLibrary(
    BuildContext context,
    WidgetRef ref,
    Library library,
    bool isSelected,
    List<Library> allLibs, {
    required bool deleteOnline,
  }) async {
    final repo = ref.read(repositoryProvider);
    await repo.deleteLibrary(library.id, deleteOnlineBackup: deleteOnline);

    if (isSelected) {
      final remaining = allLibs.where((l) => l.id != library.id).toList();
      if (remaining.isNotEmpty) {
        ref.read(selectedLibraryProvider.notifier).selectLibrary(remaining.first);
      }
    }

    ref.invalidate(librariesProvider);
    ref.invalidate(selectedLibraryProvider);
    ref.invalidate(allStorageLocationsProvider);
    ref.invalidate(storageLocationsProvider(null));
    ref.invalidate(libraryItemsProvider);
    ref.invalidate(itemTypesProvider);
    ref.invalidate(itemTypesForLibraryProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleteOnline
                ? 'Library "${library.name}" and online backup deleted from database.'
                : 'Library "${library.name}" deleted locally. Online backup kept.',
          ),
        ),
      );
    }
  }

  Widget _buildSyncStatusBadge(SyncStatusInfo status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status.state) {
      case SyncState.synced:
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF10B981);
        label = 'Synced';
        icon = Icons.cloud_done;
        break;
      case SyncState.syncing:
        bg = const Color(0xFF38BDF8).withValues(alpha: 0.15);
        fg = const Color(0xFF38BDF8);
        label = 'Syncing...';
        icon = Icons.sync;
        break;
      case SyncState.pendingSync:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFF59E0B);
        label = '${status.pendingCount} Pending';
        icon = Icons.cloud_upload_outlined;
        break;
      case SyncState.offline:
        bg = const Color(0xFF64748B).withValues(alpha: 0.15);
        fg = const Color(0xFF94A3B8);
        label = 'Offline';
        icon = Icons.cloud_off;
        break;
      case SyncState.notConfigured:
        bg = const Color(0xFF64748B).withValues(alpha: 0.15);
        fg = const Color(0xFF94A3B8);
        label = 'Local Only';
        icon = Icons.cloud_outlined;
        break;
      case SyncState.error:
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFEF4444);
        label = 'Sync Error';
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLib = ref.watch(selectedLibraryProvider).value;
    final allLibsAsync = ref.watch(librariesProvider);
    final quotaAsync = ref.watch(libraryQuotaProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final autoSyncEnabled = ref.watch(autoSyncProvider);
    final currentUser = ref.watch(authProvider);
    final itemTypesAsync = ref.watch(itemTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Libraries'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Quota & License Gating Card (Freemium Gate)
          Card(
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
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Item Limit & License Status',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  quotaAsync.when(
                    data: (quota) {
                      final percent = (quota.current / quota.max).clamp(0.0, 1.0);
                      final isNearLimit = quota.current >= (quota.max * 0.8);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${quota.current} of ${quota.max} items used',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isNearLimit ? Colors.amber : Colors.white,
                                ),
                              ),
                              Text(
                                '${(percent * 100).toInt()}%',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 8,
                              backgroundColor: const Color(0xFF1E293B),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isNearLimit ? Colors.amber : const Color(0xFF06B6D4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Each library includes 50 items for free during development. Upgrade license to unlock unlimited items.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.upgrade, size: 18),
                              label: const Text('Upgrade License'),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment gateway integration: Upgrades to unlimited tier.'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error loading quota'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Barcode & QR Code Label Printing Card
          Card(
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
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF06B6D4), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Print Barcodes & QR Codes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Generate cuttable PDF label sheets for your items and storage areas with barcodes or QR codes.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print Barcodes/QR Codes'),
                      onPressed: () => context.push('/settings/barcodes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Cloud Sync & Online Backup Card
          Card(
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
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cloud_sync, color: Color(0xFF38BDF8), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cloud Sync & Backup',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Offline-first with cloud replication',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      _buildSyncStatusBadge(syncStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'All items and storage mappings are saved permanently on this device. Connect your Supabase project to enable automatic multi-device cloud backup.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 14),
                  // User Account Banner
                  if (currentUser != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_circle, size: 22, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Signed In Account', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                Text(
                                  currentUser.email ?? currentUser.id,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(Icons.logout, size: 14),
                            label: const Text('Sign Out', style: TextStyle(fontSize: 12)),
                            onPressed: () => ref.read(authProvider.notifier).signOut(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, size: 20, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Local Only Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('Sign in to sync your inventory to the cloud', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _showAuthDialog(context, ref),
                            child: const Text('Sign In', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Divider(color: Color(0xFF334155), height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto-sync changes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Automatically push changes to the online database when signed in',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    value: autoSyncEnabled,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      ref.read(autoSyncProvider.notifier).toggle(val);
                    },
                  ),
                  const SizedBox(height: 6),
                  if (syncStatus.lastSyncedAt != null) ...[
                    Text(
                      'Last synced: ${syncStatus.lastSyncedAt!.toLocal().toString().split('.').first}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (syncStatus.errorMessage != null && currentUser != null) ...[
                    Text(
                      syncStatus.errorMessage!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (currentUser == null) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text('Sign In to Sync', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAuthDialog(context, ref),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                          ),
                          icon: syncStatus.state == SyncState.syncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync, size: 16),
                          label: Text(
                            syncStatus.state == SyncState.syncing ? 'Syncing...' : 'Sync Now',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: syncStatus.state == SyncState.syncing
                              ? null
                              : () async {
                                  final result = await ref
                                      .read(syncStatusProvider.notifier)
                                      .syncNow(force: true);
                                  if (context.mounted) {
                                    if (result.state == SyncState.error) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.redAccent,
                                          content: Text(result.errorMessage ?? 'Sync failed.'),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: Color(0xFF10B981),
                                          content: Text('Cloud sync completed successfully!'),
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                          label: const Text('Upload Local Data', style: TextStyle(fontSize: 12)),
                          onPressed: syncStatus.state == SyncState.syncing
                              ? null
                              : () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Uploading all local inventory to the cloud...'),
                                    ),
                                  );
                                  final syncService = ref.read(cloudSyncServiceProvider);
                                  await syncService.pushAllLocalData();
                                  final res = await ref
                                      .read(syncStatusProvider.notifier)
                                      .syncNow(force: true);
                                  if (context.mounted) {
                                    if (res.state == SyncState.error) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: Colors.redAccent,
                                          content: Text(res.errorMessage ?? 'Upload failed.'),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: Color(0xFF10B981),
                                          content: Text('Local inventory uploaded and synced!'),
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Active Library & Switcher Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_shared_outlined, color: Color(0xFF6366F1), size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Item Libraries',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Create New Library',
                        icon: const Icon(Icons.add, color: Color(0xFF6366F1)),
                        onPressed: () => _showCreateLibraryDialog(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  allLibsAsync.when(
                    data: (libs) {
                      return Column(
                        children: libs.map((lib) {
                          final isSelected = lib.id == selectedLib?.id;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            ),
                            title: Text(
                              lib.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text('Max: ${lib.itemLimit} items'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.share, size: 14),
                                    label: const Text('Invite', style: TextStyle(fontSize: 12)),
                                    onPressed: () => _showInviteDialog(context, lib),
                                  ),
                                if (libs.length > 1) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: 'Delete Library',
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                    onPressed: () => _showDeleteLibraryDialog(
                                      context,
                                      ref,
                                      lib,
                                      isSelected,
                                      libs,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              ref.read(selectedLibraryProvider.notifier).selectLibrary(lib);
                            },
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 4. Item Types & Schemas Card
          Card(
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
                          color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.category_outlined, color: Color(0xFF818CF8), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Item Types & Schemas',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Custom attributes and templates for your inventory',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Type', style: TextStyle(fontSize: 12)),
                        onPressed: selectedLib == null
                            ? null
                            : () async {
                                await showDialog(
                                  context: context,
                                  builder: (_) => ItemTypeManagerDialog(libraryId: selectedLib.id),
                                );
                                ref.invalidate(itemTypesProvider);
                                ref.invalidate(itemTypesForLibraryProvider);
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  itemTypesAsync.when(
                    data: (types) {
                      if (types.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'No custom item types defined.\nTap "+ Add Type" to create custom fields and templates.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: types.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155), height: 16),
                        itemBuilder: (ctx, index) {
                          final type = types[index];
                          final isGeneric = type.id == 'generic' ||
                              type.id == 'generic_type' ||
                              type.id == 'default_type' ||
                              type.name.trim().toLowerCase() == 'generic item';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_getItemTypeIcon(type.icon), size: 20, color: const Color(0xFF818CF8)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          type.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        if (type.description != null && type.description!.isNotEmpty)
                                          Text(
                                            type.description!,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit Type',
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF38BDF8)),
                                    onPressed: selectedLib == null
                                        ? null
                                        : () async {
                                            await showDialog(
                                              context: context,
                                              builder: (_) => ItemTypeManagerDialog(
                                                libraryId: selectedLib.id,
                                                initialItemType: type,
                                              ),
                                            );
                                            ref.invalidate(itemTypesProvider);
                                            ref.invalidate(itemTypesForLibraryProvider);
                                          },
                                  ),
                                  if (!isGeneric)
                                    IconButton(
                                      tooltip: 'Delete Type',
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                      onPressed: () => _confirmDeleteItemType(context, ref, type),
                                    ),
                                ],
                              ),
                              if (type.fields.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: type.fields.map((field) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF334155)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            field.name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            field.unit != null ? '(${field.unit})' : '[${field.type.displayName}]',
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF818CF8)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text(
                      'Error loading item types: $err',
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 5. Application Details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About PossessionTracker',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '${AppConstants.appName} v1.0.0\n${AppConstants.appTagline}',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Built with Flutter, Riverpod, GoRouter, and Supabase / PostgreSQL relational architecture.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
