import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/firebase_service.dart';

class ReportScreen extends StatelessWidget {
  ReportScreen({super.key});

  final _transactionService = TransactionService();
  final _budgetService = BudgetService();
  final _reportService = ReportService();

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

  String _monthLabel(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Belum login')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Bulanan')),
      body: StreamBuilder<BudgetModel>(
        stream: _budgetService.watchBudget(user.uid),
        builder: (context, budgetSnapshot) {
          if (budgetSnapshot.hasError) {
            return Center(
              child: Text('Gagal memuat budget: ${budgetSnapshot.error}'),
            );
          }
          if (!budgetSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<TransactionModel>>(
            stream: _transactionService.watchTransactions(user.uid),
            builder: (context, transactionSnapshot) {
              if (transactionSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Gagal memuat laporan: ${transactionSnapshot.error}',
                  ),
                );
              }
              if (!transactionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final report = _reportService.buildMonthlyReport(
                transactions: transactionSnapshot.data!,
                budgetLimit: budgetSnapshot.data!.monthlyLimit,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _ReportHero(
                    month: _monthLabel(DateTime.now()),
                    report: report,
                    rupiah: _rupiah,
                  ),
                  const SizedBox(height: 14),
                  _MetricGrid(report: report, rupiah: _rupiah),
                  const SizedBox(height: 14),
                  _CategoryBreakdown(report: report, rupiah: _rupiah),
                  const SizedBox(height: 14),
                  _RecentMonthlyTransactions(
                    transactions: report.transactions,
                    rupiah: _rupiah,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  final String month;
  final MonthlyReport report;
  final String Function(num value) rupiah;

  const _ReportHero({
    required this.month,
    required this.report,
    required this.rupiah,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progressColor =
        report.budgetLimit > 0 && report.expense >= report.budgetLimit
        ? const Color(0xFFDC2626)
        : colors.primary;

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
            month,
            style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 8),
          Text(
            rupiah(report.balance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Saldo bersih bulan ini',
            style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: report.budgetProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.budgetLimit > 0
                ? '${rupiah(report.expense)} dari ${rupiah(report.budgetLimit)}'
                : 'Budget belum diatur',
            style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.82)),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final MonthlyReport report;
  final String Function(num value) rupiah;

  const _MetricGrid({required this.report, required this.rupiah});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        final cards = [
          _MetricCard(
            title: 'Pemasukan',
            value: rupiah(report.income),
            icon: Icons.south_west,
            color: const Color(0xFF16A34A),
          ),
          _MetricCard(
            title: 'Pengeluaran',
            value: rupiah(report.expense),
            icon: Icons.north_east,
            color: const Color(0xFFEF4444),
          ),
          _MetricCard(
            title: 'Kategori Terboros',
            value: report.topExpenseCategory,
            subtitle: rupiah(report.topExpenseAmount),
            icon: Icons.local_fire_department_outlined,
            color: const Color(0xFFF59E0B),
          ),
          _MetricCard(
            title: 'Sisa Budget',
            value: report.budgetLimit > 0
                ? rupiah(report.remainingBudget)
                : '-',
            icon: Icons.savings_outlined,
            color: colors.primary,
          ),
        ];

        if (wide) {
          return GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: cards,
          );
        }

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.18,
          children: cards,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const Spacer(),
            Text(title, style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final MonthlyReport report;
  final String Function(num value) rupiah;

  const _CategoryBreakdown({required this.report, required this.rupiah});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxValue = report.expenseByCategory.values.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengeluaran per Kategori',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            if (report.expenseByCategory.isEmpty)
              Text(
                'Belum ada pengeluaran bulan ini.',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              for (final entry in report.expenseByCategory.entries) ...[
                Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Text(
                      rupiah(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: entry.value / maxValue,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _RecentMonthlyTransactions extends StatelessWidget {
  final List<TransactionModel> transactions;
  final String Function(num value) rupiah;

  const _RecentMonthlyTransactions({
    required this.transactions,
    required this.rupiah,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final latest = transactions.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaksi Bulan Ini',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (latest.isEmpty)
              Text(
                'Belum ada transaksi bulan ini.',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              for (final transaction in latest)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        (transaction.isIncome
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEF4444))
                            .withValues(alpha: 0.14),
                    foregroundColor: transaction.isIncome
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEF4444),
                    child: Icon(
                      transaction.isIncome ? Icons.add : Icons.remove,
                    ),
                  ),
                  title: Text(
                    transaction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(transaction.category),
                  trailing: Text(
                    '${transaction.isIncome ? '+' : '-'} ${rupiah(transaction.amount)}',
                    style: TextStyle(
                      color: transaction.isIncome
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEF4444),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
