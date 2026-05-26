import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import 'add_transaction_screen.dart';
import 'budget_screen.dart';
import 'profile_screen.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _typeFilter = 'all';
  String _categoryFilter = 'all';
  bool _monthOnly = false;

  static const _categories = [
    'Gaji',
    'Bonus',
    'Investasi',
    'Hadiah',
    'Makanan',
    'Transportasi',
    'Belanja',
    'Tagihan',
    'Hiburan',
    'Kesehatan',
    'Pendidikan',
    'Lainnya',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> _transactionsRef() {
    return FirebaseFirestore.instance.collection('transactions');
  }

  DocumentReference<Map<String, dynamic>> _budgetRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('budget');
  }

  String _rupiah(num value) {
    final text = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final reverseIndex = text.length - i;
      buffer.write(text[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'Rp $buffer';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredTransactions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    return transactions.where((doc) {
      final data = doc.data();
      final title = data['title']?.toString().toLowerCase() ?? '';
      final category = data['category']?.toString().trim();
      final normalizedCategory = (category == null || category.isEmpty)
          ? 'Lainnya'
          : category;
      final type = data['type']?.toString() == 'income' ? 'income' : 'expense';
      final transactionDate = _dateFromValue(data['date']);

      if (_typeFilter != 'all' && type != _typeFilter) return false;
      if (_categoryFilter != 'all' && normalizedCategory != _categoryFilter) {
        return false;
      }
      if (_monthOnly) {
        if (transactionDate == null) return false;
        if (transactionDate.year != now.year ||
            transactionDate.month != now.month) {
          return false;
        }
      }
      if (query.isNotEmpty &&
          !title.contains(query) &&
          !normalizedCategory.toLowerCase().contains(query)) {
        return false;
      }

      return true;
    }).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _ownedTransactions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String uid,
  ) {
    final transactions = docs.where((doc) {
      final userId = doc.data()['userId']?.toString();
      return userId == null || userId.isEmpty || userId == uid;
    }).toList();
    transactions.sort((a, b) {
      final aDate = _dateFromValue(a.data()['date']);
      final bDate = _dateFromValue(b.data()['date']);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return transactions;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _monthTransactions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions,
  ) {
    final now = DateTime.now();
    return transactions.where((doc) {
      final date = _dateFromValue(doc.data()['date']);
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();
  }

  static DateTime? _dateFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Belum login')));
    }

    final transactionsStream = _transactionsRef().snapshots();
    final budgetStream = _budgetRef(user.uid).snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyFlow'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                tooltip: 'Dark mode',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () {
                  themeModeNotifier.value = isDark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: budgetStream,
        builder: (context, budgetSnapshot) {
          if (budgetSnapshot.hasError) {
            return Center(
              child: Text('Gagal memuat budget: ${budgetSnapshot.error}'),
            );
          }

          if (!budgetSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final budgetLimit =
              (budgetSnapshot.data!.data()?['monthlyLimit'] as num?)?.toInt() ??
              0;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: transactionsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Gagal memuat data: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final transactions = _ownedTransactions(
                snapshot.data!.docs,
                user.uid,
              );
              final filteredTransactions = _filteredTransactions(transactions);
              final totals = _Totals.from(filteredTransactions);
              final monthTransactions = _monthTransactions(transactions);
              final monthTotals = _Totals.from(monthTransactions);

              return RefreshIndicator(
                onRefresh: () async {},
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _UserHeader(
                              user: user,
                              onTap: () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                );
                                if (updated == true) {
                                  await FirebaseAuth.instance.currentUser
                                      ?.reload();
                                  if (context.mounted) setState(() {});
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            _HeroBalanceCard(totals: totals, rupiah: _rupiah),
                            const SizedBox(height: 14),
                            _BudgetCard(
                              limit: budgetLimit,
                              spent: monthTotals.expense,
                              rupiah: _rupiah,
                              onEdit: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BudgetScreen(currentLimit: budgetLimit),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            _SummaryGrid(totals: totals, rupiah: _rupiah),
                            const SizedBox(height: 14),
                            _ChartCard(totals: totals, rupiah: _rupiah),
                            const SizedBox(height: 14),
                            _TrendChartCard(
                              points: _DailyPoint.from(filteredTransactions),
                              rupiah: _rupiah,
                            ),
                            const SizedBox(height: 14),
                            _FilterPanel(
                              searchController: _searchController,
                              typeFilter: _typeFilter,
                              categoryFilter: _categoryFilter,
                              monthOnly: _monthOnly,
                              categories: _categories,
                              onSearchChanged: (_) => setState(() {}),
                              onTypeChanged: (value) {
                                setState(() => _typeFilter = value);
                              },
                              onCategoryChanged: (value) {
                                setState(() => _categoryFilter = value);
                              },
                              onMonthOnlyChanged: (value) {
                                setState(() => _monthOnly = value);
                              },
                              onReset: () {
                                setState(() {
                                  _searchController.clear();
                                  _typeFilter = 'all';
                                  _categoryFilter = 'all';
                                  _monthOnly = false;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Transaksi',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  '${filteredTransactions.length} dari ${transactions.length}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (filteredTransactions.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: transactions.isEmpty
                            ? const _EmptyState()
                            : const _NoFilterResults(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        sliver: SliverList.separated(
                          itemCount: filteredTransactions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = filteredTransactions[index];
                            return _TransactionTile(
                              doc: doc,
                              rupiah: _rupiah,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(
                                      doc: doc,
                                      rupiah: _rupiah,
                                      onEdit: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddTransactionScreen(
                                              transactionId: doc.id,
                                              initialData: doc.data(),
                                            ),
                                          ),
                                        );
                                      },
                                      onDelete: () async {
                                        final deleted = await _deleteTransaction(
                                          context,
                                          doc,
                                        );
                                        if (deleted && context.mounted) {
                                          Navigator.pop(context);
                                        }
                                        return deleted;
                                      },
                                    ),
                                  ),
                                );
                              },
                              onEdit: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddTransactionScreen(
                                      transactionId: doc.id,
                                      initialData: doc.data(),
                                    ),
                                  ),
                                );
                              },
                              onDelete: () => _deleteTransaction(context, doc),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Transaksi'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
        },
      ),
    );
  }

  Future<bool> _deleteTransaction(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text('Transaksi "${doc.data()['title']}" akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    final receiptPath = doc.data()['receiptPath']?.toString();
    await _transactionsRef().doc(doc.id).delete();
    if (receiptPath != null && receiptPath.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(receiptPath).delete();
      } catch (_) {
        // Receipt may already be gone or blocked by storage rules.
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transaksi dihapus')));
    }

    return true;
  }
}

class _FilterPanel extends StatelessWidget {
  final TextEditingController searchController;
  final String typeFilter;
  final String categoryFilter;
  final bool monthOnly;
  final List<String> categories;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onMonthOnlyChanged;
  final VoidCallback onReset;

  const _FilterPanel({
    required this.searchController,
    required this.typeFilter,
    required this.categoryFilter,
    required this.monthOnly,
    required this.categories,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onMonthOnlyChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: const Icon(Icons.tune),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filter Transaksi',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Cari dan sortir data yang ingin dilihat',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Reset filter',
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Cari transaksi',
                hintText: 'Judul atau kategori',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 640;
                final typeSelector = SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    selected: {typeFilter},
                    segments: const [
                      ButtonSegment(
                        value: 'all',
                        icon: Icon(Icons.receipt_long_outlined),
                        label: Text('Semua'),
                      ),
                      ButtonSegment(
                        value: 'income',
                        icon: Icon(Icons.south_west),
                        label: Text('Masuk'),
                      ),
                      ButtonSegment(
                        value: 'expense',
                        icon: Icon(Icons.north_east),
                        label: Text('Keluar'),
                      ),
                    ],
                    onSelectionChanged: (value) => onTypeChanged(value.first),
                  ),
                );
                final categoryDropdown = DropdownButtonFormField<String>(
                  initialValue: categoryFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Semua')),
                    for (final category in categories)
                      DropdownMenuItem(value: category, child: Text(category)),
                  ],
                  onChanged: (value) {
                    if (value != null) onCategoryChanged(value);
                  },
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: typeSelector),
                      const SizedBox(width: 12),
                      Expanded(child: categoryDropdown),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    typeSelector,
                    const SizedBox(height: 12),
                    categoryDropdown,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulan ini saja',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Tampilkan transaksi pada bulan berjalan',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: monthOnly,
                    activeThumbColor: colors.primary,
                    onChanged: onMonthOnlyChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals {
  final int income;
  final int expense;

  const _Totals({required this.income, required this.expense});

  int get balance => income - expense;

  factory _Totals.from(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var income = 0;
    var expense = 0;

    for (final doc in docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toInt() ?? 0;
      if (data['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }

    return _Totals(income: income, expense: expense);
  }
}

class _UserHeader extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const _UserHeader({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final email = user.email ?? 'User';
    final name = user.displayName?.trim();
    final displayName = (name == null || name.isEmpty) ? email : name;
    final photoUrl = user.photoURL;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Text(displayName.characters.first.toUpperCase())
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo,',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (displayName != email)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBalanceCard extends StatelessWidget {
  final _Totals totals;
  final String Function(num value) rupiah;

  const _HeroBalanceCard({required this.totals, required this.rupiah});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo Saat Ini',
            style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 10),
          Text(
            rupiah(totals.balance),
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _MiniMetric(
                icon: Icons.arrow_downward,
                label: 'Masuk',
                value: rupiah(totals.income),
              ),
              const SizedBox(width: 12),
              _MiniMetric(
                icon: Icons.arrow_upward,
                label: 'Keluar',
                value: rupiah(totals.expense),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final int limit;
  final int spent;
  final String Function(num value) rupiah;
  final VoidCallback onEdit;

  const _BudgetCard({
    required this.limit,
    required this.spent,
    required this.rupiah,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasBudget = limit > 0;
    final progress = hasBudget ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final remaining = (limit - spent).clamp(0, limit);
    final danger = hasBudget && spent >= limit;
    final warning = hasBudget && spent >= limit * 0.8 && !danger;
    final progressColor = danger
        ? const Color(0xFFDC2626)
        : warning
        ? const Color(0xFFF59E0B)
        : colors.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: progressColor.withValues(alpha: 0.14),
                  foregroundColor: progressColor,
                  child: const Icon(Icons.savings_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Bulanan',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        hasBudget
                            ? '${rupiah(remaining)} tersisa'
                            : 'Belum ada limit budget',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Atur budget',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: hasBudget ? progress : 0,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${rupiah(spent)} terpakai',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  hasBudget ? rupiah(limit) : 'Atur sekarang',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final _Totals totals;
  final String Function(num value) rupiah;

  const _SummaryGrid({required this.totals, required this.rupiah});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Pemasukan',
            value: rupiah(totals.income),
            color: const Color(0xFF16A34A),
            icon: Icons.south_west,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            title: 'Pengeluaran',
            value: rupiah(totals.expense),
            color: const Color(0xFFEF4444),
            icon: Icons.north_east,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final _Totals totals;
  final String Function(num value) rupiah;

  const _ChartCard({required this.totals, required this.rupiah});

  @override
  Widget build(BuildContext context) {
    final maxValue = [
      totals.income,
      totals.expense,
      1,
    ].reduce((a, b) => a > b ? a : b).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grafik Cashflow',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            _BarRow(
              label: 'Pemasukan',
              value: totals.income,
              maxValue: maxValue,
              color: const Color(0xFF16A34A),
              rupiah: rupiah,
            ),
            const SizedBox(height: 14),
            _BarRow(
              label: 'Pengeluaran',
              value: totals.expense,
              maxValue: maxValue,
              color: const Color(0xFFEF4444),
              rupiah: rupiah,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int value;
  final double maxValue;
  final Color color;
  final String Function(num value) rupiah;

  const _BarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.rupiah,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value / maxValue).clamp(0.04, 1.0);
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              rupiah(value),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  height: 14,
                  width: constraints.maxWidth * percent,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DailyPoint {
  final String label;
  final int income;
  final int expense;

  const _DailyPoint({
    required this.label,
    required this.income,
    required this.expense,
  });

  static List<_DailyPoint> from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final days = List.generate(7, (index) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index));
      return day;
    });
    final incomeByDay = <String, int>{};
    final expenseByDay = <String, int>{};

    for (final doc in docs) {
      final data = doc.data();
      final date = _HomeScreenState._dateFromValue(data['date']);
      if (date == null) continue;
      final key = _dayKey(date);
      final amount = (data['amount'] as num?)?.toInt() ?? 0;

      if (data['type'] == 'income') {
        incomeByDay[key] = (incomeByDay[key] ?? 0) + amount;
      } else {
        expenseByDay[key] = (expenseByDay[key] ?? 0) + amount;
      }
    }

    return [
      for (final day in days)
        _DailyPoint(
          label: '${day.day}/${day.month}',
          income: incomeByDay[_dayKey(day)] ?? 0,
          expense: expenseByDay[_dayKey(day)] ?? 0,
        ),
    ];
  }

  static String _dayKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}

class _TrendChartCard extends StatelessWidget {
  final List<_DailyPoint> points;
  final String Function(num value) rupiah;

  const _TrendChartCard({required this.points, required this.rupiah});

  @override
  Widget build(BuildContext context) {
    final income = points.fold<int>(0, (total, point) => total + point.income);
    final expense = points.fold<int>(
      0,
      (total, point) => total + point.expense,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Grafik 7 Hari',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _LegendDot(color: const Color(0xFF16A34A), label: 'Masuk'),
                const SizedBox(width: 10),
                _LegendDot(color: const Color(0xFFEF4444), label: 'Keluar'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${rupiah(income)} masuk - ${rupiah(expense)} keluar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: CustomPaint(
                painter: _TrendChartPainter(
                  points: points,
                  incomeColor: const Color(0xFF16A34A),
                  expenseColor: const Color(0xFFEF4444),
                  axisColor: Theme.of(context).colorScheme.outlineVariant,
                  textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<_DailyPoint> points;
  final Color incomeColor;
  final Color expenseColor;
  final Color axisColor;
  final Color textColor;

  const _TrendChartPainter({
    required this.points,
    required this.incomeColor,
    required this.expenseColor,
    required this.axisColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const bottomSpace = 26.0;
    final chartHeight = size.height - bottomSpace;
    final maxValue = points
        .map(
          (point) =>
              point.income > point.expense ? point.income : point.expense,
        )
        .fold<int>(1, (max, value) => value > max ? value : max)
        .toDouble();
    final groupWidth = size.width / points.length;
    final barWidth = groupWidth * 0.22;
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = chartHeight * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), axisPaint);
    }

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final centerX = groupWidth * i + groupWidth / 2;
      _drawBar(
        canvas,
        centerX - barWidth - 2,
        chartHeight,
        barWidth,
        chartHeight * (point.income / maxValue),
        incomeColor,
      );
      _drawBar(
        canvas,
        centerX + 2,
        chartHeight,
        barWidth,
        chartHeight * (point.expense / maxValue),
        expenseColor,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: point.label,
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, chartHeight + 8),
      );
    }
  }

  void _drawBar(
    Canvas canvas,
    double x,
    double bottom,
    double width,
    double height,
    Color color,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, bottom - height, width, height),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.incomeColor != incomeColor ||
        oldDelegate.expenseColor != expenseColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.textColor != textColor;
  }
}

class _TransactionTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String Function(num value) rupiah;
  final VoidCallback onEdit;
  final Future<bool> Function() onDelete;
  final VoidCallback? onTap;

  const _TransactionTile({
    required this.doc,
    required this.rupiah,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final isIncome = data['type'] == 'income';
    final amount = (data['amount'] as num?) ?? 0;
    final date = _HomeScreenState._dateFromValue(data['date']);
    final category = data['category']?.toString().trim();
    final categoryLabel = (category == null || category.isEmpty)
        ? 'Lainnya'
        : category;
    final receiptUrl = data['receiptUrl']?.toString();
    final formattedDate = date == null
        ? '-'
        : '${date.day}/${date.month}/${date.year}';
    final color = isIncome ? const Color(0xFF16A34A) : const Color(0xFFEF4444);

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete, color: Color(0xFFEF4444)),
      ),
      confirmDismiss: (_) async {
        return await onDelete();
      },
      child: Card(
        child: ListTile(
          onTap: onTap ?? onEdit,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
            child: Icon(_categoryIcon(categoryLabel, isIncome)),
          ),
          title: Text(
            data['title']?.toString() ?? 'Tanpa judul',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$formattedDate • $categoryLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Chip(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                backgroundColor: color.withValues(alpha: 0.12),
                label: Text(
                  isIncome ? 'Pemasukan' : 'Pengeluaran',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (receiptUrl != null && receiptUrl.isNotEmpty)
                IconButton(
                  tooltip: 'Lihat nota',
                  icon: const Icon(Icons.image_outlined),
                  onPressed: () => _showReceipt(context, receiptUrl),
                ),
              Text(
                '${isIncome ? '+' : '-'} ${rupiah(amount)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category, bool isIncome) {
    switch (category) {
      case 'Gaji':
        return Icons.work_outline;
      case 'Bonus':
      case 'Hadiah':
        return Icons.card_giftcard;
      case 'Investasi':
        return Icons.show_chart;
      case 'Makanan':
        return Icons.restaurant_outlined;
      case 'Transportasi':
        return Icons.directions_car_outlined;
      case 'Belanja':
        return Icons.shopping_bag_outlined;
      case 'Tagihan':
        return Icons.receipt_long_outlined;
      case 'Hiburan':
        return Icons.movie_outlined;
      case 'Kesehatan':
        return Icons.health_and_safety_outlined;
      case 'Pendidikan':
        return Icons.school_outlined;
      default:
        return isIncome ? Icons.add : Icons.remove;
    }
  }

  void _showReceipt(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nota Transaksi',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 260,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nota tidak bisa dimuat'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada transaksi',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tambahkan pemasukan atau pengeluaran pertama kamu.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFilterResults extends StatelessWidget {
  const _NoFilterResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Transaksi tidak ditemukan',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba ubah kata kunci, tipe, kategori, atau filter bulan.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
