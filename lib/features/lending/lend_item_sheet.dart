import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/item_model.dart';

class LendItemSheet extends StatefulWidget {
  final Item item;

  const LendItemSheet({super.key, required this.item});

  @override
  State<LendItemSheet> createState() => _LendItemSheetState();
}

class _LendItemSheetState extends State<LendItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _borrowerController = TextEditingController();
  final _contactController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _expectedReturnDate;

  @override
  void dispose() {
    _borrowerController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expectedReturnDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop({
      'borrowerName': _borrowerController.text.trim(),
      'borrowerContact': _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
      'expectedReturnAt': _expectedReturnDate,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.handshake, color: Colors.purpleAccent),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Lend Out Item',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Lending: ${widget.item.name}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _borrowerController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Borrower Name *',
                  hintText: 'e.g. David Miller, Alice, Neighbour Bob',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter borrower name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact (Phone / Email)',
                  hintText: 'e.g. +1 555-0192',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: Color(0xFF06B6D4)),
                title: Text(
                  _expectedReturnDate == null
                      ? 'Select Expected Return Date (Optional)'
                      : 'Return Due: ${DateFormat.yMMMd().format(_expectedReturnDate!)}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: Text(_expectedReturnDate == null ? 'Set Date' : 'Change'),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes / Condition',
                  hintText: 'e.g. Borrowing to hang drywall this weekend',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent.shade700,
                    ),
                    onPressed: _submit,
                    child: const Text('Confirm Loan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
