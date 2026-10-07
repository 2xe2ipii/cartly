import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/cartly_api.dart';

class AddItemSheet extends StatefulWidget {
  const AddItemSheet({super.key, required this.onAdd});

  final Future<void> Function(String name, int quantity) onAdd;

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  bool _saving = false;
  String? _serverError;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      await widget.onAdd(
        _nameController.text.trim(),
        int.parse(_quantityController.text.trim()),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on CartlyApiException catch (error) {
      if (mounted) {
        setState(() {
          _serverError = error.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverError = 'Something went wrong. Please try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add item',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  enabled: !_saving,
                  maxLength: 100,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(100),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Name is required.';
                    if (trimmed.length > 100) return 'Name must be 100 characters or less.';
                    return null;
                  },
                  onChanged: (_) => _clearServerError(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  enabled: !_saving,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    final quantity = int.tryParse(trimmed);
                    if (quantity == null || quantity < 1) {
                      return 'Quantity must be at least 1.';
                    }
                    if (quantity > 9999) {
                      return 'Quantity must be 9,999 or less.';
                    }
                    return null;
                  },
                  onChanged: (_) => _clearServerError(),
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _serverError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Adding…' : 'Add item'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearServerError() {
    if (_serverError != null) setState(() => _serverError = null);
  }
}
