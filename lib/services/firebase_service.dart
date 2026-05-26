import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_models.dart';

const _defaultFirebaseStorageBucket = 'moneyflow-c9328.firebasestorage.app';

class TransactionService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  TransactionService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instanceFor(bucket: _defaultFirebaseStorageBucket);

  CollectionReference<Map<String, dynamic>> get _transactionsRef {
    return _firestore.collection('transactions');
  }

  Stream<List<TransactionModel>> watchTransactions(String uid) {
    return _transactionsRef.snapshots().map((snapshot) {
      final transactions = snapshot.docs
          .where((doc) {
            final userId = doc.data()['userId']?.toString();
            return userId == null || userId.isEmpty || userId == uid;
          })
          .map(TransactionModel.fromDoc)
          .toList();

      transactions.sort((a, b) => b.date.compareTo(a.date));
      return transactions;
    });
  }

  Future<void> saveTransaction({
    String? transactionId,
    required String uid,
    required String? email,
    required String title,
    required int amount,
    required String type,
    required String category,
    required DateTime date,
    Uint8List? receiptBytes,
    String? receiptName,
    String? receiptUrl,
    String? receiptPath,
    String? oldReceiptPath,
    bool removeExistingReceipt = false,
  }) async {
    var nextReceiptUrl = receiptUrl;
    var nextReceiptPath = receiptPath;

    if (receiptBytes != null) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${receiptName ?? 'nota.jpg'}';
      nextReceiptPath = 'receipts/$uid/$fileName';
      final ref = _storage.ref(nextReceiptPath);
      await ref.putData(
        receiptBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      nextReceiptUrl = await ref.getDownloadURL();
    }

    final transaction = TransactionModel(
      id: transactionId ?? '',
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      receiptUrl: nextReceiptUrl,
      receiptPath: nextReceiptPath,
      userId: uid,
      userEmail: email,
    );
    final payload = transaction.toFirestore();

    if (transactionId == null) {
      await _transactionsRef.add({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _transactionsRef.doc(transactionId).update(payload);
    }

    final shouldDeleteOldReceipt =
        (oldReceiptPath != null && oldReceiptPath != nextReceiptPath) ||
        (removeExistingReceipt && oldReceiptPath != null);
    if (shouldDeleteOldReceipt) {
      await deleteFileQuietly(oldReceiptPath);
    }
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    await _transactionsRef.doc(transaction.id).delete();
    await deleteFileQuietly(transaction.receiptPath);
  }

  Future<void> deleteFileQuietly(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await _storage.ref(path).delete();
    } catch (_) {
      // The file may already be removed or blocked by storage rules.
    }
  }
}

class BudgetService {
  final FirebaseFirestore _firestore;

  BudgetService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _budgetRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('budget');
  }

  Stream<BudgetModel> watchBudget(String uid) {
    return _budgetRef(uid).snapshots().map(BudgetModel.fromSnapshot);
  }

  Future<void> saveBudget(String uid, int monthlyLimit) async {
    await _budgetRef(uid).set(
      BudgetModel(monthlyLimit: monthlyLimit, userId: uid).toFirestore(),
      SetOptions(merge: true),
    );
  }
}

class ProfileService {
  final FirebaseFirestore _firestore;

  ProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> updateProfile({
    required User user,
    required String name,
  }) async {
    await user.updateDisplayName(name);
    await user.reload();

    final profile = UserProfileModel(
      uid: user.uid,
      name: name,
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(profile.toFirestore(), SetOptions(merge: true));
  }

  static String _contentTypeFromFileName(String? fileName) {
    final extension = (fileName ?? '').split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}

class ReportService {
  MonthlyReport buildMonthlyReport({
    required List<TransactionModel> transactions,
    required int budgetLimit,
    DateTime? month,
  }) {
    final selectedMonth = month ?? DateTime.now();
    final monthlyTransactions = transactions.where((transaction) {
      return transaction.date.year == selectedMonth.year &&
          transaction.date.month == selectedMonth.month;
    }).toList();

    var income = 0;
    var expense = 0;
    final expenseByCategory = <String, int>{};

    for (final transaction in monthlyTransactions) {
      if (transaction.isIncome) {
        income += transaction.amount;
      } else {
        expense += transaction.amount;
        expenseByCategory[transaction.category] =
            (expenseByCategory[transaction.category] ?? 0) + transaction.amount;
      }
    }

    var topCategory = 'Belum ada';
    var topAmount = 0;
    for (final entry in expenseByCategory.entries) {
      if (entry.value > topAmount) {
        topCategory = entry.key;
        topAmount = entry.value;
      }
    }

    final sortedCategories = Map.fromEntries(
      expenseByCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );

    return MonthlyReport(
      income: income,
      expense: expense,
      budgetLimit: budgetLimit,
      topExpenseCategory: topCategory,
      topExpenseAmount: topAmount,
      expenseByCategory: sortedCategories,
      transactions: monthlyTransactions,
    );
  }
}
