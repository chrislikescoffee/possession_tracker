import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/field_definition_model.dart';

class TypedFieldInputWidget extends StatefulWidget {
  final FieldDefinition field;
  final dynamic initialValue;
  final ValueChanged<dynamic> onChanged;
  final VoidCallback? onRemove;

  const TypedFieldInputWidget({
    super.key,
    required this.field,
    this.initialValue,
    required this.onChanged,
    this.onRemove,
  });

  @override
  State<TypedFieldInputWidget> createState() => _TypedFieldInputWidgetState();
}

class _TypedFieldInputWidgetState extends State<TypedFieldInputWidget> {
  // Text / Number controller
  late TextEditingController _textController;

  // Dimension controllers
  late TextEditingController _dimHeightController;
  late TextEditingController _dimWidthController;
  late TextEditingController _dimDepthController;
  String _dimUnit = 'cm';

  // Weight controller
  late TextEditingController _weightController;
  String _weightUnit = 'kg';

  // Currency controller
  late TextEditingController _currencyController;
  String _currencyCode = 'AUD';

  // Date value
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    final val = widget.initialValue ?? widget.field.defaultValue;

    _textController = TextEditingController(text: val?.toString() ?? '');

    // Dimension
    Map dimMap = val is Map ? val : {};
    _dimHeightController = TextEditingController(text: dimMap['height']?.toString() ?? '');
    _dimWidthController = TextEditingController(text: dimMap['width']?.toString() ?? '');
    _dimDepthController = TextEditingController(text: dimMap['depth']?.toString() ?? '');
    _dimUnit = dimMap['unit']?.toString() ?? widget.field.unit ?? 'cm';

    // Weight
    Map weightMap = val is Map ? val : {};
    _weightController = TextEditingController(
        text: weightMap['weight']?.toString() ?? (val is num ? val.toString() : ''));
    _weightUnit = weightMap['unit']?.toString() ?? widget.field.unit ?? 'kg';

    // Currency
    Map currencyMap = val is Map ? val : {};
    _currencyController = TextEditingController(
        text: currencyMap['amount']?.toString() ?? (val is num ? val.toString() : ''));
    _currencyCode = currencyMap['currency']?.toString() ?? widget.field.unit ?? 'AUD';

    // Date
    if (val != null) {
      if (val is DateTime) {
        _selectedDate = val;
      } else {
        _selectedDate = DateTime.tryParse(val.toString());
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _dimHeightController.dispose();
    _dimWidthController.dispose();
    _dimDepthController.dispose();
    _weightController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _emitDimension() {
    final h = double.tryParse(_dimHeightController.text.trim()) ?? 0.0;
    final w = double.tryParse(_dimWidthController.text.trim()) ?? 0.0;
    final d = double.tryParse(_dimDepthController.text.trim()) ?? 0.0;
    widget.onChanged({
      'height': h,
      'width': w,
      'depth': d,
      'unit': _dimUnit,
    });
  }

  void _emitWeight() {
    final w = double.tryParse(_weightController.text.trim()) ?? 0.0;
    widget.onChanged({
      'weight': w,
      'unit': _weightUnit,
    });
  }

  void _emitCurrency() {
    final amt = double.tryParse(_currencyController.text.trim()) ?? 0.0;
    widget.onChanged({
      'amount': amt,
      'currency': _currencyCode,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Field name, type chip & optional remove button
          Row(
            children: [
              Text(
                widget.field.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.field.type.displayName,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF818CF8)),
                ),
              ),
              const Spacer(),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Typed input bodies
          _buildInputBody(context),
        ],
      ),
    );
  }

  Widget _buildInputBody(BuildContext context) {
    switch (widget.field.type) {
      case ItemFieldType.text:
        return TextFormField(
          controller: _textController,
          decoration: InputDecoration(
            hintText: 'Enter ${widget.field.name.toLowerCase()}...',
            isDense: true,
          ),
          onChanged: widget.onChanged,
        );

      case ItemFieldType.number:
        return TextFormField(
          controller: _textController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '0',
            suffixText: widget.field.unit,
            isDense: true,
          ),
          onChanged: (val) {
            final parsed = num.tryParse(val.trim());
            widget.onChanged(parsed ?? val);
          },
        );

      case ItemFieldType.dimension:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _dimHeightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'H', isDense: true),
                onChanged: (_) => _emitDimension(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('×', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            Expanded(
              child: TextFormField(
                controller: _dimWidthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'W', isDense: true),
                onChanged: (_) => _emitDimension(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('×', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            Expanded(
              child: TextFormField(
                controller: _dimDepthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'D', isDense: true),
                onChanged: (_) => _emitDimension(),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _dimUnit,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'cm', child: Text('cm')),
                DropdownMenuItem(value: 'mm', child: Text('mm')),
                DropdownMenuItem(value: 'in', child: Text('in')),
                DropdownMenuItem(value: 'm', child: Text('m')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _dimUnit = val);
                  _emitDimension();
                }
              },
            ),
          ],
        );

      case ItemFieldType.weight:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '0.0',
                  isDense: true,
                ),
                onChanged: (_) => _emitWeight(),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _weightUnit,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'kg', child: Text('kg')),
                DropdownMenuItem(value: 'g', child: Text('g')),
                DropdownMenuItem(value: 'lb', child: Text('lb')),
                DropdownMenuItem(value: 'oz', child: Text('oz')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _weightUnit = val);
                  _emitWeight();
                }
              },
            ),
          ],
        );

      case ItemFieldType.currency:
        return Row(
          children: [
            DropdownButton<String>(
              value: _currencyCode,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'AUD', child: Text('AUD \$')),
                DropdownMenuItem(value: 'USD', child: Text('USD \$')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR €')),
                DropdownMenuItem(value: 'GBP', child: Text('GBP £')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _currencyCode = val);
                  _emitCurrency();
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _currencyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  isDense: true,
                ),
                onChanged: (_) => _emitCurrency(),
              ),
            ),
          ],
        );

      case ItemFieldType.date:
        final formattedDate = _selectedDate != null
            ? DateFormat.yMMMMd().format(_selectedDate!)
            : 'Select date';

        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime(1970),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
              widget.onChanged(picked.toIso8601String().split('T').first);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF475569)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Color(0xFF818CF8)),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: _selectedDate != null ? Colors.white : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
