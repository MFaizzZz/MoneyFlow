import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionModel {
  final String id;
  final String title;
  final int amount;
  final String type;
  final String category;
  final DateTime date;
  final String? receiptUrl;
  final String? receiptPath;
  final String? userId;
  final String? userEmail;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.receiptUrl,
    this.receiptPath,
    this.userId,
    this.userEmail,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => !isIncome;

  factory TransactionModel.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return TransactionModel.fromMap(doc.id, doc.data());
  }

  factory TransactionModel.fromMap(String id, Map<String, dynamic> data) {
    final category = data['category']?.toString().trim();
    return TransactionModel(
      id: id,
      title: data['title']?.toString() ?? 'Tanpa judul',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      type: data['type']?.toString() == 'income' ? 'income' : 'expense',
      category: category == null || category.isEmpty ? 'Lainnya' : category,
      date: dateFromValue(data['date']) ?? DateTime.now(),
      receiptUrl: data['receiptUrl']?.toString(),
      receiptPath: data['receiptPath']?.toString(),
      userId: data['userId']?.toString(),
      userEmail: data['userEmail']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'userId': userId,
      'userEmail': userEmail,
      'date': Timestamp.fromDate(date),
      'dateText': dateText(date),
      'receiptUrl': receiptUrl,
      'receiptPath': receiptPath,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? dateFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class BudgetModel {
  final int monthlyLimit;
  final String? userId;

  const BudgetModel({required this.monthlyLimit, this.userId});

  factory BudgetModel.empty() {
    return const BudgetModel(monthlyLimit: 0);
  }

  factory BudgetModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return BudgetModel.empty();

    return BudgetModel(
      monthlyLimit: (data['monthlyLimit'] as num?)?.toInt() ?? 0,
      userId: data['userId']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'monthlyLimit': monthlyLimit,
      'userId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class UserProfileModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;

  const UserProfileModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  factory UserProfileModel.fromUser(User user) {
    final email = user.email ?? '';
    final name = user.displayName?.trim();
    return UserProfileModel(
      uid: user.uid,
      name: name == null || name.isEmpty ? email : name,
      email: email,
      photoUrl: user.photoURL,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class MonthlyReport {
  final int income;
  final int expense;
  final int budgetLimit;
  final String topExpenseCategory;
  final int topExpenseAmount;
  final Map<String, int> expenseByCategory;
  final List<TransactionModel> transactions;

  const MonthlyReport({
    required this.income,
    required this.expense,
    required this.budgetLimit,
    required this.topExpenseCategory,
    required this.topExpenseAmount,
    required this.expenseByCategory,
    required this.transactions,
  });

  int get balance => income - expense;
  int get remainingBudget => (budgetLimit - expense).clamp(0, budgetLimit);
  double get budgetProgress {
    if (budgetLimit <= 0) return 0;
    return (expense / budgetLimit).clamp(0, 1);
  }
}
