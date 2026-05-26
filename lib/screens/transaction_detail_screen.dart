import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String Function(num value) rupiah;
  final VoidCallback onEdit;
  final Future<bool> Function() onDelete;

  const TransactionDetailScreen({
    super.key,
    required this.doc,
    required this.rupiah,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = data['title']?.toString() ?? 'Tanpa judul';
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final type = data['type']?.toString() == 'income' ? 'Pemasukan' : 'Pengeluaran';
    final category = data['category']?.toString().trim();
    final categoryLabel = (category == null || category.isEmpty) ? 'Lainnya' : category;
    final date = _dateFromValue(data['date']);
    final formattedDate = date == null ? '-' : '${date.day}/${date.month}/${date.year}';
    final receiptUrl = data['receiptUrl']?.toString();
    final isIncome = type == 'Pemasukan';
    final color = isIncome ? const Color(0xFF16A34A) : const Color(0xFFEF4444);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Chip(
                          backgroundColor: color.withOpacity(0.14),
                          label: Text(
                            type,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceVariant,
                          label: Text(categoryLabel),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          rupiah(amount),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isIncome ? 'Masuk' : 'Keluar',
                          style: TextStyle(
                            color: color.withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: [
                  _InfoRow(label: 'Tanggal', value: formattedDate),
                  const Divider(height: 0),
                  _InfoRow(label: 'Kategori', value: categoryLabel),
                  const Divider(height: 0),
                  _InfoRow(label: 'Jenis', value: type),
                  const Divider(height: 0),
                  _InfoRow(label: 'ID Transaksi', value: doc.id),
                ],
              ),
            ),
            if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Struk / Nota',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: InteractiveViewer(
                    child: Image.network(
                      receiptUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          alignment: Alignment.center,
                          child: const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Gagal memuat nota'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final deleted = await onDelete();
                      if (deleted && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _dateFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
