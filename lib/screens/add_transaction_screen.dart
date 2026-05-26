import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../services/firebase_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String? transactionId;
  final Map<String, dynamic>? initialData;

  const AddTransactionScreen({super.key, this.transactionId, this.initialData});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _transactionService = TransactionService();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'expense';
  String _category = 'Makanan';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  Uint8List? _receiptBytes;
  String? _receiptName;
  String? _receiptUrl;
  String? _receiptPath;
  String? _originalReceiptPath;
  bool _removeExistingReceipt = false;

  bool get _isEditing => widget.transactionId != null;

  static const _incomeCategories = [
    'Gaji',
    'Bonus',
    'Investasi',
    'Hadiah',
    'Lainnya',
  ];
  static const _expenseCategories = [
    'Makanan',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Hiburan',
    'Kesehatan',
    'Pendidikan',
    'Lainnya',
  ];

  List<String> get _categories =>
      _type == 'income' ? _incomeCategories : _expenseCategories;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _titleController.text = data['title']?.toString() ?? '';
      _amountController.text = data['amount']?.toString() ?? '';
      _type = data['type']?.toString() == 'income' ? 'income' : 'expense';
      final savedCategory = data['category']?.toString();
      _selectedDate =
          TransactionModel.dateFromValue(data['date']) ?? DateTime.now();
      _category = (_categories.contains(savedCategory))
          ? savedCategory!
          : _categories.first;
      _receiptUrl = data['receiptUrl']?.toString();
      _receiptPath = data['receiptPath']?.toString();
      _originalReceiptPath = _receiptPath;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    final amount = int.parse(_amountController.text.trim());
    try {
      await _transactionService.saveTransaction(
        transactionId: widget.transactionId,
        uid: user.uid,
        email: user.email,
        title: _titleController.text.trim(),
        amount: amount,
        type: _type,
        category: _category,
        date: _selectedDate,
        receiptBytes: _receiptBytes,
        receiptName: _receiptName,
        receiptUrl: _receiptUrl,
        receiptPath: _receiptPath,
        oldReceiptPath: _originalReceiptPath,
        removeExistingReceipt: _removeExistingReceipt,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan transaksi: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _receiptBytes = bytes;
      _receiptName = file.name;
      _removeExistingReceipt = false;
    });
  }

  void _removeReceipt() {
    setState(() {
      _receiptBytes = null;
      _receiptName = null;
      _receiptUrl = null;
      _receiptPath = null;
      _removeExistingReceipt = true;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaksi' : 'Tambah Transaksi'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'income',
                      label: Text('Pemasukan'),
                      icon: Icon(Icons.trending_up),
                    ),
                    ButtonSegment(
                      value: 'expense',
                      label: Text('Pengeluaran'),
                      icon: Icon(Icons.trending_down),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) {
                    setState(() {
                      _type = value.first;
                      _category = _categories.first;
                    });
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Judul',
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Judul wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah',
                    prefixIcon: Icon(Icons.payments),
                    prefixText: 'Rp ',
                  ),
                  validator: (value) {
                    final amount = int.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Jumlah harus lebih dari 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final category in _categories)
                      DropdownMenuItem(value: category, child: Text(category)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_formatDate(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 20),
                _ReceiptPicker(
                  receiptBytes: _receiptBytes,
                  receiptUrl: _receiptUrl,
                  receiptName: _receiptName,
                  onPick: _pickReceipt,
                  onRemove: _removeReceipt,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveTransaction,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_isEditing ? Icons.save : Icons.add),
                  label: Text(_isEditing ? 'Simpan Perubahan' : 'Simpan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptPicker extends StatelessWidget {
  final Uint8List? receiptBytes;
  final String? receiptUrl;
  final String? receiptName;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ReceiptPicker({
    required this.receiptBytes,
    required this.receiptUrl,
    required this.receiptName,
    required this.onPick,
    required this.onRemove,
  });

  bool get _hasReceipt =>
      receiptBytes != null || (receiptUrl != null && receiptUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                foregroundColor: colors.primary,
                child: const Icon(Icons.receipt_long),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Nota transaksi',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload_file),
                label: Text(_hasReceipt ? 'Ganti' : 'Upload'),
              ),
            ],
          ),
          if (_hasReceipt) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: receiptBytes != null
                    ? Image.memory(receiptBytes!, fit: BoxFit.cover)
                    : Image.network(receiptUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    receiptName ?? 'Nota tersimpan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                  label: const Text('Hapus'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Tambahkan foto nota agar transaksi lebih mudah dilacak.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
