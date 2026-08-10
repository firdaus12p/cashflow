import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fl_chart/fl_chart.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  static String format(int value) {
    final reversed = value.toString().split('').reversed.toList();
    final result = <String>[];
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) result.add('.');
      result.add(reversed[i]);
    }
    return result.reversed.join();
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = CurrencyInputFormatter.format(int.parse(digits));
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

double parseCurrencyInput(String input) {
  return tryParseCurrencyInput(input) ?? 0;
}

double? tryParseCurrencyInput(String input) {
  final digits = input.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return null;
  return double.tryParse(digits);
}

final NumberFormat _rupiahNumberFormatter =
    NumberFormat.decimalPattern('id_ID');

String formatRupiahValue(num amount) {
  return _rupiahNumberFormatter.format(amount.round());
}

String formatRupiah(num amount) {
  return 'Rp ${formatRupiahValue(amount)}';
}

({DateTime start, DateTime end}) resolveHomeFilterRange(
  String filter,
  DateTime referenceDate,
) {
  switch (filter) {
    case 'daily':
      return (
        start: DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
        ),
        end: DateTime(
          referenceDate.year,
          referenceDate.month,
          referenceDate.day,
          23,
          59,
          59,
        ),
      );
    case 'yearly':
      return (
        start: DateTime(referenceDate.year, 1, 1),
        end: DateTime(referenceDate.year, 12, 31, 23, 59, 59),
      );
    case 'monthly':
    default:
      return (
        start: DateTime(referenceDate.year, referenceDate.month, 1),
        end: DateTime(
            referenceDate.year, referenceDate.month + 1, 0, 23, 59, 59),
      );
  }
}

double calculateMonthlyExpenseForInsight(
  List<Transaction> transactions,
  DateTime referenceDate, {
  String selectedWallet = 'All',
}) {
  final thisMonthStart = DateTime(referenceDate.year, referenceDate.month, 1);
  final thisMonthEnd =
      DateTime(referenceDate.year, referenceDate.month + 1, 0, 23, 59, 59);

  return transactions
      .where((t) =>
          t.affectsBalance &&
          t.category != _internalTransferCategory &&
          t.type == 'expense' &&
          (selectedWallet == 'All' || t.wallet == selectedWallet) &&
          t.date.isAfter(thisMonthStart.subtract(const Duration(seconds: 1))) &&
          t.date.isBefore(thisMonthEnd.add(const Duration(seconds: 1))))
      .fold(0.0, (sum, t) => sum + t.amount);
}

double calculateBalanceForWallet(
  Iterable<Transaction> transactions, {
  String selectedWallet = 'All',
}) {
  return transactions
      .where((transaction) =>
          transaction.affectsBalance &&
          (selectedWallet == 'All' || transaction.wallet == selectedWallet))
      .fold<double>(0, (sum, transaction) {
    return sum +
        (transaction.type == 'income'
            ? transaction.amount
            : -transaction.amount);
  });
}

Iterable<Transaction> affectingTransactions(
    Iterable<Transaction> transactions) {
  return transactions.where((transaction) => transaction.affectsBalance);
}

Iterable<Transaction> userVisibleBalanceTransactions(
    Iterable<Transaction> transactions) {
  return transactions.where((transaction) =>
      transaction.affectsBalance &&
      transaction.category != _internalTransferCategory);
}

bool hasSavingBadgeForPeriod(List<UserBadge> badges, DateTime referenceDate) {
  return badges.any((badge) =>
      badge.type == 'saving' &&
      badge.earnedDate.year == referenceDate.year &&
      badge.earnedDate.month == referenceDate.month);
}

String formatSelectedDateRangeLabel(DateTimeRange range) {
  final startMonth = DateFormat('MMM').format(range.start);
  final endMonth = DateFormat('MMM').format(range.end);

  if (range.start.year == range.end.year &&
      range.start.month == range.end.month) {
    return '$startMonth ${range.start.day} - ${range.end.day}, ${range.end.year}';
  }

  if (range.start.year == range.end.year) {
    return '$startMonth ${range.start.day} - $endMonth ${range.end.day}, ${range.end.year}';
  }

  return '$startMonth ${range.start.day}, ${range.start.year} - $endMonth ${range.end.day}, ${range.end.year}';
}

// BR-08: total persentase pos aktif harus tepat 100% (toleransi floating point ±0.01)
const double _bucketPercentageTolerance = 0.01;

double getBucketPercentageTotal(List<FinancialBucket> buckets) {
  return buckets.fold(0.0, (sum, b) => sum + b.allocationPercentage);
}

bool validateBucketPercentages(List<FinancialBucket> buckets) {
  if (buckets.isEmpty) return false;
  final total = getBucketPercentageTotal(buckets);
  return (total - 100.0).abs() <= _bucketPercentageTolerance;
}

bool canSaveBucketPercentages(List<FinancialBucket> buckets) {
  if (buckets.isEmpty) return false;
  return getBucketPercentageTotal(buckets) <=
      100.0 + _bucketPercentageTolerance;
}

bool hasIncompleteBucketConfiguration(List<FinancialBucket> buckets) {
  return buckets.isNotEmpty && !validateBucketPercentages(buckets);
}

const String _bucketConfigurationIncompleteText = 'Pos keuangan belum 100%';
const String _bucketConfigurationIncompleteMessage =
    'Pos keuangan belum 100%. Selesaikan dulu di halaman Pos Keuangan.';
const String _internalTransferCategory = 'Transfer Internal';

const String _homeBalanceSourceTypePreferenceKey = 'homeBalanceSourceType';
const String _homeBalanceSourceIdPreferenceKey = 'homeBalanceSourceId';
const String _homeBalanceVisibilityHiddenPreferenceKey =
    'homeBalanceVisibilityHidden';

// BR-09: normalisasi persentase subset pos ke 100%
// Mengembalikan Map<bucketId, normalizedPercentage>
Map<int, double> normalizeSubsetAllocation(List<FinancialBucket> subset) {
  if (subset.isEmpty) return {};
  final totalPct = subset.fold(0.0, (s, b) => s + b.allocationPercentage);
  return {
    for (final b in subset) b.id!: (b.allocationPercentage / totalPct) * 100,
  };
}

// Distribusikan amount ke subset pos sesuai persentase yang sudah dinormalisasi.
// Mengembalikan Map<bucketId, allocatedAmount>
Map<int, double> allocateIncomeToBuckets(
    double amount, List<FinancialBucket> subset) {
  if (subset.isEmpty || amount == 0) {
    return {for (final b in subset) b.id!: 0.0};
  }
  final normalized = normalizeSubsetAllocation(subset);
  return {
    for (final entry in normalized.entries)
      entry.key: amount * entry.value / 100,
  };
}

bool bucketsShareSameWallet(List<FinancialBucket> buckets) {
  if (buckets.isEmpty) return false;
  final firstWalletId = buckets.first.walletId;
  if (firstWalletId == null) return false;
  return buckets.every((bucket) => bucket.walletId == firstWalletId);
}

typedef HomeBalanceSourceResolution = ({String type, int? id, String title});

Wallet? _findWalletInList(Iterable<Wallet> wallets, int? walletId) {
  if (walletId == null) return null;
  for (final wallet in wallets) {
    if (wallet.id == walletId) return wallet;
  }
  return null;
}

FinancialBucket? _findBucketInList(
    Iterable<FinancialBucket> buckets, int? bucketId) {
  if (bucketId == null) return null;
  for (final bucket in buckets) {
    if (bucket.id == bucketId) return bucket;
  }
  return null;
}

HomeBalanceSourceResolution resolveHomeBalanceSource(
  String preferenceType,
  int? preferenceId,
  List<Wallet> wallets,
  List<FinancialBucket> buckets,
) {
  switch (preferenceType) {
    case 'wallet':
      final wallet = _findWalletInList(wallets, preferenceId);
      if (wallet != null) {
        return (type: 'wallet', id: wallet.id, title: 'Saldo ${wallet.name}');
      }
      break;
    case 'bucket':
      final bucket = _findBucketInList(buckets, preferenceId);
      if (bucket != null) {
        return (type: 'bucket', id: bucket.id, title: 'Saldo ${bucket.name}');
      }
      break;
  }

  // Fallback eksplisit bila source tersimpan sudah hilang/tidak valid.
  return (type: 'total', id: null, title: 'Total Saldo');
}

class ChartSeriesData {
  const ChartSeriesData({
    required this.title,
    required this.subtitle,
    required this.legend,
    required this.labels,
    required this.values,
  });

  final String title;
  final String subtitle;
  final String legend;
  final List<String> labels;
  final List<double> values;
}

void main() {
  runApp(const CashflowApp());
}

class CashflowApp extends StatelessWidget {
  const CashflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cashflow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.pink,
        fontFamily: GoogleFonts.poppins().fontFamily,
        scaffoldBackgroundColor: const Color(0xFFFFF0F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF69B4),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// Model Classes
class Transaction {
  final int? id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final String wallet;
  final int? walletId;
  final String walletNameSnapshot;
  final bool affectsBalance;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    this.wallet = 'Cash',
    this.walletId,
    this.walletNameSnapshot = '',
    this.affectsBalance = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'wallet': wallet,
      'walletId': walletId,
      'walletNameSnapshot': walletNameSnapshot,
      'affectsBalance': affectsBalance ? 1 : 0,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      type: map['type'],
      amount: map['amount'],
      category: map['category'],
      description: map['description'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      wallet: map['wallet'] ?? 'Cash',
      walletId: map['walletId'],
      walletNameSnapshot: map['walletNameSnapshot'] ?? '',
      affectsBalance: (map['affectsBalance'] ?? 1) == 1,
    );
  }
}

class SavingGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String emoji;
  final String? iconKey;
  final DateTime createdDate;
  final DateTime? targetDate;

  SavingGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.emoji = '💰',
    this.iconKey,
    required this.createdDate,
    this.targetDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'emoji': emoji,
      'iconKey': iconKey,
      'createdDate': createdDate.millisecondsSinceEpoch,
      'targetDate': targetDate?.millisecondsSinceEpoch,
    };
  }

  factory SavingGoal.fromMap(Map<String, dynamic> map) {
    return SavingGoal(
      id: map['id'],
      name: map['name'],
      targetAmount: map['targetAmount'],
      currentAmount: map['currentAmount'] ?? 0,
      emoji: map['emoji'] ?? '💰',
      iconKey: map['iconKey'],
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
      targetDate: map['targetDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['targetDate'])
          : null,
    );
  }

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  // fallback ke emoji untuk record lama yang belum punya iconKey
  String get effectiveIcon => iconKey ?? emoji;
}

class WishlistItem {
  final int? id;
  final String name;
  final double price;
  final String emoji;
  final String? iconKey;
  final String priority; // 'low', 'medium', 'high'
  final DateTime createdDate;

  WishlistItem({
    this.id,
    required this.name,
    required this.price,
    this.emoji = '🛍️',
    this.iconKey,
    this.priority = 'medium',
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'emoji': emoji,
      'iconKey': iconKey,
      'priority': priority,
      'createdDate': createdDate.millisecondsSinceEpoch,
    };
  }

  factory WishlistItem.fromMap(Map<String, dynamic> map) {
    return WishlistItem(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      emoji: map['emoji'] ?? '🛍️',
      iconKey: map['iconKey'],
      priority: map['priority'] ?? 'medium',
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
    );
  }

  String get effectiveIcon => iconKey ?? emoji;
}

class UserBadge {
  final int? id;
  final String name;
  final String description;
  final String emoji;
  final String? iconKey;
  final DateTime earnedDate;
  final String type; // 'saving', 'spending', 'streak', 'goal'

  UserBadge({
    this.id,
    required this.name,
    required this.description,
    required this.emoji,
    this.iconKey,
    required this.earnedDate,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      'iconKey': iconKey,
      'earnedDate': earnedDate.millisecondsSinceEpoch,
      'type': type,
    };
  }

  factory UserBadge.fromMap(Map<String, dynamic> map) {
    return UserBadge(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      emoji: map['emoji'],
      iconKey: map['iconKey'],
      earnedDate: DateTime.fromMillisecondsSinceEpoch(map['earnedDate']),
      type: map['type'],
    );
  }

  String get effectiveIcon => iconKey ?? emoji;
}

// --- New domain models (v3) ---

class Wallet {
  final int? id;
  final String name;
  final String? iconKey;
  final String? color;
  final bool isArchived;
  final DateTime createdDate;
  final DateTime updatedDate;

  Wallet({
    this.id,
    required this.name,
    this.iconKey,
    this.color,
    this.isArchived = false,
    required this.createdDate,
    required this.updatedDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'color': color,
        'isArchived': isArchived ? 1 : 0,
        'createdDate': createdDate.millisecondsSinceEpoch,
        'updatedDate': updatedDate.millisecondsSinceEpoch,
      };

  factory Wallet.fromMap(Map<String, dynamic> map) => Wallet(
        id: map['id'],
        name: map['name'],
        iconKey: map['iconKey'],
        color: map['color'],
        isArchived: (map['isArchived'] ?? 0) == 1,
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
        updatedDate: DateTime.fromMillisecondsSinceEpoch(map['updatedDate']),
      );
}

const Map<String, IconData> _availableWalletIcons = {
  'cash': Icons.payments_outlined,
  'e_wallet': Icons.phone_android_outlined,
  'bank': Icons.account_balance_outlined,
  'savings': Icons.savings_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'card': Icons.credit_card_outlined,
};

const Map<String, IconData> _availableBucketIcons = {
  'savings': Icons.savings_outlined,
  'giving': Icons.volunteer_activism_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'health': Icons.health_and_safety_outlined,
  'home': Icons.home_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'chart': Icons.pie_chart_outline,
};

IconData resolveWalletIcon(String? iconKey, String fallbackName) {
  if (iconKey != null && _availableWalletIcons.containsKey(iconKey)) {
    return _availableWalletIcons[iconKey]!;
  }

  switch (fallbackName) {
    case 'Cash':
      return Icons.payments_outlined;
    case 'E-Wallet':
      return Icons.phone_android_outlined;
    case 'Bank':
      return Icons.account_balance_outlined;
    case 'Tabungan':
      return Icons.savings_outlined;
    default:
      return Icons.account_balance_wallet_outlined;
  }
}

IconData resolveBucketIcon(String? iconKey) {
  if (iconKey != null && _availableBucketIcons.containsKey(iconKey)) {
    return _availableBucketIcons[iconKey]!;
  }
  return Icons.pie_chart_outline;
}

class Debt {
  final int? id;
  final String type; // 'debt' or 'receivable'
  final String personName;
  final double principalAmount;
  final double remainingAmount;
  final DateTime borrowedDate;
  final DateTime? dueDate;
  final String recordingMode; // 'balance' or 'note'
  final int? walletId;
  final int? bucketId;
  final String? note;
  final String status; // 'active' or 'settled'
  final DateTime createdDate;
  final DateTime updatedDate;

  Debt({
    this.id,
    required this.type,
    required this.personName,
    required this.principalAmount,
    required this.remainingAmount,
    required this.borrowedDate,
    this.dueDate,
    required this.recordingMode,
    this.walletId,
    this.bucketId,
    this.note,
    this.status = 'active',
    required this.createdDate,
    required this.updatedDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'personName': personName,
        'principalAmount': principalAmount,
        'remainingAmount': remainingAmount,
        'borrowedDate': borrowedDate.millisecondsSinceEpoch,
        'dueDate': dueDate?.millisecondsSinceEpoch,
        'recordingMode': recordingMode,
        'walletId': walletId,
        'bucketId': bucketId,
        'note': note,
        'status': status,
        'createdDate': createdDate.millisecondsSinceEpoch,
        'updatedDate': updatedDate.millisecondsSinceEpoch,
      };

  factory Debt.fromMap(Map<String, dynamic> map) => Debt(
        id: map['id'],
        type: map['type'],
        personName: map['personName'],
        principalAmount: map['principalAmount'],
        remainingAmount: map['remainingAmount'],
        borrowedDate: DateTime.fromMillisecondsSinceEpoch(map['borrowedDate']),
        dueDate: map['dueDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'])
            : null,
        recordingMode: map['recordingMode'],
        walletId: map['walletId'],
        bucketId: map['bucketId'],
        note: map['note'],
        status: map['status'] ?? 'active',
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
        updatedDate: DateTime.fromMillisecondsSinceEpoch(map['updatedDate']),
      );

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      remainingAmount > 0 &&
      status == 'active';

  double get progressFraction => principalAmount > 0
      ? ((principalAmount - remainingAmount) / principalAmount).clamp(0.0, 1.0)
      : 0.0;
}

class DebtPayment {
  final int? id;
  final int debtId;
  final double amount;
  final DateTime paymentDate;
  final String recordingMode;
  final int? walletId;
  final int? bucketId;
  final String? note;
  final DateTime createdDate;

  DebtPayment({
    this.id,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    required this.recordingMode,
    this.walletId,
    this.bucketId,
    this.note,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'debtId': debtId,
        'amount': amount,
        'paymentDate': paymentDate.millisecondsSinceEpoch,
        'recordingMode': recordingMode,
        'walletId': walletId,
        'bucketId': bucketId,
        'note': note,
        'createdDate': createdDate.millisecondsSinceEpoch,
      };

  factory DebtPayment.fromMap(Map<String, dynamic> map) => DebtPayment(
        id: map['id'],
        debtId: map['debtId'],
        amount: map['amount'],
        paymentDate: DateTime.fromMillisecondsSinceEpoch(map['paymentDate']),
        recordingMode: map['recordingMode'],
        walletId: map['walletId'],
        bucketId: map['bucketId'],
        note: map['note'],
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
      );
}

class FinancialBucket {
  final int? id;
  final String name;
  final String? iconKey;
  final int? walletId;
  final double allocationPercentage;
  final double currentBalance;
  final bool isArchived;
  final DateTime createdDate;
  final DateTime updatedDate;

  FinancialBucket({
    this.id,
    required this.name,
    this.iconKey,
    this.walletId,
    this.allocationPercentage = 0,
    this.currentBalance = 0,
    this.isArchived = false,
    required this.createdDate,
    required this.updatedDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'walletId': walletId,
        'allocationPercentage': allocationPercentage,
        'currentBalance': currentBalance,
        'isArchived': isArchived ? 1 : 0,
        'createdDate': createdDate.millisecondsSinceEpoch,
        'updatedDate': updatedDate.millisecondsSinceEpoch,
      };

  factory FinancialBucket.fromMap(Map<String, dynamic> map) => FinancialBucket(
        id: map['id'],
        name: map['name'],
        iconKey: map['iconKey'],
        walletId: map['walletId'],
        allocationPercentage: map['allocationPercentage'] ?? 0,
        currentBalance: map['currentBalance'] ?? 0,
        isArchived: (map['isArchived'] ?? 0) == 1,
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
        updatedDate: DateTime.fromMillisecondsSinceEpoch(map['updatedDate']),
      );

  IconData get resolvedIcon => resolveBucketIcon(iconKey);
}

class TransactionBucketAllocation {
  final int? id;
  final int transactionId;
  final int bucketId;
  final double normalizedPercentage;
  final double allocatedAmount;
  final String role; // 'source' or 'target'
  final DateTime createdDate;

  TransactionBucketAllocation({
    this.id,
    required this.transactionId,
    required this.bucketId,
    required this.normalizedPercentage,
    required this.allocatedAmount,
    required this.role,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'transactionId': transactionId,
        'bucketId': bucketId,
        'normalizedPercentage': normalizedPercentage,
        'allocatedAmount': allocatedAmount,
        'role': role,
        'createdDate': createdDate.millisecondsSinceEpoch,
      };

  factory TransactionBucketAllocation.fromMap(Map<String, dynamic> map) =>
      TransactionBucketAllocation(
        id: map['id'],
        transactionId: map['transactionId'],
        bucketId: map['bucketId'],
        normalizedPercentage: map['normalizedPercentage'],
        allocatedAmount: map['allocatedAmount'],
        role: map['role'],
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
      );
}

class BucketTransfer {
  final int? id;
  final int fromBucketId;
  final int toBucketId;
  final int? fromWalletIdSnapshot;
  final int? toWalletIdSnapshot;
  final double amount;
  final String? note;
  final DateTime transferDate;
  final DateTime createdDate;

  BucketTransfer({
    this.id,
    required this.fromBucketId,
    required this.toBucketId,
    this.fromWalletIdSnapshot,
    this.toWalletIdSnapshot,
    required this.amount,
    this.note,
    required this.transferDate,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromBucketId': fromBucketId,
        'toBucketId': toBucketId,
        'fromWalletIdSnapshot': fromWalletIdSnapshot,
        'toWalletIdSnapshot': toWalletIdSnapshot,
        'amount': amount,
        'note': note,
        'transferDate': transferDate.millisecondsSinceEpoch,
        'createdDate': createdDate.millisecondsSinceEpoch,
      };

  factory BucketTransfer.fromMap(Map<String, dynamic> map) => BucketTransfer(
        id: map['id'],
        fromBucketId: map['fromBucketId'],
        toBucketId: map['toBucketId'],
        fromWalletIdSnapshot: map['fromWalletIdSnapshot'],
        toWalletIdSnapshot: map['toWalletIdSnapshot'],
        amount: map['amount'],
        note: map['note'],
        transferDate: DateTime.fromMillisecondsSinceEpoch(map['transferDate']),
        createdDate: DateTime.fromMillisecondsSinceEpoch(map['createdDate']),
      );
}

// Enhanced Database Helper
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static String? _overridePath;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  @visibleForTesting
  static void overrideDatabasePath(String path) {
    _overridePath = path;
    _database = null;
  }

  @visibleForTesting
  static Future<void> closeDatabase() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path =
        _overridePath ?? p.join(await getDatabasesPath(), 'money_tracker.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        date INTEGER NOT NULL,
        wallet TEXT DEFAULT 'Cash',
        walletId INTEGER,
        walletNameSnapshot TEXT DEFAULT '',
        affectsBalance INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE saving_goals(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        targetAmount REAL NOT NULL,
        currentAmount REAL DEFAULT 0,
        emoji TEXT DEFAULT '💰',
        iconKey TEXT,
        createdDate INTEGER NOT NULL,
        targetDate INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE wishlist(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        emoji TEXT DEFAULT '🛍️',
        iconKey TEXT,
        priority TEXT DEFAULT 'medium',
        createdDate INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE badges(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        emoji TEXT NOT NULL,
        iconKey TEXT,
        earnedDate INTEGER NOT NULL,
        type TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE wallets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        iconKey TEXT,
        color TEXT,
        isArchived INTEGER DEFAULT 0,
        createdDate INTEGER NOT NULL,
        updatedDate INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        personName TEXT NOT NULL,
        principalAmount REAL NOT NULL,
        remainingAmount REAL NOT NULL,
        borrowedDate INTEGER NOT NULL,
        dueDate INTEGER,
        recordingMode TEXT NOT NULL,
        walletId INTEGER,
        bucketId INTEGER,
        note TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        createdDate INTEGER NOT NULL,
        updatedDate INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debt_payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debtId INTEGER NOT NULL,
        amount REAL NOT NULL,
        paymentDate INTEGER NOT NULL,
        recordingMode TEXT NOT NULL,
        walletId INTEGER,
        bucketId INTEGER,
        note TEXT,
        createdDate INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE financial_buckets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        iconKey TEXT,
        walletId INTEGER,
        allocationPercentage REAL NOT NULL DEFAULT 0,
        currentBalance REAL NOT NULL DEFAULT 0,
        isArchived INTEGER DEFAULT 0,
        createdDate INTEGER NOT NULL,
        updatedDate INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_bucket_allocations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId INTEGER NOT NULL,
        bucketId INTEGER NOT NULL,
        normalizedPercentage REAL NOT NULL,
        allocatedAmount REAL NOT NULL,
        role TEXT NOT NULL,
        createdDate INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bucket_transfers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fromBucketId INTEGER NOT NULL,
        toBucketId INTEGER NOT NULL,
        fromWalletIdSnapshot INTEGER,
        toWalletIdSnapshot INTEGER,
        amount REAL NOT NULL,
        note TEXT,
        transferDate INTEGER NOT NULL,
        createdDate INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_preferences(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updatedDate INTEGER NOT NULL
      )
    ''');

    await _seedDefaultWallets(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN wallet TEXT DEFAULT "Cash"');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS saving_goals(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          targetAmount REAL NOT NULL,
          currentAmount REAL DEFAULT 0,
          emoji TEXT DEFAULT '💰',
          createdDate INTEGER NOT NULL,
          targetDate INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS wishlist(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          emoji TEXT DEFAULT '🛍️',
          priority TEXT DEFAULT 'medium',
          createdDate INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS badges(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          emoji TEXT NOT NULL,
          earnedDate INTEGER NOT NULL,
          type TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // transactions: wallet alignment and balance tracking
      await db.execute('ALTER TABLE transactions ADD COLUMN walletId INTEGER');
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN walletNameSnapshot TEXT DEFAULT ''");
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN affectsBalance INTEGER DEFAULT 1');

      // icon migration parallel fields
      await db.execute('ALTER TABLE saving_goals ADD COLUMN iconKey TEXT');
      await db.execute('ALTER TABLE wishlist ADD COLUMN iconKey TEXT');
      await db.execute('ALTER TABLE badges ADD COLUMN iconKey TEXT');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS wallets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          iconKey TEXT,
          color TEXT,
          isArchived INTEGER DEFAULT 0,
          createdDate INTEGER NOT NULL,
          updatedDate INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS debts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          personName TEXT NOT NULL,
          principalAmount REAL NOT NULL,
          remainingAmount REAL NOT NULL,
          borrowedDate INTEGER NOT NULL,
          dueDate INTEGER,
          recordingMode TEXT NOT NULL,
          walletId INTEGER,
          bucketId INTEGER,
          note TEXT,
          status TEXT NOT NULL DEFAULT 'active',
          createdDate INTEGER NOT NULL,
          updatedDate INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS debt_payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          debtId INTEGER NOT NULL,
          amount REAL NOT NULL,
          paymentDate INTEGER NOT NULL,
          recordingMode TEXT NOT NULL,
          walletId INTEGER,
          bucketId INTEGER,
          note TEXT,
          createdDate INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS financial_buckets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          iconKey TEXT,
          allocationPercentage REAL NOT NULL DEFAULT 0,
          currentBalance REAL NOT NULL DEFAULT 0,
          isArchived INTEGER DEFAULT 0,
          createdDate INTEGER NOT NULL,
          updatedDate INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS transaction_bucket_allocations(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transactionId INTEGER NOT NULL,
          bucketId INTEGER NOT NULL,
          normalizedPercentage REAL NOT NULL,
          allocatedAmount REAL NOT NULL,
          role TEXT NOT NULL,
          createdDate INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS bucket_transfers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fromBucketId INTEGER NOT NULL,
          toBucketId INTEGER NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          transferDate INTEGER NOT NULL,
          createdDate INTEGER NOT NULL
        )
      ''');

      await _seedDefaultWallets(db);
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_preferences(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updatedDate INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 5) {
      await db
          .execute('ALTER TABLE financial_buckets ADD COLUMN walletId INTEGER');
      await db.execute(
          'ALTER TABLE bucket_transfers ADD COLUMN fromWalletIdSnapshot INTEGER');
      await db.execute(
          'ALTER TABLE bucket_transfers ADD COLUMN toWalletIdSnapshot INTEGER');
      await _backfillBucketWalletIds(db);
    }
  }

  Future<int?> _resolveDefaultBucketWalletId(DatabaseExecutor executor) async {
    final cashRows = await executor.query(
      'wallets',
      columns: ['id'],
      where: 'name = ? AND isArchived = 0',
      whereArgs: ['Cash'],
      limit: 1,
    );
    if (cashRows.isNotEmpty) {
      return cashRows.first['id'] as int?;
    }

    final firstActiveWallet = await executor.query(
      'wallets',
      columns: ['id'],
      where: 'isArchived = 0',
      orderBy: 'createdDate ASC',
      limit: 1,
    );
    if (firstActiveWallet.isNotEmpty) {
      return firstActiveWallet.first['id'] as int?;
    }

    return null;
  }

  Future<void> _backfillBucketWalletIds(DatabaseExecutor executor) async {
    final fallbackWalletId = await _resolveDefaultBucketWalletId(executor);
    if (fallbackWalletId == null) return;

    final bucketRows = await executor.query(
      'financial_buckets',
      columns: ['id'],
      where: 'walletId IS NULL',
      orderBy: 'createdDate ASC',
    );

    for (final row in bucketRows) {
      final bucketId = row['id'] as int?;
      if (bucketId == null) continue;

      final dominantWalletRows = await executor.rawQuery(
        '''
        SELECT t.walletId AS walletId,
               SUM(ABS(a.allocatedAmount)) AS totalAllocated,
               COUNT(*) AS allocationCount
        FROM transaction_bucket_allocations a
        JOIN transactions t ON t.id = a.transactionId
        WHERE a.bucketId = ? AND t.walletId IS NOT NULL
        GROUP BY t.walletId
        ORDER BY totalAllocated DESC, allocationCount DESC, walletId ASC
        LIMIT 1
        ''',
        [bucketId],
      );

      final resolvedWalletId = dominantWalletRows.isNotEmpty
          ? dominantWalletRows.first['walletId'] as int?
          : fallbackWalletId;

      await executor.update(
        'financial_buckets',
        {
          'walletId': resolvedWalletId,
          'updatedDate': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [bucketId],
      );
    }
  }

  Future<void> _ensureBucketWalletBindings(DatabaseExecutor executor) async {
    final unboundCount = Sqflite.firstIntValue(await executor.rawQuery(
          'SELECT COUNT(*) FROM financial_buckets WHERE walletId IS NULL',
        )) ??
        0;
    if (unboundCount > 0) {
      await _backfillBucketWalletIds(executor);
    }
  }

  Future<int?> _resolveBucketWalletIdForWriteTxn(
    DatabaseExecutor executor, {
    required int? walletId,
  }) async {
    if (walletId != null) {
      final rows = await executor.query(
        'wallets',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [walletId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['id'] as int? ?? walletId;
      }
    }

    return _resolveDefaultBucketWalletId(executor);
  }

  Future<void> _seedDefaultWallets(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final name in ['Cash', 'E-Wallet', 'Bank', 'Tabungan']) {
      await db.execute(
        'INSERT OR IGNORE INTO wallets (name, isArchived, createdDate, updatedDate) VALUES (?, 0, ?, ?)',
        [name, now, now],
      );
    }
  }

  Future<void> setAppPreference(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_preferences',
      {
        'key': key,
        'value': value,
        'updatedDate': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getAppPreference(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<Map<String, String>> getAppPreferences(Iterable<String> keys) async {
    final db = await database;
    final keyList = keys.toList(growable: false);
    if (keyList.isEmpty) return const {};

    final placeholders = List.filled(keyList.length, '?').join(', ');
    final rows = await db.query(
      'app_preferences',
      columns: ['key', 'value'],
      where: 'key IN ($placeholders)',
      whereArgs: keyList,
    );

    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<({String walletName, int? walletId})> _resolveWalletContextByIdTxn(
    DatabaseExecutor executor, {
    required int? walletId,
    required String fallbackName,
    int? fallbackWalletId,
  }) async {
    if (walletId == null) {
      return (walletName: fallbackName, walletId: fallbackWalletId);
    }

    final rows = await executor.query(
      'wallets',
      columns: ['id', 'name'],
      where: 'id = ?',
      whereArgs: [walletId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return (walletName: fallbackName, walletId: fallbackWalletId ?? walletId);
    }

    return (
      walletName: rows.first['name'] as String? ?? fallbackName,
      walletId: rows.first['id'] as int? ?? walletId,
    );
  }

  Future<({String walletName, int? walletId})>
      _resolveWalletContextFromBucketTxn(
    DatabaseExecutor executor, {
    required FinancialBucket bucket,
    required String fallbackName,
    int? fallbackWalletId,
  }) async {
    return _resolveWalletContextByIdTxn(
      executor,
      walletId: bucket.walletId,
      fallbackName: fallbackName,
      fallbackWalletId: fallbackWalletId,
    );
  }

  // Transaction methods
  Future<int> insertTransaction(Transaction transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  Future<List<Transaction>> getTransactionsByWallet(String wallet) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'wallet = ?',
      whereArgs: [wallet],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  Future<List<Transaction>> getFilteredTransactions({
    String? wallet,
    String? type,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (wallet != null && wallet != 'All') {
      whereClause += 'wallet = ?';
      whereArgs.add(wallet);
    }

    if (type != null && type != 'All') {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'type = ?';
      whereArgs.add(type);
    }

    if (category != null && category != 'All') {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'category = ?';
      whereArgs.add(category);
    }

    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'date BETWEEN ? AND ?';
      whereArgs.addAll(
          [startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch]);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  bool _isDebtLinkedTransaction(Transaction transaction) {
    return transaction.affectsBalance &&
        (transaction.category == 'Hutang' || transaction.category == 'Piutang');
  }

  Future<void> _reverseTransactionAllocationsTxn(
    DatabaseExecutor txn,
    int transactionId,
  ) async {
    final allocationRows = await txn.query(
      'transaction_bucket_allocations',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
    final allocations =
        allocationRows.map(TransactionBucketAllocation.fromMap).toList();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final allocation in allocations) {
      double balanceDelta = 0;
      if (allocation.role == 'source') {
        balanceDelta = allocation.allocatedAmount;
      } else if (allocation.role == 'target') {
        balanceDelta = -allocation.allocatedAmount;
      }

      if (balanceDelta != 0) {
        await txn.rawUpdate(
          'UPDATE financial_buckets SET currentBalance = currentBalance + ?, updatedDate = ? WHERE id = ?',
          [balanceDelta, now, allocation.bucketId],
        );
      }
    }

    await txn.delete(
      'transaction_bucket_allocations',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final transactionRows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (transactionRows.isEmpty) {
        return 0;
      }

      final transaction = Transaction.fromMap(transactionRows.first);
      if (_isDebtLinkedTransaction(transaction)) {
        throw StateError(
          'Transactions linked to debt records cannot be deleted directly.',
        );
      }

      await _reverseTransactionAllocationsTxn(txn, id);

      return await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> updateTransaction({
    required int transactionId,
    required String type,
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required String walletName,
    int? walletId,
    bool? affectsBalance,
    FinancialBucket? sourceBucket,
    List<FinancialBucket>? subsetBuckets,
    bool allowWithoutBucketAllocation = false,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      final transactionRows = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (transactionRows.isEmpty) {
        return 0;
      }

      final existingTransaction = Transaction.fromMap(transactionRows.first);
      if (_isDebtLinkedTransaction(existingTransaction)) {
        throw StateError(
          'Transactions linked to debt records cannot be updated directly.',
        );
      }

      final resolvedAffectsBalance =
          affectsBalance ?? existingTransaction.affectsBalance;
      if (resolvedAffectsBalance &&
          (category == 'Hutang' || category == 'Piutang')) {
        throw StateError(
          'Transactions linked to debt records cannot be updated directly.',
        );
      }

      final resolvedWalletId = walletId ?? existingTransaction.walletId;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _reverseTransactionAllocationsTxn(txn, transactionId);

      final updatedRows = await txn.update(
        'transactions',
        {
          'id': transactionId,
          'type': type,
          'amount': amount,
          'category': category,
          'description': description,
          'date': date.millisecondsSinceEpoch,
          'wallet': walletName,
          'walletId': resolvedWalletId,
          'walletNameSnapshot': walletName,
          'affectsBalance': resolvedAffectsBalance ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );

      if (!resolvedAffectsBalance) {
        return updatedRows;
      }

      if (type == 'income') {
        if (subsetBuckets == null || subsetBuckets.isEmpty) {
          if (allowWithoutBucketAllocation) {
            return updatedRows;
          }
          throw StateError(
            'Income transactions that affect balance require subset buckets.',
          );
        }

        final allocations = allocateIncomeToBuckets(amount, subsetBuckets);
        final normalized = normalizeSubsetAllocation(subsetBuckets);
        for (final bucket in subsetBuckets) {
          final bucketId = bucket.id!;
          await txn.insert('transaction_bucket_allocations', {
            'transactionId': transactionId,
            'bucketId': bucketId,
            'normalizedPercentage': normalized[bucketId] ?? 0,
            'allocatedAmount': allocations[bucketId] ?? 0,
            'role': 'target',
            'createdDate': now,
          });
          await txn.rawUpdate(
            'UPDATE financial_buckets SET currentBalance = currentBalance + ?, updatedDate = ? WHERE id = ?',
            [allocations[bucketId] ?? 0, now, bucketId],
          );
        }

        return updatedRows;
      }

      if (type == 'expense') {
        if (sourceBucket == null) {
          if (allowWithoutBucketAllocation) {
            return updatedRows;
          }
          throw StateError(
            'Expense transactions that affect balance require a source bucket.',
          );
        }

        await txn.insert('transaction_bucket_allocations', {
          'transactionId': transactionId,
          'bucketId': sourceBucket.id!,
          'normalizedPercentage': 100.0,
          'allocatedAmount': amount,
          'role': 'source',
          'createdDate': now,
        });
        await txn.rawUpdate(
          'UPDATE financial_buckets SET currentBalance = currentBalance - ?, updatedDate = ? WHERE id = ?',
          [amount, now, sourceBucket.id!],
        );

        return updatedRows;
      }

      throw StateError('Unsupported transaction type: $type');
    });
  }

  // Saving Goals methods
  Future<int> insertSavingGoal(SavingGoal goal) async {
    final db = await database;
    return await db.insert('saving_goals', goal.toMap());
  }

  Future<List<SavingGoal>> getSavingGoals() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'saving_goals',
      orderBy: 'createdDate DESC',
    );

    return List.generate(maps.length, (i) {
      return SavingGoal.fromMap(maps[i]);
    });
  }

  Future<int> updateSavingGoal(SavingGoal goal) async {
    final db = await database;
    return await db.update(
      'saving_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteSavingGoal(int id) async {
    final db = await database;
    return await db.delete('saving_goals', where: 'id = ?', whereArgs: [id]);
  }

  // Wishlist methods
  Future<int> insertWishlistItem(WishlistItem item) async {
    final db = await database;
    return await db.insert('wishlist', item.toMap());
  }

  Future<List<WishlistItem>> getWishlistItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'wishlist',
      orderBy: 'createdDate DESC',
    );

    return List.generate(maps.length, (i) {
      return WishlistItem.fromMap(maps[i]);
    });
  }

  Future<int> deleteWishlistItem(int id) async {
    final db = await database;
    return await db.delete('wishlist', where: 'id = ?', whereArgs: [id]);
  }

  // Badge methods
  Future<int> insertBadge(UserBadge badge) async {
    final db = await database;
    return await db.insert('badges', badge.toMap());
  }

  Future<List<UserBadge>> getBadges() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'badges',
      orderBy: 'earnedDate DESC',
    );

    return List.generate(maps.length, (i) {
      return UserBadge.fromMap(maps[i]);
    });
  }

  Future<int> _insertExpenseWithSourceTxn(
    DatabaseExecutor txn, {
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required String walletName,
    required FinancialBucket sourceBucket,
    int? walletId,
  }) async {
    final resolvedWallet = await _resolveWalletContextFromBucketTxn(
      txn,
      bucket: sourceBucket,
      fallbackName: walletName,
      fallbackWalletId: walletId,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final txId = await txn.insert('transactions', {
      'type': 'expense',
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'wallet': resolvedWallet.walletName,
      'walletId': resolvedWallet.walletId,
      'walletNameSnapshot': resolvedWallet.walletName,
      'affectsBalance': 1,
    });

    await txn.insert('transaction_bucket_allocations', {
      'transactionId': txId,
      'bucketId': sourceBucket.id!,
      'normalizedPercentage': 100.0,
      'allocatedAmount': amount,
      'role': 'source',
      'createdDate': now,
    });
    await txn.rawUpdate(
      'UPDATE financial_buckets SET currentBalance = currentBalance - ?, updatedDate = ? WHERE id = ?',
      [amount, now, sourceBucket.id!],
    );

    return txId;
  }

  Future<void> purchaseWishlistItem(
    WishlistItem item, {
    FinancialBucket? sourceBucket,
    required String walletName,
    int? walletId,
  }) async {
    if (item.id == null) {
      throw StateError('Wishlist item must have an id before purchase.');
    }

    final db = await database;
    await db.transaction((txn) async {
      if (sourceBucket == null) {
        await txn.insert('transactions', {
          'type': 'expense',
          'amount': item.price,
          'category': 'Belanja',
          'description': item.name,
          'date': DateTime.now().millisecondsSinceEpoch,
          'wallet': walletName,
          'walletId': walletId,
          'walletNameSnapshot': walletName,
          'affectsBalance': 1,
        });
      } else {
        await _insertExpenseWithSourceTxn(
          txn,
          amount: item.price,
          category: 'Belanja',
          description: item.name,
          date: DateTime.now(),
          walletName: walletName,
          sourceBucket: sourceBucket,
          walletId: walletId,
        );
      }
      await txn.delete('wishlist', where: 'id = ?', whereArgs: [item.id]);
    });
  }

  // Wallet CRUD
  Future<int> insertWallet(Wallet wallet) async {
    final db = await database;
    return await db.insert('wallets', wallet.toMap());
  }

  Future<List<Wallet>> getWallets() async {
    final db = await database;
    final maps = await db.query('wallets', orderBy: 'createdDate ASC');
    return maps.map(Wallet.fromMap).toList();
  }

  Future<List<Wallet>> getActiveWallets() async {
    final db = await database;
    final maps = await db.query(
      'wallets',
      where: 'isArchived = 0',
      orderBy: 'createdDate ASC',
    );
    return maps.map(Wallet.fromMap).toList();
  }

  Future<int> updateWallet(Wallet wallet) async {
    final db = await database;
    final walletId = wallet.id;
    if (walletId == null) {
      return 0;
    }

    return await db.transaction((txn) async {
      final existingRows = await txn.query(
        'wallets',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [walletId],
        limit: 1,
      );
      final previousName =
          existingRows.isEmpty ? null : existingRows.first['name'] as String?;

      final updatedRows = await txn.update(
        'wallets',
        wallet.toMap(),
        where: 'id = ?',
        whereArgs: [walletId],
      );

      if (previousName != null && previousName != wallet.name) {
        await txn.rawUpdate(
          "UPDATE transactions SET walletId = ?, walletNameSnapshot = CASE WHEN walletNameSnapshot IS NULL OR walletNameSnapshot = '' THEN wallet ELSE walletNameSnapshot END WHERE walletId IS NULL AND wallet = ?",
          [walletId, previousName],
        );
      }

      return updatedRows;
    });
  }

  Future<int> _countWalletReferences(
    DatabaseExecutor executor, {
    required int id,
    String? name,
  }) async {
    final walletName = name?.trim();
    final transactionCount = walletName == null || walletName.isEmpty
        ? (Sqflite.firstIntValue(await executor.rawQuery(
                'SELECT COUNT(*) FROM transactions WHERE walletId = ?',
                [id])) ??
            0)
        : (Sqflite.firstIntValue(await executor.rawQuery(
                'SELECT COUNT(*) FROM transactions WHERE walletId = ? OR (walletId IS NULL AND wallet = ?)',
                [id, walletName])) ??
            0);
    final debtCount = Sqflite.firstIntValue(await executor.rawQuery(
          'SELECT COUNT(*) FROM debts WHERE walletId = ?',
          [id],
        )) ??
        0;
    final paymentCount = Sqflite.firstIntValue(await executor.rawQuery(
          'SELECT COUNT(*) FROM debt_payments WHERE walletId = ?',
          [id],
        )) ??
        0;
    return transactionCount + debtCount + paymentCount;
  }

  Future<int> getWalletReferenceCount(Wallet wallet) async {
    final walletId = wallet.id;
    if (walletId == null) return 0;
    final db = await database;
    return _countWalletReferences(db, id: walletId, name: wallet.name);
  }

  Future<int> archiveWallet(int id) async {
    final db = await database;
    return await db.update(
      'wallets',
      {'isArchived': 1, 'updatedDate': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteWallet(int id) async {
    final db = await database;
    final walletRows = await db.query(
      'wallets',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (walletRows.isEmpty) return 0;

    final walletName = walletRows.first['name'] as String?;
    final referenceCount =
        await _countWalletReferences(db, id: id, name: walletName);
    if (referenceCount > 0) {
      return await db.update(
        'wallets',
        {
          'isArchived': 1,
          'updatedDate': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return await db.delete('wallets', where: 'id = ?', whereArgs: [id]);
  }

  // Debt CRUD
  Future<int> insertDebt(Debt debt) async {
    final db = await database;
    return await db.insert('debts', debt.toMap());
  }

  Future<List<Debt>> getDebts() async {
    final db = await database;
    final maps = await db.query('debts', orderBy: 'createdDate DESC');
    return maps.map(Debt.fromMap).toList();
  }

  Future<Debt?> getDebtById(int id) async {
    final db = await database;
    final maps = await db.query('debts', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Debt.fromMap(maps.first);
  }

  Future<int> updateDebt(Debt debt) async {
    final db = await database;
    return await db.update(
      'debts',
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  Future<int> deleteDebt(int id) async {
    final db = await database;
    return await db.transaction((txn) async {
      final debtRows = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (debtRows.isEmpty) {
        return 0;
      }

      final debt = Debt.fromMap(debtRows.first);
      final paymentRows = await txn.query(
        'debt_payments',
        where: 'debtId = ?',
        whereArgs: [id],
      );
      final payments = paymentRows.map(DebtPayment.fromMap).toList();
      final hasBalanceEffects = debt.recordingMode == 'balance' ||
          payments.any((payment) => payment.recordingMode == 'balance');
      if (hasBalanceEffects) {
        throw StateError(
          'Debt with balance-affecting history cannot be deleted directly.',
        );
      }

      await txn.delete('debt_payments', where: 'debtId = ?', whereArgs: [id]);
      return await txn.delete('debts', where: 'id = ?', whereArgs: [id]);
    });
  }

  // DebtPayment CRUD
  Future<int> insertDebtPayment(DebtPayment payment) async {
    final db = await database;
    return await db.insert('debt_payments', payment.toMap());
  }

  Future<List<DebtPayment>> getDebtPaymentsByDebt(int debtId) async {
    final db = await database;
    final maps = await db.query(
      'debt_payments',
      where: 'debtId = ?',
      whereArgs: [debtId],
      orderBy: 'paymentDate DESC',
    );
    return maps.map(DebtPayment.fromMap).toList();
  }

  Future<int> deleteDebtPayment(int id) async {
    final db = await database;
    return await db.delete('debt_payments', where: 'id = ?', whereArgs: [id]);
  }

  // Atomic: insert payment record + update remainingAmount + settle if paid in full.
  // Bila recordingMode='balance' dan affectedBucket!=null, terapkan side effect saldo pos:
  //   debt payment   → expense dari pos (saldo pos berkurang)
  //   receivable pay → income ke pos (saldo pos bertambah)
  Future<void> recordDebtPayment({
    required int debtId,
    required double amount,
    required DateTime paymentDate,
    required String recordingMode,
    String? note,
    int? walletId,
    int? bucketId,
    FinancialBucket? affectedBucket,
    String walletName = 'Cash',
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final debt = await getDebtById(debtId);
    if (debt == null) return;
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Payment amount must be greater than zero.',
      );
    }
    if (debt.remainingAmount <= 0 || debt.status == 'settled') {
      throw StateError('Debt is already settled.');
    }
    if (amount > debt.remainingAmount + 0.001) {
      throw RangeError.value(
        amount,
        'amount',
        'Payment amount exceeds the remaining balance.',
      );
    }

    String resolvedWalletName = walletName;
    int? resolvedWalletId = walletId;
    if (recordingMode == 'balance' && affectedBucket != null) {
      final resolvedWallet = await _resolveWalletContextFromBucketTxn(
        db,
        bucket: affectedBucket,
        fallbackName: walletName,
        fallbackWalletId: walletId,
      );
      resolvedWalletName = resolvedWallet.walletName;
      resolvedWalletId = resolvedWallet.walletId;
    } else if (walletId != null) {
      final walletRows = await db.query(
        'wallets',
        where: 'id = ?',
        whereArgs: [walletId],
        limit: 1,
      );
      if (walletRows.isNotEmpty) {
        resolvedWalletName = walletRows.first['name'] as String? ?? walletName;
      } else {
        resolvedWalletName = 'Dompet tidak aktif';
      }
    }

    await db.transaction((txn) async {
      // Insert cicilan
      await txn.insert('debt_payments', {
        'debtId': debtId,
        'amount': amount,
        'paymentDate': paymentDate.millisecondsSinceEpoch,
        'recordingMode': recordingMode,
        'walletId': resolvedWalletId,
        'bucketId': affectedBucket?.id ?? bucketId,
        'note': note,
        'createdDate': now,
      });

      // Update remainingAmount
      await txn.rawUpdate(
        'UPDATE debts SET remainingAmount = MAX(0, remainingAmount - ?), updatedDate = ? WHERE id = ?',
        [amount, now, debtId],
      );

      // Settle bila lunas
      await txn.rawUpdate(
        "UPDATE debts SET status = 'settled', updatedDate = ? WHERE id = ? AND remainingAmount <= 0",
        [now, debtId],
      );

      // BR-05/BR-07: side effect saldo pos untuk mode Masuk ke saldo
      if (recordingMode == 'balance' && affectedBucket != null) {
        final transactionType = debt.type == 'debt' ? 'expense' : 'income';
        final allocationRole = debt.type == 'debt' ? 'source' : 'target';

        final txId = await txn.insert('transactions', {
          'type': transactionType,
          'amount': amount,
          'category': debt.type == 'debt' ? 'Hutang' : 'Piutang',
          'description': debt.type == 'debt'
              ? 'Pembayaran hutang ${debt.personName}'
              : 'Pembayaran piutang ${debt.personName}',
          'date': paymentDate.millisecondsSinceEpoch,
          'wallet': resolvedWalletName,
          'walletId': resolvedWalletId,
          'walletNameSnapshot': resolvedWalletName,
          'affectsBalance': 1,
        });

        await txn.insert('transaction_bucket_allocations', {
          'transactionId': txId,
          'bucketId': affectedBucket.id!,
          'normalizedPercentage': 100.0,
          'allocatedAmount': amount,
          'role': allocationRole,
          'createdDate': now,
        });

        if (debt.type == 'debt') {
          // Membayar hutang = uang keluar dari pos
          await txn.rawUpdate(
            'UPDATE financial_buckets SET currentBalance = currentBalance - ?, updatedDate = ? WHERE id = ?',
            [amount, now, affectedBucket.id!],
          );
        } else {
          // Menerima pembayaran piutang = uang masuk ke pos
          await txn.rawUpdate(
            'UPDATE financial_buckets SET currentBalance = currentBalance + ?, updatedDate = ? WHERE id = ?',
            [amount, now, affectedBucket.id!],
          );
        }
      }
    });
  }

  // FinancialBucket CRUD
  Future<int> insertFinancialBucket(FinancialBucket bucket) async {
    final db = await database;
    return await db.transaction((txn) async {
      final resolvedWalletId = await _resolveBucketWalletIdForWriteTxn(
        txn,
        walletId: bucket.walletId,
      );
      if (resolvedWalletId == null) {
        throw StateError('Financial bucket requires an active wallet.');
      }

      final payload = bucket.toMap();
      payload['walletId'] = resolvedWalletId;
      return txn.insert('financial_buckets', payload);
    });
  }

  Future<List<FinancialBucket>> getFinancialBuckets() async {
    final db = await database;
    await _ensureBucketWalletBindings(db);
    final maps =
        await db.query('financial_buckets', orderBy: 'createdDate ASC');
    return maps.map(FinancialBucket.fromMap).toList();
  }

  Future<List<FinancialBucket>> getActiveBuckets() async {
    final db = await database;
    await _ensureBucketWalletBindings(db);
    final maps = await db.query(
      'financial_buckets',
      where: 'isArchived = 0',
      orderBy: 'createdDate ASC',
    );
    return maps.map(FinancialBucket.fromMap).toList();
  }

  Future<int> updateFinancialBucket(FinancialBucket bucket) async {
    final db = await database;
    return await db.transaction((txn) async {
      final resolvedWalletId = await _resolveBucketWalletIdForWriteTxn(
        txn,
        walletId: bucket.walletId,
      );
      if (resolvedWalletId == null) {
        throw StateError('Financial bucket requires an active wallet.');
      }

      final payload = bucket.toMap();
      payload['walletId'] = resolvedWalletId;
      return txn.update(
        'financial_buckets',
        payload,
        where: 'id = ?',
        whereArgs: [bucket.id],
      );
    });
  }

  Future<int> archiveFinancialBucket(int id) async {
    final db = await database;
    return await db.update(
      'financial_buckets',
      {'isArchived': 1, 'updatedDate': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // TransactionBucketAllocation CRUD
  Future<int> insertTransactionBucketAllocation(
      TransactionBucketAllocation allocation) async {
    final db = await database;
    return await db.insert(
        'transaction_bucket_allocations', allocation.toMap());
  }

  Future<List<TransactionBucketAllocation>> getTransactionBucketAllocations(
      int transactionId) async {
    final db = await database;
    final maps = await db.query(
      'transaction_bucket_allocations',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
    );
    return maps.map(TransactionBucketAllocation.fromMap).toList();
  }

  Future<Map<int, List<TransactionBucketAllocation>>>
      getTransactionBucketAllocationsForTransactions(
    Iterable<int> transactionIds,
  ) async {
    final ids = transactionIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final maps = await db.query(
      'transaction_bucket_allocations',
      where: 'transactionId IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'transactionId ASC',
    );

    final grouped = <int, List<TransactionBucketAllocation>>{};
    for (final map in maps) {
      final allocation = TransactionBucketAllocation.fromMap(map);
      (grouped[allocation.transactionId] ??= <TransactionBucketAllocation>[])
          .add(allocation);
    }
    return grouped;
  }

  // BucketTransfer CRUD
  Future<int> insertBucketTransfer(BucketTransfer transfer) async {
    final db = await database;
    return await db.insert('bucket_transfers', transfer.toMap());
  }

  Future<List<BucketTransfer>> getBucketTransfers() async {
    final db = await database;
    final maps =
        await db.query('bucket_transfers', orderBy: 'transferDate DESC');
    return maps.map(BucketTransfer.fromMap).toList();
  }

  // BR-12: transfer memindahkan saldo antar-pos tanpa mengubah total keseluruhan.
  Future<void> executeBucketTransfer({
    required int fromBucketId,
    required int toBucketId,
    required double amount,
    required DateTime transferDate,
    String? note,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final fromRows = await txn.query(
        'financial_buckets',
        columns: ['walletId'],
        where: 'id = ?',
        whereArgs: [fromBucketId],
        limit: 1,
      );
      final toRows = await txn.query(
        'financial_buckets',
        columns: ['walletId'],
        where: 'id = ?',
        whereArgs: [toBucketId],
        limit: 1,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.rawUpdate(
        'UPDATE financial_buckets SET currentBalance = currentBalance - ?, updatedDate = ? WHERE id = ?',
        [amount, now, fromBucketId],
      );
      await txn.rawUpdate(
        'UPDATE financial_buckets SET currentBalance = currentBalance + ?, updatedDate = ? WHERE id = ?',
        [amount, now, toBucketId],
      );
      await txn.insert('bucket_transfers', {
        'fromBucketId': fromBucketId,
        'toBucketId': toBucketId,
        'fromWalletIdSnapshot':
            fromRows.isEmpty ? null : fromRows.first['walletId'],
        'toWalletIdSnapshot': toRows.isEmpty ? null : toRows.first['walletId'],
        'amount': amount,
        'note': note,
        'transferDate': transferDate.millisecondsSinceEpoch,
        'createdDate': now,
      });

      final fromWalletId =
          fromRows.isEmpty ? null : fromRows.first['walletId'] as int?;
      final toWalletId =
          toRows.isEmpty ? null : toRows.first['walletId'] as int?;
      if (fromWalletId != null &&
          toWalletId != null &&
          fromWalletId != toWalletId) {
        final fromWallet = await _resolveWalletContextByIdTxn(
          txn,
          walletId: fromWalletId,
          fallbackName: 'Cash',
          fallbackWalletId: fromWalletId,
        );
        final toWallet = await _resolveWalletContextByIdTxn(
          txn,
          walletId: toWalletId,
          fallbackName: 'Cash',
          fallbackWalletId: toWalletId,
        );

        await txn.insert('transactions', {
          'type': 'expense',
          'amount': amount,
          'category': _internalTransferCategory,
          'description': 'Transfer ke ${toWallet.walletName}',
          'date': transferDate.millisecondsSinceEpoch,
          'wallet': fromWallet.walletName,
          'walletId': fromWallet.walletId,
          'walletNameSnapshot': fromWallet.walletName,
          'affectsBalance': 1,
        });
        await txn.insert('transactions', {
          'type': 'income',
          'amount': amount,
          'category': _internalTransferCategory,
          'description': 'Transfer dari ${fromWallet.walletName}',
          'date': transferDate.millisecondsSinceEpoch,
          'wallet': toWallet.walletName,
          'walletId': toWallet.walletId,
          'walletNameSnapshot': toWallet.walletName,
          'affectsBalance': 1,
        });
      }
    });
  }

  // Simpan transaksi income + allocation snapshot ke subset pos (BR-09).
  // Saldo setiap pos dalam subset bertambah sesuai nominal yang dialokasikan.
  Future<int> saveIncomeWithAllocations({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required String walletName,
    required List<FinancialBucket> subsetBuckets,
    int? walletId,
  }) async {
    if (!bucketsShareSameWallet(subsetBuckets)) {
      throw StateError(
        'Income allocation must target buckets from one effective wallet.',
      );
    }

    final db = await database;
    final allocations = allocateIncomeToBuckets(amount, subsetBuckets);
    final normalized = normalizeSubsetAllocation(subsetBuckets);
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.transaction((txn) async {
      final resolvedWallet = await _resolveWalletContextFromBucketTxn(
        txn,
        bucket: subsetBuckets.first,
        fallbackName: walletName,
        fallbackWalletId: walletId,
      );
      final txId = await txn.insert('transactions', {
        'type': 'income',
        'amount': amount,
        'category': category,
        'description': description,
        'date': date.millisecondsSinceEpoch,
        'wallet': resolvedWallet.walletName,
        'walletId': resolvedWallet.walletId,
        'walletNameSnapshot': resolvedWallet.walletName,
        'affectsBalance': 1,
      });

      for (final bucket in subsetBuckets) {
        final bucketId = bucket.id!;
        await txn.insert('transaction_bucket_allocations', {
          'transactionId': txId,
          'bucketId': bucketId,
          'normalizedPercentage': normalized[bucketId] ?? 0,
          'allocatedAmount': allocations[bucketId] ?? 0,
          'role': 'target',
          'createdDate': now,
        });
        await txn.rawUpdate(
          'UPDATE financial_buckets SET currentBalance = currentBalance + ?, updatedDate = ? WHERE id = ?',
          [allocations[bucketId] ?? 0, now, bucketId],
        );
      }

      return txId;
    });
  }

  // Simpan transaksi expense yang memengaruhi saldo dengan satu pos sumber (BR-10).
  Future<int> saveExpenseWithSource({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required String walletName,
    required FinancialBucket sourceBucket,
    int? walletId,
  }) async {
    final db = await database;

    return await db.transaction((txn) async {
      return _insertExpenseWithSourceTxn(
        txn,
        amount: amount,
        category: category,
        description: description,
        date: date,
        walletName: walletName,
        sourceBucket: sourceBucket,
        walletId: walletId,
      );
    });
  }

  // Simpan transaksi expense sebagai catatan saja (affectsBalance = false).
  // Tidak mengubah saldo wallet atau pos (BR-05 analog untuk expense).
  Future<int> saveExpenseNoteOnly({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required String walletName,
    int? walletId,
  }) async {
    final db = await database;
    return await db.insert('transactions', {
      'type': 'expense',
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'wallet': walletName,
      'walletId': walletId,
      'walletNameSnapshot': walletName,
      'affectsBalance': 0,
    });
  }
}

// Skeleton pages — entry point dari quick menu, tanpa domain CRUD (Phase 4-6)

class DompetPage extends StatefulWidget {
  const DompetPage({
    super.key,
    this.initialWallets, // null = load from DB; non-null = use directly (incl. [])
    @visibleForTesting this.transactionCountForWallet,
  });
  final List<Wallet>? initialWallets;
  // Nullable: null = real DB check; non-null = injected function (tests only)
  final Future<int> Function(Wallet)? transactionCountForWallet;

  @override
  State<DompetPage> createState() => _DompetPageState();
}

class _DompetPageState extends State<DompetPage> {
  late List<Wallet> _wallets;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provided = widget.initialWallets;
    if (provided != null) {
      _wallets = provided;
    } else {
      _wallets = const [];
      _isLoading = true;
      _loadWallets();
    }
  }

  Future<void> _loadWallets() async {
    final wallets = await DatabaseHelper().getActiveWallets();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('page_dompet'),
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text(
          'Dompet',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          // tradeoff: SizedBox.shrink selama loading agar pumpAndSettle test tidak
          // timeout akibat CircularProgressIndicator yang animate terus-menerus.
          // Upgrade ke CircularProgressIndicator bila ada shimmer/skeleton loading.
          ? const SizedBox.shrink()
          : _wallets.isEmpty
              ? _buildEmptyWallets()
              : ListView.builder(
                  key: const Key('wallet_list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: _wallets.length,
                  itemBuilder: (_, i) => _buildWalletItem(_wallets[i]),
                ),
      floatingActionButton: FloatingActionButton(
        key: const Key('dompet_fab'),
        backgroundColor: const Color(0xFFFF69B4),
        onPressed: () => _showAddWalletSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyWallets() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Belum ada dompet',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Tap + untuk menambah dompet baru',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildWalletItem(Wallet wallet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF69B4).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            resolveWalletIcon(wallet.iconKey, wallet.name),
            color: const Color(0xFFFF69B4),
          ),
        ),
        title: Text(wallet.name,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('wallet_edit_btn'),
              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
              tooltip: 'Edit',
              onPressed: () => _showAddWalletSheet(context, wallet: wallet),
            ),
            IconButton(
              key: const Key('wallet_archive_btn'),
              icon: const Icon(Icons.archive_outlined, color: Colors.grey),
              tooltip: 'Arsipkan',
              onPressed: () => _handleArchive(wallet),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleArchive(Wallet wallet) async {
    final int count;
    final countFn = widget.transactionCountForWallet;
    if (countFn != null) {
      count = await countFn(wallet);
    } else {
      count = await DatabaseHelper().getWalletReferenceCount(wallet);
    }

    if (!mounted) return;

    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          key: const Key('wallet_archive_warning'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Arsipkan Dompet?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            '"${wallet.name}" masih dipakai di $count catatan historis. '
            'Arsip direkomendasikan agar riwayat dan cicilan tetap konsisten.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('Batal', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            TextButton(
              key: const Key('wallet_remove_btn'),
              onPressed: () async {
                Navigator.pop(context);
                await DatabaseHelper().deleteWallet(wallet.id!);
                _loadWallets();
              },
              child: Text('Keluarkan dari daftar aktif',
                  style: GoogleFonts.poppins(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF69B4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await DatabaseHelper().archiveWallet(wallet.id!);
                _loadWallets();
              },
              child: Text('Arsipkan',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } else {
      // Tanpa histori: keluarkan langsung dari daftar aktif
      await DatabaseHelper().deleteWallet(wallet.id!);
      _loadWallets();
    }
  }

  void _showAddWalletSheet(BuildContext context, {Wallet? wallet}) {
    final nameCtrl = TextEditingController();
    String selectedIconKey = wallet?.iconKey ?? 'wallet';

    if (wallet != null) {
      nameCtrl.text = wallet.name;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  key: const Key('sheet_drag_handle'),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(wallet == null ? 'Tambah Dompet' : 'Edit Dompet',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                key: const Key('wallet_name_field'),
                controller: nameCtrl,
                autofocus: wallet == null,
                decoration: InputDecoration(
                  hintText: 'Nama dompet',
                  hintStyle: GoogleFonts.poppins(),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              Text('Ikon Dompet',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableWalletIcons.entries.map((entry) {
                  final isSelected = selectedIconKey == entry.key;
                  return GestureDetector(
                    key: Key('wallet_icon_${entry.key}'),
                    onTap: () => setModal(() => selectedIconKey = entry.key),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF69B4).withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF69B4)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        entry.value,
                        color:
                            isSelected ? const Color(0xFFFF69B4) : Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('wallet_save_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF69B4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final now = DateTime.now();
                    if (wallet == null) {
                      await DatabaseHelper().insertWallet(Wallet(
                        name: name,
                        iconKey: selectedIconKey,
                        createdDate: now,
                        updatedDate: now,
                      ));
                    } else {
                      await DatabaseHelper().updateWallet(Wallet(
                        id: wallet.id,
                        name: name,
                        iconKey: selectedIconKey,
                        color: wallet.color,
                        isArchived: wallet.isArchived,
                        createdDate: wallet.createdDate,
                        updatedDate: now,
                      ));
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadWallets();
                  },
                  child: Text('Simpan',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HutangPiutangPage extends StatefulWidget {
  const HutangPiutangPage({
    super.key,
    this.initialDebts, // null = load DB; non-null = use directly (incl. [])
    this.initialWallets,
    this.initialBuckets,
  });
  final List<Debt>? initialDebts;
  final List<Wallet>? initialWallets;
  final List<FinancialBucket>? initialBuckets;

  @override
  State<HutangPiutangPage> createState() => _HutangPiutangPageState();
}

class _HutangPiutangPageState extends State<HutangPiutangPage> {
  late List<Debt> _debts;
  late List<Wallet> _wallets;
  late List<FinancialBucket> _buckets;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provided = widget.initialDebts;
    if (provided != null) {
      _debts = provided;
    } else {
      _debts = const [];
      _isLoading = true;
      _loadDebts();
    }

    _wallets = widget.initialWallets ?? const [];
    _buckets = widget.initialBuckets ?? const [];
    if (widget.initialWallets == null || widget.initialBuckets == null) {
      _loadReferenceData();
    }
  }

  Future<void> _loadReferenceData() async {
    final wallets =
        widget.initialWallets ?? await DatabaseHelper().getActiveWallets();
    final buckets =
        widget.initialBuckets ?? await DatabaseHelper().getActiveBuckets();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _buckets = buckets;
    });
  }

  Future<void> _loadDebts() async {
    final debts = await DatabaseHelper().getDebts();
    if (!mounted) return;
    setState(() {
      _debts = debts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('page_hutang_piutang'),
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text('Hutang / Piutang',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const SizedBox.shrink()
          : _debts.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  key: const Key('debt_list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: _debts.length,
                  itemBuilder: (_, i) => _buildDebtItem(_debts[i]),
                ),
      floatingActionButton: FloatingActionButton(
        key: const Key('debt_fab'),
        backgroundColor: const Color(0xFFFF69B4),
        onPressed: () => _showAddDebtSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.handshake_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Belum ada hutang/piutang',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Tap + untuk mencatat hutang atau piutang',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );

  Widget _buildDebtItem(Debt debt) {
    final isDebt = debt.type == 'debt';
    final statusLabel = debt.status == 'settled'
        ? 'Lunas'
        : debt.isOverdue
            ? 'Terlambat'
            : 'Aktif';
    final statusColor = debt.status == 'settled'
        ? Colors.green
        : debt.isOverdue
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isDebt ? Colors.redAccent : Colors.green)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isDebt ? Icons.arrow_upward : Icons.arrow_downward,
            color: isDebt ? Colors.redAccent : Colors.green,
          ),
        ),
        title: Row(
          children: [
            Text(debt.personName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isDebt ? Colors.redAccent : Colors.green)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDebt ? 'Hutang' : 'Piutang',
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDebt ? Colors.redAccent : Colors.green,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(
              formatRupiah(debt.remainingAmount),
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HutangDetailPage(debt: debt),
            ),
          ).then((_) => _loadDebts());
        },
      ),
    );
  }

  Future<void> _showAddDebtSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DebtFormSheet(
          initialWallets: _wallets.isEmpty ? null : _wallets,
          initialBuckets: _buckets.isEmpty ? null : _buckets,
        ),
      ),
    );
    _loadReferenceData();
    _loadDebts();
  }
}

class DebtFormSheet extends StatefulWidget {
  const DebtFormSheet({
    super.key,
    this.initialDebt,
    this.initialWallets,
    this.initialBuckets,
  });

  final Debt? initialDebt;
  final List<Wallet>? initialWallets;
  final List<FinancialBucket>? initialBuckets;

  @override
  State<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<DebtFormSheet> {
  late final TextEditingController _personCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late String _selectedType;
  late String _selectedMode;
  late DateTime _borrowedDate;
  DateTime? _dueDate;
  List<Wallet> _wallets = const [];
  List<FinancialBucket> _buckets = const [];
  Wallet? _selectedWallet;
  FinancialBucket? _selectedBucket;

  @override
  void initState() {
    super.initState();
    final debt = widget.initialDebt;
    _personCtrl = TextEditingController(text: debt?.personName ?? '');
    _amountCtrl = TextEditingController(
      text: debt != null ? formatRupiahValue(debt.principalAmount) : '',
    );
    _noteCtrl = TextEditingController(text: debt?.note ?? '');
    _selectedType = debt?.type ?? 'debt';
    _selectedMode = debt?.recordingMode ?? 'note';
    _borrowedDate = debt?.borrowedDate ?? DateTime.now();
    _dueDate = debt?.dueDate;
    _wallets = widget.initialWallets ?? const [];
    _buckets = widget.initialBuckets ?? const [];
    _selectedWallet =
        _wallets.where((wallet) => wallet.id == debt?.walletId).isNotEmpty
            ? _wallets.firstWhere((wallet) => wallet.id == debt?.walletId)
            : (_wallets.isNotEmpty ? _wallets.first : null);
    _selectedBucket =
        _buckets.where((bucket) => bucket.id == debt?.bucketId).isNotEmpty
            ? _buckets.firstWhere((bucket) => bucket.id == debt?.bucketId)
            : (_buckets.isNotEmpty ? _buckets.first : null);
    if (_selectedMode == 'balance' && _selectedBucket?.walletId != null) {
      final matches =
          _wallets.where((wallet) => wallet.id == _selectedBucket?.walletId);
      if (matches.isNotEmpty) {
        _selectedWallet = matches.first;
      }
    }
    if (widget.initialWallets == null || widget.initialBuckets == null) {
      _loadReferences();
    }
  }

  Future<void> _loadReferences() async {
    final wallets = widget.initialWallets ??
        (widget.initialDebt == null
            ? await DatabaseHelper().getActiveWallets()
            : await DatabaseHelper().getWallets());
    final buckets = widget.initialBuckets ??
        (widget.initialDebt == null
            ? await DatabaseHelper().getActiveBuckets()
            : await DatabaseHelper().getFinancialBuckets());
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _buckets = buckets;
      _selectedWallet ??= wallets.isNotEmpty ? wallets.first : null;
      _selectedBucket ??= buckets.isNotEmpty ? buckets.first : null;
      if (_selectedMode == 'balance' && _selectedBucket?.walletId != null) {
        final matches =
            wallets.where((wallet) => wallet.id == _selectedBucket?.walletId);
        if (matches.isNotEmpty) {
          _selectedWallet = matches.first;
        }
      }
    });
  }

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _showValidationMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
      ),
    );
  }

  Future<void> _pickBorrowedDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDate: _borrowedDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _borrowedDate = picked);
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? _borrowedDate;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDate: initial,
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final person = _personCtrl.text.trim();
    final amount = tryParseCurrencyInput(_amountCtrl.text.trim()) ?? 0;
    if (person.isEmpty) {
      _showValidationMessage('Nama pihak tidak boleh kosong');
      return;
    }
    if (amount <= 0) {
      _showValidationMessage('Nominal harus lebih besar dari 0');
      return;
    }

    final requiresFinancialBinding = _selectedMode == 'balance';
    if (requiresFinancialBinding && _selectedBucket?.walletId != null) {
      final matches =
          _wallets.where((wallet) => wallet.id == _selectedBucket?.walletId);
      if (matches.isNotEmpty) {
        _selectedWallet = matches.first;
      }
    }
    if (requiresFinancialBinding && _selectedWallet == null) {
      _showValidationMessage('Pilih dompet untuk mode Masuk ke saldo');
      return;
    }
    if (requiresFinancialBinding && _buckets.isEmpty) {
      _showValidationMessage(
          'Buat pos keuangan aktif dulu untuk mode Masuk ke saldo');
      return;
    }
    if (requiresFinancialBinding &&
        hasIncompleteBucketConfiguration(_buckets)) {
      _showValidationMessage(_bucketConfigurationIncompleteMessage);
      return;
    }
    if (requiresFinancialBinding && _selectedBucket == null) {
      _showValidationMessage('Pilih pos keuangan untuk mode Masuk ke saldo');
      return;
    }

    final db = DatabaseHelper();
    final now = DateTime.now();
    final existing = widget.initialDebt;

    if (requiresFinancialBinding && existing == null) {
      if (_selectedType == 'debt') {
        await db.saveIncomeWithAllocations(
          amount: amount,
          category: 'Hutang',
          description: 'Hutang dari $person',
          date: now,
          walletName: _selectedWallet!.name,
          subsetBuckets: [_selectedBucket!],
          walletId: _selectedWallet!.id,
        );
      } else {
        await db.saveExpenseWithSource(
          amount: amount,
          category: 'Piutang',
          description: 'Piutang ke $person',
          date: now,
          walletName: _selectedWallet!.name,
          sourceBucket: _selectedBucket!,
          walletId: _selectedWallet!.id,
        );
      }
    }

    if (existing == null) {
      await db.insertDebt(Debt(
        type: _selectedType,
        personName: person,
        principalAmount: amount,
        remainingAmount: amount,
        borrowedDate: _borrowedDate,
        dueDate: _dueDate,
        recordingMode: _selectedMode,
        walletId: _selectedWallet?.id,
        bucketId: _selectedBucket?.id,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        createdDate: now,
        updatedDate: now,
      ));
    } else {
      final paidAmount = existing.principalAmount - existing.remainingAmount;
      if (amount + 0.001 < paidAmount) {
        _showValidationMessage(
          'Nominal total tidak boleh lebih kecil dari yang sudah dibayar.',
        );
        return;
      }
      final updatedRemaining =
          (amount - paidAmount).clamp(0.0, amount).toDouble();
      await db.updateDebt(Debt(
        id: existing.id,
        type: _selectedType,
        personName: person,
        principalAmount: amount,
        remainingAmount: updatedRemaining,
        borrowedDate: _borrowedDate,
        dueDate: _dueDate,
        recordingMode: _selectedMode,
        walletId: _selectedWallet?.id,
        bucketId: _selectedBucket?.id,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        status: updatedRemaining <= 0 ? 'settled' : 'active',
        createdDate: existing.createdDate,
        updatedDate: now,
      ));
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialDebt != null;
    final lockBalanceFields =
        isEditMode && widget.initialDebt!.recordingMode == 'balance';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              key: const Key('debt_form_sheet'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    key: const Key('sheet_drag_handle'),
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.initialDebt == null
                      ? 'Catat Hutang / Piutang'
                      : 'Edit Hutang / Piutang',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF69B4),
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Utama',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isEditMode)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          lockBalanceFields
                              ? 'Nominal, dompet, dan pos dikunci agar histori saldo tetap konsisten.'
                              : 'Tipe dan mode pencatatan tetap mengikuti record awal.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF666666),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: isEditMode
                                ? null
                                : () => setState(() => _selectedType = 'debt'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedType == 'debt'
                                    ? Colors.redAccent
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Saya Berhutang',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      color: _selectedType == 'debt'
                                          ? Colors.white
                                          : Colors.black54,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: isEditMode
                                ? null
                                : () => setState(
                                    () => _selectedType = 'receivable'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _selectedType == 'receivable'
                                    ? Colors.green
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Piutang Saya',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      color: _selectedType == 'receivable'
                                          ? Colors.white
                                          : Colors.black54,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nama Orang',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('debt_person_field'),
                      controller: _personCtrl,
                      decoration: InputDecoration(
                        hintText: 'Siapa?',
                        hintStyle: GoogleFonts.poppins(),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nominal',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('debt_amount_field'),
                      controller: _amountCtrl,
                      enabled: !lockBalanceFields,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: InputDecoration(
                        hintText: 'Nominal',
                        hintStyle: GoogleFonts.poppins(),
                        prefixText: 'Rp ',
                        prefixStyle: GoogleFonts.poppins(
                          color: const Color(0xFFFF69B4),
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanggal Pinjam',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const Key('debt_borrowed_date_btn'),
                                onPressed: _pickBorrowedDate,
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: Text(DateFormat('dd MMM yyyy')
                                    .format(_borrowedDate)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jatuh Tempo',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                key: const Key('debt_due_date_btn'),
                                onPressed: _pickDueDate,
                                icon:
                                    const Icon(Icons.event_available_outlined),
                                label: Text(
                                  _dueDate == null
                                      ? 'Jatuh tempo'
                                      : DateFormat('dd MMM yyyy')
                                          .format(_dueDate!),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Dompet',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Wallet>(
                      key: const Key('debt_wallet_dropdown'),
                      value: _selectedWallet,
                      items: _wallets
                          .map((wallet) => DropdownMenuItem<Wallet>(
                                value: wallet,
                                child: Row(
                                  children: [
                                    Icon(
                                        resolveWalletIcon(
                                            wallet.iconKey, wallet.name),
                                        size: 16,
                                        color: const Color(0xFFFF69B4)),
                                    const SizedBox(width: 8),
                                    Text(wallet.name),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: lockBalanceFields || _selectedMode == 'balance'
                          ? null
                          : (wallet) =>
                              setState(() => _selectedWallet = wallet),
                      decoration: InputDecoration(
                        hintText: 'Pilih dompet',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Pos Keuangan',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<FinancialBucket>(
                      key: const Key('debt_bucket_dropdown'),
                      value: _selectedBucket,
                      items: _buckets
                          .map((bucket) => DropdownMenuItem<FinancialBucket>(
                                value: bucket,
                                child: Row(
                                  children: [
                                    Icon(bucket.resolvedIcon,
                                        size: 16,
                                        color: const Color(0xFFFF69B4)),
                                    const SizedBox(width: 8),
                                    Text(bucket.name),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: lockBalanceFields
                          ? null
                          : (bucket) => setState(() {
                                _selectedBucket = bucket;
                                if (_selectedMode == 'balance' &&
                                    bucket?.walletId != null) {
                                  final matches = _wallets.where((wallet) =>
                                      wallet.id == bucket?.walletId);
                                  if (matches.isNotEmpty) {
                                    _selectedWallet = matches.first;
                                  }
                                }
                              }),
                      decoration: InputDecoration(
                        hintText: 'Pilih pos keuangan',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Catatan Tambahan',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('debt_note_field'),
                      controller: _noteCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Catatan',
                        hintStyle: GoogleFonts.poppins(),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      key: const Key('debt_mode_selector'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mode Pencatatan',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _debtModeOption(
                          value: 'balance',
                          label: 'Masuk ke saldo',
                          helper:
                              'Memengaruhi saldo dompet dan statistik keuangan',
                          enabled: !isEditMode,
                        ),
                        const SizedBox(height: 6),
                        _debtModeOption(
                          value: 'note',
                          label: 'Catatan saja',
                          helper:
                              'Hanya mencatat — tidak mengubah saldo dompet',
                          enabled: !isEditMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('debt_save_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF69B4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _save,
                        child: Text(isEditMode ? 'Simpan Perubahan' : 'Simpan',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
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

  Widget _debtModeOption({
    required String value,
    required String label,
    required String helper,
    required bool enabled,
  }) {
    final isSelected = value == _selectedMode;
    return GestureDetector(
      onTap: enabled ? () => setState(() => _selectedMode = value) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF69B4).withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border:
              isSelected ? Border.all(color: const Color(0xFFFF69B4)) : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFF69B4) : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(helper,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HutangDetailPage extends StatefulWidget {
  const HutangDetailPage({
    super.key,
    required this.debt,
    this.initialPayments, // null = load DB; non-null = use directly (incl. [])
    this.initialWallets,
    this.initialBuckets,
  });
  final Debt debt;
  final List<DebtPayment>? initialPayments;
  final List<Wallet>? initialWallets;
  final List<FinancialBucket>? initialBuckets;

  @override
  State<HutangDetailPage> createState() => _HutangDetailPageState();
}

class _HutangDetailPageState extends State<HutangDetailPage> {
  late Debt _debt;
  late List<DebtPayment> _payments;
  List<Wallet> _availableWallets = const [];
  List<FinancialBucket> _availableBuckets = const [];

  @override
  void initState() {
    super.initState();
    _debt = widget.debt;
    final provided = widget.initialPayments;
    if (provided != null) {
      _payments = provided;
    } else {
      _payments = const [];
      _loadPayments();
    }
    _availableWallets = widget.initialWallets ?? const [];
    _availableBuckets = widget.initialBuckets ?? const [];
    if (widget.initialWallets == null || widget.initialBuckets == null) {
      _loadReferenceData();
    }
  }

  Future<void> _loadReferenceData() async {
    final wallets =
        widget.initialWallets ?? await DatabaseHelper().getWallets();
    final buckets =
        widget.initialBuckets ?? await DatabaseHelper().getFinancialBuckets();
    if (!mounted) return;
    setState(() {
      _availableWallets = wallets;
      _availableBuckets = buckets;
    });
  }

  Wallet? _findWalletById(int? walletId) {
    if (walletId == null) return null;
    final matches = _availableWallets.where((wallet) => wallet.id == walletId);
    return matches.isEmpty ? null : matches.first;
  }

  FinancialBucket? _findBucketById(int? bucketId) {
    if (bucketId == null) return null;
    final matches = _availableBuckets.where((bucket) => bucket.id == bucketId);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _loadPayments() async {
    final payments = await DatabaseHelper().getDebtPaymentsByDebt(_debt.id!);
    if (!mounted) return;
    setState(() => _payments = payments);
  }

  Future<void> _refresh() async {
    final debt = await DatabaseHelper().getDebtById(_debt.id!);
    final payments = await DatabaseHelper().getDebtPaymentsByDebt(_debt.id!);
    if (!mounted || debt == null) return;
    setState(() {
      _debt = debt;
      _payments = payments;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _debt.status == 'active';
    final linkedWallet = _findWalletById(_debt.walletId);
    final linkedBucket = _findBucketById(_debt.bucketId);
    return Scaffold(
      key: const Key('debt_detail_page'),
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text(_debt.personName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            key: const Key('debt_edit_btn'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom),
                  child: DebtFormSheet(
                    initialDebt: _debt,
                    initialWallets:
                        _availableWallets.isEmpty ? null : _availableWallets,
                    initialBuckets:
                        _availableBuckets.isEmpty ? null : _availableBuckets,
                  ),
                ),
              );
              await _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              try {
                await DatabaseHelper().deleteDebt(_debt.id!);
                if (mounted) Navigator.pop(context);
              } on StateError {
                _showSnackBarMessage(
                  'Catatan yang sudah memengaruhi saldo tidak bisa dihapus langsung.',
                  backgroundColor: Colors.red,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _debt.type == 'debt' ? 'Hutang ke' : 'Piutang dari',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    _debt.personName,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    key: const Key('debt_progress_bar'),
                    value: _debt.progressFraction,
                    backgroundColor: Colors.white30,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sisa: ${formatRupiah(_debt.remainingAmount)}',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(_debt.progressFraction * 100).toStringAsFixed(0)}% lunas',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Metadata
            _metaRow('Nominal awal', formatRupiah(_debt.principalAmount)),
            _metaRow('Tanggal pinjam',
                DateFormat('dd MMM yyyy').format(_debt.borrowedDate)),
            _metaRow(
                'Status',
                _debt.status == 'settled'
                    ? 'Lunas'
                    : (_debt.isOverdue ? 'Terlambat' : 'Aktif')),
            _metaRow(
                'Mode',
                _debt.recordingMode == 'balance'
                    ? 'Masuk ke saldo'
                    : 'Catatan saja'),
            if (linkedWallet != null) _metaRow('Dompet', linkedWallet.name),
            if (linkedBucket != null)
              _metaRow('Pos Keuangan', linkedBucket.name),
            if (_debt.dueDate != null)
              _metaRow('Jatuh tempo',
                  DateFormat('dd MMM yyyy').format(_debt.dueDate!)),
            if (_debt.note?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text('Catatan',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _debt.note!.trim(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Riwayat pembayaran
            Text('Riwayat Pembayaran',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_payments.isEmpty)
              Text('Belum ada cicilan',
                  style: GoogleFonts.poppins(color: Colors.grey))
            else
              ..._payments.map((p) => _paymentItem(p)),
          ],
        ),
      ),
      floatingActionButton: isActive
          ? FloatingActionButton.extended(
              key: const Key('debt_pay_btn'),
              backgroundColor: const Color(0xFFFF69B4),
              icon: const Icon(Icons.payments_outlined, color: Colors.white),
              label: Text('Catat Pembayaran',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              onPressed: () => _showPaymentSheet(context),
            )
          : null,
    );
  }

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
            Text(value,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );

  Widget _paymentItem(DebtPayment p) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.check_circle_outline, color: Colors.green),
          title: Text(formatRupiah(p.amount),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          subtitle: Text(DateFormat('dd MMM yyyy').format(p.paymentDate),
              style: GoogleFonts.poppins(fontSize: 12)),
        ),
      );

  void _showSnackBarMessage(
    String message, {
    Color backgroundColor = const Color(0xFFFF69B4),
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: backgroundColor,
      ),
    );
  }

  void _showPaymentSheet(BuildContext context) {
    final amountCtrl = TextEditingController();
    final paymentWallet = _availableWallets.where((wallet) {
      return wallet.id == _debt.walletId;
    }).isNotEmpty
        ? _availableWallets.firstWhere((wallet) => wallet.id == _debt.walletId)
        : null;
    FinancialBucket? selectedBucket = _availableBuckets.where((bucket) {
      return bucket.id == _debt.bucketId;
    }).isNotEmpty
        ? _availableBuckets.firstWhere((bucket) => bucket.id == _debt.bucketId)
        : (_availableBuckets.isNotEmpty ? _availableBuckets.first : null);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  key: const Key('sheet_drag_handle'),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Catat Pembayaran',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Tampilkan mode yang dipakai agar pengguna tahu efek pembayaran ini
              Container(
                key: const Key('payment_mode_indicator'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _debt.recordingMode == 'balance'
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _debt.recordingMode == 'balance'
                          ? Icons.account_balance_outlined
                          : Icons.note_outlined,
                      size: 16,
                      color: _debt.recordingMode == 'balance'
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _debt.recordingMode == 'balance'
                          ? 'Masuk ke saldo — memengaruhi pos keuangan'
                          : 'Catatan saja — tidak mengubah saldo',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _debt.recordingMode == 'balance'
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (paymentWallet != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        resolveWalletIcon(
                            paymentWallet.iconKey, paymentWallet.name),
                        size: 16,
                        color: const Color(0xFFFF69B4),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dompet: ${paymentWallet.name}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (paymentWallet != null) const SizedBox(height: 16),
              if (_debt.recordingMode == 'balance') ...[
                DropdownButtonFormField<FinancialBucket>(
                  key: const Key('payment_bucket_dropdown'),
                  value: selectedBucket,
                  items: _availableBuckets
                      .map((bucket) => DropdownMenuItem<FinancialBucket>(
                            value: bucket,
                            child: Text(bucket.name),
                          ))
                      .toList(),
                  onChanged: (bucket) => selectedBucket = bucket,
                  decoration: InputDecoration(
                    labelText: 'Pos Keuangan',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('payment_amount_field'),
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  hintText: 'Nominal cicilan',
                  hintStyle: GoogleFonts.poppins(),
                  prefixText: 'Rp ',
                  prefixStyle: GoogleFonts.poppins(
                    color: const Color(0xFFFF69B4),
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('payment_save_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF69B4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final amount =
                        tryParseCurrencyInput(amountCtrl.text.trim()) ?? 0;
                    if (amount <= 0) {
                      _showSnackBarMessage(
                        'Nominal cicilan harus lebih besar dari 0.',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }
                    if (amount > _debt.remainingAmount) {
                      _showSnackBarMessage(
                        'Nominal cicilan melebihi sisa yang harus dibayar.',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }
                    if (_debt.recordingMode == 'balance' &&
                        _availableBuckets.isEmpty) {
                      _showSnackBarMessage(
                        'Buat pos keuangan aktif dulu untuk pembayaran ini.',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }
                    if (_debt.recordingMode == 'balance' &&
                        hasIncompleteBucketConfiguration(_availableBuckets)) {
                      _showSnackBarMessage(
                        _bucketConfigurationIncompleteMessage,
                        backgroundColor: Colors.red,
                      );
                      return;
                    }
                    if (_debt.recordingMode == 'balance' &&
                        selectedBucket == null) {
                      _showSnackBarMessage(
                        'Pilih pos keuangan untuk pembayaran ini.',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }
                    try {
                      await DatabaseHelper().recordDebtPayment(
                        debtId: _debt.id!,
                        amount: amount,
                        paymentDate: DateTime.now(),
                        recordingMode: _debt.recordingMode,
                        walletId: _debt.walletId,
                        bucketId: _debt.bucketId,
                        affectedBucket: selectedBucket,
                      );
                    } on RangeError {
                      _showSnackBarMessage(
                        'Nominal cicilan melebihi sisa yang harus dibayar.',
                        backgroundColor: Colors.red,
                      );
                      return;
                    } on ArgumentError {
                      _showSnackBarMessage(
                        'Nominal cicilan tidak valid.',
                        backgroundColor: Colors.red,
                      );
                      return;
                    } on StateError {
                      _showSnackBarMessage(
                        'Catatan ini sudah lunas.',
                        backgroundColor: Colors.red,
                      );
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _refresh();
                  },
                  child: Text('Simpan',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PosKeuanganPage extends StatefulWidget {
  const PosKeuanganPage({
    super.key,
    this.initialBuckets,
    this.initialWallets,
    @visibleForTesting this.bucketBalanceOverride,
  });
  final List<FinancialBucket>? initialBuckets;
  final List<Wallet>? initialWallets;
  // Nullable: null = real DB; non-null = injected (tests only)
  final Map<int, double>? bucketBalanceOverride;

  @override
  State<PosKeuanganPage> createState() => _PosKeuanganPageState();
}

class _PosKeuanganPageState extends State<PosKeuanganPage> {
  late List<FinancialBucket> _buckets;
  late List<Wallet> _wallets;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provided = widget.initialBuckets;
    _wallets = widget.initialWallets ?? const [];
    if (provided != null) {
      _buckets = provided;
      if (widget.initialWallets == null) {
        // Keep injected bucket data visible while wallet labels hydrate.
        _loadWallets();
      }
    } else {
      _buckets = const [];
      _isLoading = true;
      _loadReferences();
    }
  }

  Future<void> _loadReferences() async {
    final buckets = await DatabaseHelper().getActiveBuckets();
    final wallets =
        widget.initialWallets ?? await DatabaseHelper().getActiveWallets();
    if (!mounted) return;
    setState(() {
      _buckets = buckets;
      _wallets = wallets;
      _isLoading = false;
    });
  }

  Future<void> _loadBuckets() async {
    final buckets = await DatabaseHelper().getActiveBuckets();
    if (!mounted) return;
    setState(() {
      _buckets = buckets;
      _isLoading = false;
    });
  }

  Future<void> _loadWallets() async {
    final wallets = await DatabaseHelper().getActiveWallets();
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isValid = validateBucketPercentages(_buckets);
    return Scaffold(
      key: const Key('page_pos_keuangan'),
      backgroundColor: const Color(0xFFFFF0F5),
      appBar: AppBar(
        title: Text('Pos Keuangan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              key: const Key('bucket_percent_indicator'),
              label: Text(
                '${getBucketPercentageTotal(_buckets).toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
              backgroundColor: isValid ? Colors.green : Colors.redAccent,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const SizedBox.shrink()
          : _buckets.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  key: const Key('bucket_list'),
                  padding: const EdgeInsets.all(16),
                  itemCount: _buckets.length,
                  itemBuilder: (_, i) => _buildBucketItem(_buckets[i]),
                ),
      floatingActionButton: FloatingActionButton(
        key: const Key('pos_fab'),
        backgroundColor: const Color(0xFFFF69B4),
        onPressed: () => _showAddBucketSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Belum ada pos keuangan',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Tap + untuk membuat pos keuangan global',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );

  Widget _buildBucketItem(FinancialBucket bucket) {
    final linkedWallet =
        _wallets.where((wallet) => wallet.id == bucket.walletId);
    final walletLabel =
        linkedWallet.isEmpty ? 'Dompet belum diatur' : linkedWallet.first.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF69B4).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(bucket.resolvedIcon, color: const Color(0xFFFF69B4)),
        ),
        title: Text(bucket.name,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$walletLabel · ${bucket.allocationPercentage.toStringAsFixed(1)}% · ${formatRupiah(bucket.currentBalance)}',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('bucket_edit_btn'),
              icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey),
              tooltip: 'Edit Pos',
              onPressed: () => _showAddBucketSheet(context, bucket: bucket),
            ),
            IconButton(
              key: const Key('bucket_transfer_btn'),
              icon: const Icon(Icons.swap_horiz, color: Colors.blue),
              tooltip: 'Transfer Saldo',
              onPressed: () => _showTransferSheet(context, bucket),
            ),
            IconButton(
              key: const Key('bucket_archive_btn'),
              icon: const Icon(Icons.archive_outlined, color: Colors.grey),
              tooltip: 'Arsipkan',
              onPressed: () => _handleArchive(bucket),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleArchive(FinancialBucket bucket) async {
    if (!mounted) return;
    await DatabaseHelper().archiveFinancialBucket(bucket.id!);
    _loadBuckets();
  }

  void _showAddBucketSheet(BuildContext context, {FinancialBucket? bucket}) {
    final nameCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    String selectedIconKey = bucket?.iconKey ?? 'chart';
    Wallet? selectedWallet =
        _wallets.where((wallet) => wallet.id == bucket?.walletId).isNotEmpty
            ? _wallets.firstWhere((wallet) => wallet.id == bucket?.walletId)
            : (_wallets.isNotEmpty ? _wallets.first : null);

    if (bucket != null) {
      nameCtrl.text = bucket.name;
      pctCtrl.text = bucket.allocationPercentage.toStringAsFixed(0);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final mediaQuery = MediaQuery.of(ctx);
          return Padding(
            padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
            child: SafeArea(
              top: false,
              child: FractionallySizedBox(
                heightFactor: 0.85,
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  key: const Key('sheet_drag_handle'),
                                  width: 50,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                  bucket == null
                                      ? 'Tambah Pos Keuangan'
                                      : 'Edit Pos Keuangan',
                                  style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              TextField(
                                key: const Key('bucket_name_field'),
                                controller: nameCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Nama pos (mis. Tabungan, Sedekah)',
                                  hintStyle: GoogleFonts.poppins(),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                key: const Key('bucket_pct_field'),
                                controller: pctCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'Persentase alokasi (mis. 30)',
                                  hintStyle: GoogleFonts.poppins(),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Dompet Aktif',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<Wallet>(
                                key: const Key('bucket_wallet_dropdown'),
                                value: selectedWallet,
                                items: _wallets
                                    .map(
                                      (wallet) => DropdownMenuItem<Wallet>(
                                        value: wallet,
                                        child: Row(
                                          children: [
                                            Icon(
                                              resolveWalletIcon(
                                                  wallet.iconKey, wallet.name),
                                              size: 16,
                                              color: const Color(0xFFFF69B4),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(wallet.name),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (wallet) =>
                                    setModal(() => selectedWallet = wallet),
                                decoration: InputDecoration(
                                  hintText: _wallets.isEmpty
                                      ? 'Belum ada dompet aktif'
                                      : 'Pilih dompet aktif',
                                  hintStyle: GoogleFonts.poppins(),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Ikon Pos',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    _availableBucketIcons.entries.map((entry) {
                                  final isSelected =
                                      selectedIconKey == entry.key;
                                  return GestureDetector(
                                    key: Key('bucket_icon_${entry.key}'),
                                    onTap: () => setModal(
                                        () => selectedIconKey = entry.key),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFFFF69B4)
                                                .withValues(alpha: 0.12)
                                            : Colors.grey
                                                .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFFF69B4)
                                              : Colors.grey
                                                  .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Icon(
                                        entry.value,
                                        color: isSelected
                                            ? const Color(0xFFFF69B4)
                                            : Colors.grey,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const Key('bucket_save_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF69B4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              final pct =
                                  double.tryParse(pctCtrl.text.trim()) ?? 0;
                              if (name.isEmpty || pct <= 0) return;
                              if (selectedWallet == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _wallets.isEmpty
                                          ? 'Buat dompet aktif dulu sebelum membuat pos.'
                                          : 'Pilih tepat satu dompet aktif untuk pos ini.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final draftBuckets = [
                                ..._buckets
                                    .where((item) => item.id != bucket?.id),
                                FinancialBucket(
                                  id: bucket?.id,
                                  name: name,
                                  iconKey: selectedIconKey,
                                  walletId: selectedWallet?.id,
                                  allocationPercentage: pct,
                                  currentBalance: bucket?.currentBalance ?? 0,
                                  isArchived: bucket?.isArchived ?? false,
                                  createdDate:
                                      bucket?.createdDate ?? DateTime.now(),
                                  updatedDate: DateTime.now(),
                                ),
                              ];

                              if (!canSaveBucketPercentages(draftBuckets)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Total persentase semua pos tidak boleh lebih dari 100%.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final now = DateTime.now();
                              if (bucket == null) {
                                await DatabaseHelper().insertFinancialBucket(
                                  FinancialBucket(
                                    name: name,
                                    iconKey: selectedIconKey,
                                    walletId: selectedWallet?.id,
                                    allocationPercentage: pct,
                                    createdDate: now,
                                    updatedDate: now,
                                  ),
                                );
                              } else {
                                await DatabaseHelper().updateFinancialBucket(
                                  FinancialBucket(
                                    id: bucket.id,
                                    name: name,
                                    iconKey: selectedIconKey,
                                    walletId: selectedWallet?.id,
                                    allocationPercentage: pct,
                                    currentBalance: bucket.currentBalance,
                                    isArchived: bucket.isArchived,
                                    createdDate: bucket.createdDate,
                                    updatedDate: now,
                                  ),
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadBuckets();
                            },
                            child: Text('Simpan',
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTransferSheet(BuildContext context, FinancialBucket from) {
    final amountCtrl = TextEditingController();
    FinancialBucket? selectedTarget;

    final targets = _buckets.where((b) => b.id != from.id).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Tidak ada pos tujuan lain', style: GoogleFonts.poppins()),
      ));
      return;
    }
    selectedTarget = targets.first;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transfer dari ${from.name}',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<FinancialBucket>(
                  key: const Key('transfer_target_dropdown'),
                  value: selectedTarget,
                  items: targets
                      .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text(b.name),
                          ))
                      .toList(),
                  onChanged: (v) => setModal(() => selectedTarget = v),
                  decoration: InputDecoration(
                    labelText: 'Pos tujuan',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('transfer_amount_field'),
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Nominal transfer',
                    hintStyle: GoogleFonts.poppins(),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('transfer_confirm_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF69B4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amount <= 0 || selectedTarget == null) return;
                      await DatabaseHelper().executeBucketTransfer(
                        fromBucketId: from.id!,
                        toBucketId: selectedTarget!.id!,
                        amount: amount,
                        transferDate: DateTime.now(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadBuckets();
                    },
                    child: Text('Transfer',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// Main Screen with Enhanced Navigation
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    @visibleForTesting this.skipInitialLoad = false,
    @visibleForTesting this.initialTransactions,
    @visibleForTesting this.initialAllTransactions,
    @visibleForTesting this.initialWallets,
    @visibleForTesting this.initialBuckets,
    @visibleForTesting this.initialHomeBalanceSourceType,
    @visibleForTesting this.initialHomeBalanceSourceId,
    @visibleForTesting this.initialHomeBalanceVisibilityHidden,
    @visibleForTesting this.persistHomeHeroPreferences = true,
  });

  @visibleForTesting
  final bool skipInitialLoad;

  @visibleForTesting
  final List<Transaction>? initialTransactions;

  @visibleForTesting
  final List<Transaction>? initialAllTransactions;

  @visibleForTesting
  final List<Wallet>? initialWallets;

  @visibleForTesting
  final List<FinancialBucket>? initialBuckets;

  @visibleForTesting
  final String? initialHomeBalanceSourceType;

  @visibleForTesting
  final int? initialHomeBalanceSourceId;

  @visibleForTesting
  final bool? initialHomeBalanceVisibilityHidden;

  @visibleForTesting
  final bool persistHomeHeroPreferences;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Transaction> _transactions = [];
  List<SavingGoal> _savingGoals = [];
  List<WishlistItem> _wishlistItems = [];
  List<UserBadge> _badges = [];
  List<Transaction> _allTransactions = [];
  List<FinancialBucket> _activeBuckets = [];
  Map<int, double> _bucketPeriodIncomeTotals = {};
  Map<int, double> _bucketPeriodExpenseTotals = {};
  String _selectedHomeFilter = 'monthly';
  String _selectedHomeWallet = 'All';
  String _homeBalanceSourceType = 'total';
  int? _homeBalanceSourceId;
  bool _homeBalanceVisibilityHidden = false;
  String _selectedFilter = 'weekly';
  String _selectedWallet = 'All';
  DateTime _selectedPeriodDate = DateTime.now();
  DateTimeRange? _selectedDateRange;

  List<Wallet> _activeWallets = [];
  int _homeHeroPreferenceLoadEpoch = 0;
  int _bucketHeroSummaryLoadEpoch = 0;

  bool get _hasInjectedHomeBalancePreferences =>
      widget.initialHomeBalanceSourceType != null ||
      widget.initialHomeBalanceSourceId != null ||
      widget.initialHomeBalanceVisibilityHidden != null;

  HomeBalanceSourceResolution get _resolvedHomeBalanceSource =>
      resolveHomeBalanceSource(
        _homeBalanceSourceType,
        _homeBalanceSourceId,
        _activeWallets,
        _activeBuckets,
      );

  ({DateTime start, DateTime end}) _currentPeriodRange() {
    switch (_selectedFilter) {
      case 'weekly':
        final weekdayOffset = _selectedPeriodDate.weekday - DateTime.monday;
        final start = DateTime(
          _selectedPeriodDate.year,
          _selectedPeriodDate.month,
          _selectedPeriodDate.day,
        ).subtract(Duration(days: weekdayOffset));
        final end = DateTime(
          start.year,
          start.month,
          start.day + 6,
          23,
          59,
          59,
        );
        return (start: start, end: end);
      case 'monthly':
        final start =
            DateTime(_selectedPeriodDate.year, _selectedPeriodDate.month, 1);
        final end = DateTime(
          _selectedPeriodDate.year,
          _selectedPeriodDate.month + 1,
          0,
          23,
          59,
          59,
        );
        return (start: start, end: end);
      case 'yearly':
        final start = DateTime(_selectedPeriodDate.year, 1, 1);
        final end = DateTime(_selectedPeriodDate.year, 12, 31, 23, 59, 59);
        return (start: start, end: end);
      case 'range':
        final range = _selectedDateRange;
        if (range != null) {
          final start = DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          );
          final end = DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
            23,
            59,
            59,
          );
          return (start: start, end: end);
        }
        final fallback = DateTime.now();
        return (
          start: DateTime(fallback.year, fallback.month, fallback.day),
          end:
              DateTime(fallback.year, fallback.month, fallback.day, 23, 59, 59),
        );
      default:
        final fallback = DateTime.now();
        return (
          start: DateTime(fallback.year, fallback.month, fallback.day),
          end:
              DateTime(fallback.year, fallback.month, fallback.day, 23, 59, 59),
        );
    }
  }

  Future<void> _selectDateRange() async {
    final initialRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 6)),
          end: DateTime.now(),
        );

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDateRange: initialRange,
    );

    if (!mounted || range == null) return;

    setState(() {
      _selectedFilter = 'range';
      _selectedDateRange = range;
      _selectedPeriodDate = range.end;
    });
  }

  void _shiftSelectedPeriod(int direction) {
    setState(() {
      switch (_selectedFilter) {
        case 'weekly':
          _selectedPeriodDate =
              _selectedPeriodDate.add(Duration(days: 7 * direction));
          break;
        case 'monthly':
          _selectedPeriodDate = DateTime(
            _selectedPeriodDate.year,
            _selectedPeriodDate.month + direction,
            1,
          );
          break;
        case 'yearly':
          _selectedPeriodDate =
              DateTime(_selectedPeriodDate.year + direction, 1, 1);
          break;
        case 'range':
          if (_selectedDateRange != null) {
            final span = _selectedDateRange!.duration.inDays;
            final start = _selectedDateRange!.start
                .add(Duration(days: (span + 1) * direction));
            final end = _selectedDateRange!.end
                .add(Duration(days: (span + 1) * direction));
            _selectedDateRange = DateTimeRange(start: start, end: end);
            _selectedPeriodDate = end;
          }
          break;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelectionChanged);
    _activeWallets = List<Wallet>.from(widget.initialWallets ?? const []);
    _activeBuckets =
        List<FinancialBucket>.from(widget.initialBuckets ?? const []);
    _transactions =
        List<Transaction>.from(widget.initialTransactions ?? const []);
    _allTransactions =
        List<Transaction>.from(widget.initialAllTransactions ?? const []);
    _homeBalanceSourceType =
        widget.initialHomeBalanceSourceType ?? _homeBalanceSourceType;
    _homeBalanceSourceId = widget.initialHomeBalanceSourceId;
    _homeBalanceVisibilityHidden =
        widget.initialHomeBalanceVisibilityHidden ?? false;

    if (widget.skipInitialLoad) {
      if (!_hasInjectedHomeBalancePreferences) {
        _loadHomeHeroPreferences();
      }
      _loadBucketHeroSummaries();
      return;
    }

    if (!widget.skipInitialLoad &&
        widget.initialTransactions == null &&
        widget.initialAllTransactions == null) {
      _loadAllData();
    } else {
      if (!_hasInjectedHomeBalancePreferences) {
        _loadHomeHeroPreferences();
      }
      _loadBucketHeroSummaries();
    }
  }

  void _handleTabSelectionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _showSnackBarMessage(
    String message, {
    Color backgroundColor = const Color(0xFFFF69B4),
    bool deferToNextFrame = false,
  }) {
    void showSnackBar() {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: backgroundColor,
        ),
      );
    }

    if (deferToNextFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackBar();
      });
      return;
    }

    showSnackBar();
  }

  Future<void> _loadAllData() async {
    try {
      await _loadWallets();
      await _loadBuckets();
      await _loadHomeHeroPreferences();
      await _loadAllTransactions();
      await _loadTransactions();
      await _loadSavingGoals();
      await _loadWishlistItems();
      await _checkAndAwardBadges();
    } on StateError catch (_) {
      _showSnackBarMessage(
        'Gagal memuat data aplikasi. Coba lagi.',
        backgroundColor: Colors.red,
        deferToNextFrame: true,
      );
    } on Exception catch (_) {
      _showSnackBarMessage(
        'Gagal memuat data aplikasi. Coba lagi.',
        backgroundColor: Colors.red,
        deferToNextFrame: true,
      );
    }
  }

  Future<void> _loadWallets() async {
    final wallets = await _dbHelper.getActiveWallets();
    if (!mounted) return;
    // Reset selected wallet jika sudah tidak ada di daftar aktif
    final names = wallets.map((w) => w.name).toSet();
    setState(() {
      _activeWallets = wallets;
      if (_selectedHomeWallet != 'All' &&
          !names.contains(_selectedHomeWallet)) {
        _selectedHomeWallet = 'All';
      }
    });
  }

  Future<void> _loadBuckets() async {
    final buckets = await _dbHelper.getActiveBuckets();
    if (!mounted) return;
    setState(() {
      _activeBuckets = buckets;
    });
  }

  Future<void> _loadAllTransactions() async {
    final allTransactions = await _dbHelper.getTransactions();
    if (!mounted) return;
    setState(() {
      _allTransactions = allTransactions;
    });
  }

  Future<void> _loadTransactions() async {
    final now = DateTime.now();
    final range = resolveHomeFilterRange(_selectedHomeFilter, now);

    final transactions = await _dbHelper.getFilteredTransactions(
      wallet: _selectedHomeWallet,
      startDate: range.start,
      endDate: range.end,
    );

    if (!mounted) return;
    setState(() {
      _transactions = transactions;
    });

    await _loadBucketHeroSummaries();
  }

  Future<void> _loadHomeHeroPreferences() async {
    final requestEpoch = ++_homeHeroPreferenceLoadEpoch;
    final preferences = await _dbHelper.getAppPreferences([
      _homeBalanceSourceTypePreferenceKey,
      _homeBalanceSourceIdPreferenceKey,
      _homeBalanceVisibilityHiddenPreferenceKey,
    ]);

    if (!mounted || requestEpoch != _homeHeroPreferenceLoadEpoch) return;
    setState(() {
      _homeBalanceSourceType =
          preferences[_homeBalanceSourceTypePreferenceKey] ?? 'total';
      final rawSourceId = preferences[_homeBalanceSourceIdPreferenceKey];
      _homeBalanceSourceId = rawSourceId == null || rawSourceId.isEmpty
          ? null
          : int.tryParse(rawSourceId);
      _homeBalanceVisibilityHidden =
          preferences[_homeBalanceVisibilityHiddenPreferenceKey] == '1';
    });
  }

  Future<void> _persistHomeHeroPreferences() async {
    if (!widget.persistHomeHeroPreferences) {
      return;
    }

    await _dbHelper.setAppPreference(
      _homeBalanceSourceTypePreferenceKey,
      _homeBalanceSourceType,
    );
    await _dbHelper.setAppPreference(
      _homeBalanceSourceIdPreferenceKey,
      _homeBalanceSourceId?.toString() ?? '',
    );
    await _dbHelper.setAppPreference(
      _homeBalanceVisibilityHiddenPreferenceKey,
      _homeBalanceVisibilityHidden ? '1' : '0',
    );
  }

  Future<void> _setHomeBalanceSource(String sourceType, {int? sourceId}) async {
    final previousSourceType = _homeBalanceSourceType;
    final previousSourceId = _homeBalanceSourceId;
    final previousIncomeTotals =
        Map<int, double>.from(_bucketPeriodIncomeTotals);
    final previousExpenseTotals =
        Map<int, double>.from(_bucketPeriodExpenseTotals);
    setState(() {
      _homeBalanceSourceType = sourceType;
      _homeBalanceSourceId = sourceId;
    });

    try {
      await _loadBucketHeroSummaries();
      if (!mounted) return;
      await _persistHomeHeroPreferences();
    } on Exception {
      if (!mounted) return;
      setState(() {
        _homeBalanceSourceType = previousSourceType;
        _homeBalanceSourceId = previousSourceId;
        _bucketPeriodIncomeTotals = previousIncomeTotals;
        _bucketPeriodExpenseTotals = previousExpenseTotals;
      });
      await _loadBucketHeroSummaries();
      if (!mounted) return;
      _showSnackBarMessage(
        'Pilihan sumber saldo gagal disimpan. Coba lagi.',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _toggleHomeBalanceVisibility() async {
    final previousVisibility = _homeBalanceVisibilityHidden;
    setState(() {
      _homeBalanceVisibilityHidden = !_homeBalanceVisibilityHidden;
    });

    try {
      await _persistHomeHeroPreferences();
    } on Exception {
      if (!mounted) return;
      setState(() {
        _homeBalanceVisibilityHidden = previousVisibility;
      });
      _showSnackBarMessage(
        'Status visibilitas saldo gagal disimpan. Coba lagi.',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _loadBucketHeroSummaries() async {
    final requestEpoch = ++_bucketHeroSummaryLoadEpoch;
    if (_homeBalanceSourceType != 'bucket' || _transactions.isEmpty) {
      if (!mounted || requestEpoch != _bucketHeroSummaryLoadEpoch) return;
      setState(() {
        _bucketPeriodIncomeTotals = {};
        _bucketPeriodExpenseTotals = {};
      });
      return;
    }

    final transactions = List<Transaction>.from(_transactions);
    final transactionIds = transactions
        .map((transaction) => transaction.id)
        .whereType<int>()
        .toList(growable: false);
    final allocationsByTransactionId =
        await _dbHelper.getTransactionBucketAllocationsForTransactions(
      transactionIds,
    );
    if (!mounted || requestEpoch != _bucketHeroSummaryLoadEpoch) return;

    final incomeTotals = <int, double>{};
    final expenseTotals = <int, double>{};

    for (final transaction in affectingTransactions(transactions)) {
      final transactionId = transaction.id;
      if (transactionId == null) continue;
      final allocations = allocationsByTransactionId[transactionId] ?? const [];

      for (final allocation in allocations) {
        if (transaction.type == 'income' && allocation.role == 'target') {
          incomeTotals[allocation.bucketId] =
              (incomeTotals[allocation.bucketId] ?? 0) +
                  allocation.allocatedAmount;
        }
        if (transaction.type == 'expense' && allocation.role == 'source') {
          expenseTotals[allocation.bucketId] =
              (expenseTotals[allocation.bucketId] ?? 0) +
                  allocation.allocatedAmount;
        }
      }
    }

    if (!mounted || requestEpoch != _bucketHeroSummaryLoadEpoch) return;
    setState(() {
      _bucketPeriodIncomeTotals = incomeTotals;
      _bucketPeriodExpenseTotals = expenseTotals;
    });
  }

  double _resolveHomeBalanceValue() {
    final source = _resolvedHomeBalanceSource;

    switch (source.type) {
      case 'wallet':
        final wallet = _findWalletInList(_activeWallets, source.id);
        if (wallet == null) return calculateBalanceForWallet(_allTransactions);
        return calculateBalanceForWallet(
          _allTransactions,
          selectedWallet: wallet.name,
        );
      case 'bucket':
        final bucket = _findBucketInList(_activeBuckets, source.id);
        return bucket?.currentBalance ?? 0;
      case 'total':
      default:
        return calculateBalanceForWallet(_allTransactions);
    }
  }

  double _resolveHomeIncomeValue() {
    final source = _resolvedHomeBalanceSource;
    final effectiveTransactions = userVisibleBalanceTransactions(_transactions);

    switch (source.type) {
      case 'wallet':
        final wallet = _findWalletInList(_activeWallets, source.id);
        if (wallet == null) return 0;
        return effectiveTransactions
            .where((t) => t.type == 'income' && t.wallet == wallet.name)
            .fold(0.0, (sum, t) => sum + t.amount);
      case 'bucket':
        return _bucketPeriodIncomeTotals[source.id] ?? 0;
      case 'total':
      default:
        return effectiveTransactions
            .where((t) => t.type == 'income')
            .fold(0.0, (sum, t) => sum + t.amount);
    }
  }

  double _resolveHomeExpenseValue() {
    final source = _resolvedHomeBalanceSource;
    final effectiveTransactions = userVisibleBalanceTransactions(_transactions);

    switch (source.type) {
      case 'wallet':
        final wallet = _findWalletInList(_activeWallets, source.id);
        if (wallet == null) return 0;
        return effectiveTransactions
            .where((t) => t.type == 'expense' && t.wallet == wallet.name)
            .fold(0.0, (sum, t) => sum + t.amount);
      case 'bucket':
        return _bucketPeriodExpenseTotals[source.id] ?? 0;
      case 'total':
      default:
        return effectiveTransactions
            .where((t) => t.type == 'expense')
            .fold(0.0, (sum, t) => sum + t.amount);
    }
  }

  String _formatHomeHeroAmount(num amount) {
    if (_homeBalanceVisibilityHidden) {
      return 'Rp ••••••';
    }
    return formatRupiah(amount);
  }

  Future<void> _loadSavingGoals() async {
    final goals = await _dbHelper.getSavingGoals();
    if (!mounted) return;
    setState(() {
      _savingGoals = goals;
    });
  }

  Future<void> _loadWishlistItems() async {
    final items = await _dbHelper.getWishlistItems();
    if (!mounted) return;
    setState(() {
      _wishlistItems = items;
    });
  }

  Future<void> _checkAndAwardBadges() async {
    final allTransactions =
        userVisibleBalanceTransactions(_allTransactions).toList();
    // Skip seluruh pengecekan badge bila tidak ada transaksi sama sekali.
    if (allTransactions.isEmpty) return;
    final badges = await _dbHelper.getBadges();

    // First transaction badge
    if (allTransactions.length == 1 && !badges.any((b) => b.type == 'first')) {
      final badge = UserBadge(
        name: 'Langkah Pertama',
        description: 'Transaksi pertama kamu! Keep going!',
        emoji: '🌟',
        earnedDate: DateTime.now(),
        type: 'first',
      );
      await _dbHelper.insertBadge(badge);
      badges.insert(0, badge);
    }

    // Hemat Banget badge
    final now = DateTime.now();
    final startMonth = DateTime(now.year, now.month, 1);
    final endMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final monthlyTransactions =
        await _dbHelper.getTransactionsByDateRange(startMonth, endMonth);
    final effectiveMonthlyTransactions =
        userVisibleBalanceTransactions(monthlyTransactions).toList();
    final monthlyIncome = effectiveMonthlyTransactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    final monthlyExpense = effectiveMonthlyTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    if (monthlyIncome > monthlyExpense &&
        monthlyExpense > 0 &&
        !hasSavingBadgeForPeriod(badges, now)) {
      final badge = UserBadge(
        name: 'Hemat Banget',
        description: 'Kamu lebih banyak nabung daripada belanja bulan ini!',
        emoji: '🏆',
        earnedDate: DateTime.now(),
        type: 'saving',
      );
      await _dbHelper.insertBadge(badge);
      badges.insert(0, badge);
    }

    // Goal Achievement badge
    for (var goal in _savingGoals) {
      if (goal.progress >= 1.0 &&
          !badges.any((b) => b.type == 'goal_${goal.id}')) {
        final badge = UserBadge(
          name: 'Goal Master',
          description: 'Berhasil capai target ${goal.name}!',
          emoji: '🎯',
          earnedDate: DateTime.now(),
          type: 'goal_${goal.id}',
        );
        await _dbHelper.insertBadge(badge);
        badges.insert(0, badge);
      }
    }

    if (!mounted) return;
    setState(() {
      _badges = badges;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFB6C1),
              Color(0xFFFFF0F5),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboard(),
                    _buildStatisticsPage(),
                    _buildSavingGoals(),
                    _buildWishlist(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildEnhancedTabBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildCuteFloatingActionButton(context),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFFFF69B4),
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo Cantik!',
                  style: GoogleFonts.poppins(
                    fontSize: 22, // Kecilkan sedikit
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Yuk kelola uang kamu hari ini',
                  style: GoogleFonts.poppins(
                    fontSize: 13, // Kecilkan sedikit
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Badge count indicator dengan constraint
          if (_badges.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 60),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${_badges.length}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTabBar() {
    return Container(
      key: const Key('bottom_nav_bar'),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            _buildBottomNavItem(
              itemKey: const Key('bottom_nav_beranda'),
              icon: Icons.home_rounded,
              label: 'Beranda',
              tabIndex: 0,
            ),
            _buildBottomNavItem(
              itemKey: const Key('bottom_nav_statistik'),
              icon: Icons.bar_chart_rounded,
              label: 'Statistik',
              tabIndex: 1,
            ),
            const SizedBox(width: 72),
            _buildBottomNavItem(
              itemKey: const Key('bottom_nav_target_tabungan'),
              icon: Icons.flag_rounded,
              label: 'Target Tabungan',
              tabIndex: 2,
            ),
            _buildBottomNavItem(
              itemKey: const Key('bottom_nav_wishlist_belanja'),
              icon: Icons.shopping_bag_outlined,
              label: 'Wishlist Belanja',
              tabIndex: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required Key itemKey,
    required IconData icon,
    required String label,
    required int tabIndex,
  }) {
    final isSelected = _tabController.index == tabIndex;
    return Expanded(
      child: GestureDetector(
        key: itemKey,
        onTap: () => _tabController.animateTo(tabIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : const Color(0xFFFF69B4),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFFFF69B4),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final totalIncome = _resolveHomeIncomeValue();
    final totalExpense = _resolveHomeExpenseValue();
    final balance = _resolveHomeBalanceValue();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHomeFilterSection(),
          const SizedBox(height: 16),

          // Filter wallet mengikuti filter periode agar kontrol Home terbaca berurutan.
          SizedBox(
            key: const Key('wallet_filter_row'),
            height: 45,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildWalletFilter('All'),
                  ),
                  ..._activeWallets.map((w) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildWalletFilter(w.name),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // Balance card
          _buildBalanceCard(balance, totalIncome, totalExpense),
          const SizedBox(height: 18),

          // Quick menu — entry point fitur baru yang tidak ada di bottom nav
          _buildHomeQuickMenu(),
          const SizedBox(height: 25),

          // Analytics insight
          _buildAnalyticsInsight(),
          const SizedBox(height: 25),

          // Active goals preview
          if (_savingGoals.isNotEmpty) ...[
            _buildActiveGoalsPreview(),
            const SizedBox(height: 25),
          ],

          _buildTransactionHistorySection(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTransactionHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat Transaksi',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFF69B4),
          ),
        ),
        const SizedBox(height: 15),
        if (_transactions.isEmpty)
          _buildEmptyTransactionState()
        else
          _buildTransactionItems(),
      ],
    );
  }

  Widget _buildStatisticsPage() {
    final hasStatisticsRangeSelection =
        _selectedFilter != 'range' || _selectedDateRange != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistik Keuangan',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFF69B4),
            ),
          ),
          const SizedBox(height: 20),
          _buildStatisticsFilterSection(),
          const SizedBox(height: 20),
          if (hasStatisticsRangeSelection) ...[
            _buildStatsOverview(),
            const SizedBox(height: 25),
            Text(
              'Kategori Pengeluaran',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF69B4),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 280,
              child: _buildCategoryChart(),
            ),
            const SizedBox(height: 25),
            Text(
              'Grafik ${_statisticsPeriodLabel()}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF69B4),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 250,
              child: _buildMonthlyChart(),
            ),
          ] else
            _buildStatisticsRangePlaceholder(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  String _statisticsPeriodLabel() {
    switch (_selectedFilter) {
      case 'weekly':
        return 'Pengeluaran Minggu';
      case 'monthly':
        return 'Pengeluaran Bulan';
      case 'yearly':
        return 'Pengeluaran Tahun';
      case 'range':
        return 'Pengeluaran Rentang';
      default:
        return 'Pengeluaran';
    }
  }

  Widget _buildStatisticsRangePlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.date_range,
            size: 40,
            color: Color(0xFFFF69B4),
          ),
          const SizedBox(height: 12),
          Text(
            'Pilih rentang tanggal dulu',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Statistik rentang akan tampil setelah kamu memilih tanggal mulai dan tanggal akhir.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletFilter(String wallet) {
    bool isSelected = _selectedHomeWallet == wallet;
    final storedWallet = _activeWallets.where((item) => item.name == wallet);
    final walletRecord = storedWallet.isNotEmpty ? storedWallet.first : null;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedHomeWallet = wallet;
        });
        await _loadTransactions();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF69B4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFF69B4).withAlpha(77), // 0.3 * 255 ≈ 77
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withAlpha(25), // 0.1 * 255 ≈ 25
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              resolveWalletIcon(walletRecord?.iconKey, wallet),
              size: 14,
              color: isSelected ? Colors.white : const Color(0xFFFF69B4),
            ),
            const SizedBox(width: 6),
            Text(
              wallet,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : const Color(0xFFFF69B4),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildHomeBalanceSourceMenuItems() {
    return [
      PopupMenuItem<String>(
        value: 'total',
        child: Text('Total Saldo', style: GoogleFonts.poppins(fontSize: 12)),
      ),
      ..._activeWallets
          .where((wallet) => wallet.id != null && !wallet.isArchived)
          .map(
            (wallet) => PopupMenuItem<String>(
              value: 'wallet:${wallet.id}',
              child: Text(
                'Dompet: ${wallet.name}',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ),
      ..._activeBuckets
          .where((bucket) => bucket.id != null && !bucket.isArchived)
          .map(
            (bucket) => PopupMenuItem<String>(
              value: 'bucket:${bucket.id}',
              child: Text(
                'Pos: ${bucket.name}',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ),
    ];
  }

  void _handleHomeBalanceSourceSelection(String value) {
    if (value == 'total') {
      _setHomeBalanceSource('total');
      return;
    }

    final parts = value.split(':');
    if (parts.length != 2) return;
    _setHomeBalanceSource(parts.first, sourceId: int.tryParse(parts.last));
  }

  Widget _buildHomeQuickMenu() {
    return SizedBox(
      key: const Key('home_quick_menu'),
      height: 104,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickMenuItem(
              itemKey: const Key('quick_menu_dompet'),
              icon: Icons.account_balance_wallet_outlined,
              label: 'Dompet',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DompetPage(
                    initialWallets:
                        widget.skipInitialLoad || _activeWallets.isNotEmpty
                            ? _activeWallets
                            : null,
                  ),
                ),
              ).then((_) => _loadWallets()),
            ),
            const SizedBox(width: 12),
            _buildQuickMenuItem(
              itemKey: const Key('quick_menu_hutang_piutang'),
              icon: Icons.handshake_outlined,
              label: 'Hutang/Piutang',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HutangPiutangPage()),
              ),
            ),
            const SizedBox(width: 12),
            _buildQuickMenuItem(
              itemKey: const Key('quick_menu_pos_keuangan'),
              icon: Icons.pie_chart_outline,
              label: 'Pos Keuangan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PosKeuanganPage()),
              ).then((_) => _loadBuckets()),
            ),
            const SizedBox(width: 12),
            _buildQuickMenuItem(
              itemKey: const Key('quick_menu_badge_pencapaian'),
              icon: Icons.emoji_events_outlined,
              label: 'Badge',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    key: const Key('page_badge_pencapaian'),
                    backgroundColor: const Color(0xFFFFF0F5),
                    appBar: AppBar(
                      title: Text(
                        'Badge & Pencapaian',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    body: _buildBadgesPage(showPageTitle: false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMenuItem({
    required Key itemKey,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final shortLabel = label == 'Pos Keuangan' ? 'Pos keu..' : label;
    return GestureDetector(
      key: itemKey,
      onTap: onTap,
      child: Container(
        width: 96,
        height: 84,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFF69B4), size: 24),
            const SizedBox(height: 8),
            Text(
              shortLabel,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsInsight() {
    final now = DateTime.now();
    final thisMonthExpense = calculateMonthlyExpenseForInsight(
      _allTransactions,
      now,
      selectedWallet: _selectedHomeWallet,
    );

    String insightText = '';
    IconData insightIcon = Icons.insights_outlined;
    Color insightColor = Colors.green;

    if (thisMonthExpense < 500000) {
      insightText = 'Kamu hemat banget bulan ini! Keep it up!';
      insightIcon = Icons.auto_awesome_outlined;
      insightColor = Colors.green;
    } else if (thisMonthExpense > 1000000) {
      insightText = 'Pengeluaran lumayan besar nih, coba lebih hemat ya!';
      insightIcon = Icons.warning_amber_rounded;
      insightColor = Colors.orange;
    } else {
      insightText = 'Pengeluaran kamu masih wajar, good job!';
      insightIcon = Icons.thumb_up_off_alt_rounded;
      insightColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [insightColor.withValues(alpha: 0.1), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: insightColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: insightColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(insightIcon, size: 24, color: insightColor),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analisa Keuangan',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: insightColor,
                  ),
                ),
                Text(
                  insightText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Transaction> _filteredStatisticsTransactions() {
    final period = _currentPeriodRange();
    return _allTransactions.where((t) {
      final matchesWallet =
          _selectedWallet == 'All' || t.wallet == _selectedWallet;
      final matchesPeriod =
          t.date.isAfter(period.start.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(period.end.add(const Duration(seconds: 1)));
      return t.affectsBalance &&
          t.category != _internalTransferCategory &&
          matchesWallet &&
          matchesPeriod;
    }).toList();
  }

  Widget _buildActiveGoalsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Goal Aktif',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF69B4),
              ),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFFF69B4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _savingGoals.take(3).length,
            itemBuilder: (context, index) {
              final goal = _savingGoals[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withValues(alpha: 0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(goal.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            goal.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF333333),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatRupiah(goal.currentAmount)} / ${formatRupiah(goal.targetAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: goal.progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        goal.progress >= 1.0
                            ? Colors.green
                            : const Color(0xFFFF69B4),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${(goal.progress * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: goal.progress >= 1.0
                            ? Colors.green
                            : const Color(0xFFFF69B4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHomeFilterButton(String filter, String label, IconData icon) {
    bool isSelected = _selectedHomeFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() {
            _selectedHomeFilter = filter;
          });
          await _loadTransactions();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF69B4) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFFFF69B4),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : const Color(0xFFFF69B4),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsFilterButton(
      String filter, String label, IconData icon) {
    bool isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF69B4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFFFF69B4),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : const Color(0xFFFF69B4),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeFilterSection() {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          _buildHomeFilterButton(
              'daily', 'Harian', Icons.calendar_today_outlined),
          const SizedBox(width: 10),
          _buildHomeFilterButton(
              'monthly', 'Bulanan', Icons.calendar_view_month_outlined),
          const SizedBox(width: 10),
          _buildHomeFilterButton(
              'yearly', 'Tahunan', Icons.date_range_outlined),
        ],
      ),
    );
  }

  Widget _buildStatisticsFilterSection() {
    final period = _currentPeriodRange();
    final headerInfo = _periodHeaderInfo(period.start, period.end);

    return Column(
      children: [
        Container(
          height: 50,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatisticsFilterButton(
                    'weekly', 'Minggu', Icons.view_week_outlined),
                const SizedBox(width: 10),
                _buildStatisticsFilterButton(
                    'monthly', 'Bulan', Icons.calendar_view_month_outlined),
                const SizedBox(width: 10),
                _buildStatisticsFilterButton(
                    'yearly', 'Tahun', Icons.date_range_outlined),
                const SizedBox(width: 10),
                _buildStatisticsFilterButton(
                    'range', 'Rentang', Icons.date_range_outlined),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_selectedFilter == 'range')
          GestureDetector(
            onTap: _selectDateRange,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF4A6C8E)),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDateRange != null
                        ? formatSelectedDateRangeLabel(_selectedDateRange!)
                        : 'Pilih Rentang Tanggal',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2F4057),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftSelectedPeriod(-1),
                icon: const Icon(Icons.chevron_left, size: 36),
                color: const Color(0xFF4A4A4A),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      headerInfo.title,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2430),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (headerInfo.subtitle != null)
                      Text(
                        headerInfo.subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _shiftSelectedPeriod(1),
                icon: const Icon(Icons.chevron_right, size: 36),
                color: const Color(0xFF4A4A4A),
              ),
            ],
          ),
      ],
    );
  }

  ({String title, String? subtitle}) _periodHeaderInfo(
    DateTime start,
    DateTime end,
  ) {
    switch (_selectedFilter) {
      case 'weekly':
        return (
          title:
              '${DateFormat('MMM d').format(start)} - ${DateFormat('d').format(end)}',
          subtitle: null,
        );
      case 'monthly':
        return (
          title: DateFormat('MMMM yyyy').format(start),
          subtitle:
              '(${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM').format(end)})',
        );
      case 'yearly':
        return (title: DateFormat('yyyy').format(start), subtitle: null);
      case 'range':
        return (
          title:
              '${DateFormat('d MMM yyyy').format(start)} - ${DateFormat('d MMM yyyy').format(end)}',
          subtitle: null,
        );
      default:
        return (title: DateFormat('d MMM yyyy').format(start), subtitle: null);
    }
  }

  Widget _buildBalanceCard(double balance, double income, double expense) {
    final resolvedSource = _resolvedHomeBalanceSource;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF69B4),
            Color(0xFFFF1493),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  resolvedSource.title,
                  key: const Key('home_balance_title'),
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                key: const Key('home_balance_visibility_toggle'),
                onPressed: _toggleHomeBalanceVisibility,
                icon: Icon(
                  _homeBalanceVisibilityHidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: _homeBalanceVisibilityHidden
                    ? 'Tampilkan saldo'
                    : 'Sembunyikan saldo',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              PopupMenuButton<String>(
                key: const Key('home_balance_source_button'),
                onSelected: _handleHomeBalanceSourceSelection,
                itemBuilder: (_) => _buildHomeBalanceSourceMenuItems(),
                icon: const Icon(
                  Icons.expand_more_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'Pilih sumber saldo',
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            child: Text(
              _formatHomeHeroAmount(balance),
              key: const Key('home_balance_value'),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_downward,
                              color: Colors.greenAccent, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Pemasukan',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        child: Text(
                          _formatHomeHeroAmount(income),
                          key: const Key('home_balance_income_value'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_upward,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Pengeluaran',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        child: Text(
                          _formatHomeHeroAmount(expense),
                          key: const Key('home_balance_expense_value'),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart() {
    Map<String, double> categoryData = {};

    for (var transaction in _filteredStatisticsTransactions()
        .where((t) => t.type == 'expense')) {
      categoryData[transaction.category] =
          (categoryData[transaction.category] ?? 0) + transaction.amount;
    }

    if (categoryData.isEmpty) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada pengeluaran nih',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              Text(
                'Yuk mulai catat pengeluaran kamu!',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    List<PieChartSectionData> sections = [];
    List<Color> colors = [
      const Color(0xFFFF69B4),
      const Color(0xFF9C27B0),
      const Color(0xFF3F51B5),
      const Color(0xFF00BCD4),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFF44336),
    ];

    int colorIndex = 0;
    categoryData.forEach((category, amount) {
      sections.add(
        PieChartSectionData(
          value: amount,
          title:
              '${(amount / categoryData.values.reduce((a, b) => a + b) * 100).toInt()}%',
          color: colors[colorIndex % colors.length],
          radius: 60,
          titleStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                startDegreeOffset: -90,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 15,
            runSpacing: 10,
            children: categoryData.entries.map((entry) {
              int index = categoryData.keys.toList().indexOf(entry.key);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionState() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada transaksi',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yuk mulai catat pemasukan dan\npengeluaran kamu!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showAddTransactionDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF69B4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(
                '+ Tambah Transaksi',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItems() {
    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildTransactionItem(_transactions[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionActionBackground({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    final isStartAligned = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isStartAligned ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetailInfo({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTransactionDetail(Transaction transaction) async {
    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (detailContext) {
          final accentColor =
              transaction.type == 'income' ? Colors.green : Colors.red;
          final typeLabel =
              transaction.type == 'income' ? 'Pemasukan' : 'Pengeluaran';
          final amountLabel =
              '${transaction.type == 'income' ? '+' : '-'} ${formatRupiah(transaction.amount)}';

          return Scaffold(
            key: const Key('transaction_detail_page'),
            backgroundColor: const Color(0xFFFFF0F5),
            appBar: AppBar(
              title: Text(
                'Detail Transaksi',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFF333333),
              elevation: 0,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withValues(alpha: 0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              transaction.type == 'income'
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: accentColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            transaction.description,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            amountLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildTransactionDetailInfo(
                      label: 'Tipe',
                      value: typeLabel,
                    ),
                    const SizedBox(height: 12),
                    _buildTransactionDetailInfo(
                      label: 'Kategori',
                      value: transaction.category,
                    ),
                    const SizedBox(height: 12),
                    _buildTransactionDetailInfo(
                      label: 'Dompet',
                      value: transaction.wallet,
                    ),
                    const SizedBox(height: 12),
                    _buildTransactionDetailInfo(
                      label: 'Tanggal',
                      value: DateFormat('dd MMM yyyy, HH:mm')
                          .format(transaction.date),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('transaction_detail_delete_btn'),
                            onPressed: transaction.id == null
                                ? null
                                : () => Navigator.pop(detailContext, 'delete'),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(
                              'Hapus',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const Key('transaction_detail_edit_btn'),
                            onPressed: () =>
                                Navigator.pop(detailContext, 'edit'),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(
                              'Edit',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF69B4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      await _showTransactionDialog(initialTransaction: transaction);
      return;
    }

    if (action == 'delete' && transaction.id != null) {
      _deleteTransaction(transaction.id!);
    }
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final accentColor =
        transaction.type == 'income' ? Colors.green : Colors.red;
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: transaction.id == null
            ? null
            : () => _openTransactionDetail(transaction),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  transaction.type == 'income'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          transaction.category,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '• ${transaction.wallet}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(transaction.date),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${transaction.type == 'income' ? '+' : '-'} ${formatRupiah(transaction.amount)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (transaction.id == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Dismissible(
        key: Key('transaction_history_item_${transaction.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            _deleteTransaction(transaction.id!);
            return false;
          }

          _showTransactionDialog(initialTransaction: transaction);
          return false;
        },
        background: _buildTransactionActionBackground(
          color: Colors.red,
          icon: Icons.delete_outline,
          label: 'Delete',
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _buildTransactionActionBackground(
          color: const Color(0xFF29C7E8),
          icon: Icons.edit_outlined,
          label: 'Edit',
          alignment: Alignment.centerRight,
        ),
        child: card,
      ),
    );
  }

  Widget _buildSavingGoals() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Target Tabungan',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF69B4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _showAddGoalDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF69B4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  '+ Goal Baru',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _savingGoals.isEmpty
                ? _buildEmptyGoalsState()
                : _buildGoalsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlist() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wishlist Belanja',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF69B4),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _showAddWishlistDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF69B4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  '+ Tambah Item',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_wishlistItems.isEmpty)
            _buildEmptyWishlistState()
          else
            _buildWishlistItems(),
        ],
      ),
    );
  }

  Widget _buildEmptyWishlistState() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              'Wishlist masih kosong',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yuk tambahkan barang impian\nyang pengen kamu beli!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showAddWishlistDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF69B4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(
                '+ Tambah ke Wishlist',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistItems() {
    // Sort by priority: high -> medium -> low
    List<WishlistItem> sortedItems = List.from(_wishlistItems);
    sortedItems.sort((a, b) {
      const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
    });

    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedItems.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildWishlistItem(sortedItems[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWishlistItem(WishlistItem item) {
    Color priorityColor;
    String priorityText;

    switch (item.priority) {
      case 'high':
        priorityColor = Colors.red;
        priorityText = 'Prioritas Tinggi';
        break;
      case 'medium':
        priorityColor = Colors.orange;
        priorityText = 'Prioritas Sedang';
        break;
      case 'low':
        priorityColor = Colors.green;
        priorityText = 'Prioritas Rendah';
        break;
      default:
        priorityColor = Colors.grey;
        priorityText = 'Prioritas Sedang';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: priorityColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              item.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  formatRupiah(item.price),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF69B4),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: priorityColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    priorityText,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: () => _deleteWishlistItem(item.id!),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _buyWishlistItem(item),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesPage({bool showPageTitle = true}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showPageTitle) ...[
            Text(
              'Badge & Pencapaian',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF69B4),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Badge Kamu',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFF69B4),
            ),
          ),
          const SizedBox(height: 15),
          if (_badges.isEmpty) _buildEmptyBadgesState() else _buildBadgesList(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    final allTransactions = _filteredStatisticsTransactions();
    final totalIncome = allTransactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = allTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
    final completedGoals = _savingGoals.where((g) => g.progress >= 1.0).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Statistik ${_selectedFilter == 'weekly' ? 'Mingguan' : _selectedFilter == 'monthly' ? 'Bulanan' : _selectedFilter == 'yearly' ? 'Tahunan' : 'Rentang'}',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.trending_up_rounded,
                  'Pemasukan',
                  formatRupiah(totalIncome),
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white30),
              Expanded(
                child: _buildStatItem(
                  Icons.trending_down_rounded,
                  'Pengeluaran',
                  formatRupiah(totalExpense),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(height: 1, color: Colors.white30),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.flag_rounded,
                  'Goal Tercapai',
                  '$completedGoals dari ${_savingGoals.length}',
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white30),
              Expanded(
                child: _buildStatItem(
                  Icons.emoji_events_outlined,
                  'Badge Terkumpul',
                  '${_badges.length} Badge',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.white),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyBadgesState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 15),
            Text(
              'Belum ada badge',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            Text(
              'Yuk mulai catat transaksi dan\ncapai goal untuk dapetin badge!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesList() {
    return SizedBox(
      height: 230, // ⬅️ Batasi tinggi agar tidak overflow
      child: GridView.builder(
        scrollDirection: Axis.horizontal, // ⬅️ Ubah jadi horizontal scroll
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          childAspectRatio: 1.1,
          mainAxisSpacing: 15,
        ),
        itemCount: _badges.length,
        itemBuilder: (context, index) {
          final badge = _badges[index];
          return Container(
            width: 160,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    badge.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  badge.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  badge.description,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('dd MMM yyyy').format(badge.earnedDate),
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlyChart() {
    final chartData = _buildExpenseChartSeries();
    final spots = List.generate(
      chartData.values.length,
      (index) => FlSpot(index.toDouble(), chartData.values[index]),
    );
    final labels = chartData.labels;
    final maxExpense = chartData.values.isEmpty
        ? 0.0
        : chartData.values.reduce((a, b) => a > b ? a : b);

    if (maxExpense == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📈', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'Belum ada data pengeluaran',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Mulai catat pengeluaran untuk melihat grafik',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Tentukan interval Y-axis yang lebih smart
    double yInterval;
    if (maxExpense > 10000000) {
      // > 10 juta
      yInterval = 2000000; // interval 2 juta
    } else if (maxExpense > 5000000) {
      // > 5 juta
      yInterval = 1000000; // interval 1 juta
    } else if (maxExpense > 1000000) {
      // > 1 juta
      yInterval = 500000; // interval 500rb
    } else if (maxExpense > 500000) {
      // > 500rb
      yInterval = 200000; // interval 200rb
    } else {
      yInterval = 100000; // interval 100rb
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chartData.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  if (chartData.subtitle.isNotEmpty)
                    Text(
                      chartData.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF69B4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Trend',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFFFF69B4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 84,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');

                        final label = formatRupiahValue(value);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            label,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < labels.length &&
                            value.toInt() >= 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[value.toInt()],
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.3), width: 1),
                    bottom: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.3), width: 1),
                  ),
                ),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 0,
                maxY: (maxExpense * 1.2)
                    .ceilToDouble(), // Tambah 20% ruang di atas
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFFFF69B4),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final monthIndex = barSpot.x.toInt();
                        final amount = barSpot.y;

                        return LineTooltipItem(
                          '${labels[monthIndex]}\n${formatRupiah(amount)}',
                          GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  getTouchLineStart: (data, index) => 0,
                  getTouchLineEnd: (data, index) => double.infinity,
                  touchSpotThreshold: 50,
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF69B4),
                        Color(0xFFFF1493),
                        Color(0xFFDC143C),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: Colors.white,
                          strokeWidth: 3,
                          strokeColor: const Color(0xFFFF69B4),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF69B4).withValues(alpha: 0.3),
                          const Color(0xFFFF69B4).withValues(alpha: 0.1),
                          const Color(0xFFFF69B4).withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    shadow: Shadow(
                      color: const Color(0xFFFF69B4).withValues(alpha: 0.3),
                      offset: const Offset(0, 3),
                      blurRadius: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Legend dan info tambahan
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF69B4).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF69B4).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chartData.legend,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFFFF69B4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ChartSeriesData _buildExpenseChartSeries() {
    final period = _currentPeriodRange();
    final effectiveTransactions = affectingTransactions(_allTransactions);

    switch (_selectedFilter) {
      case 'weekly':
        final labels = <String>[];
        final values = <double>[];
        for (int index = 0; index < 7; index++) {
          final day = period.start.add(Duration(days: index));
          final nextDay = DateTime(day.year, day.month, day.day + 1);
          labels.add(DateFormat('E').format(day));
          values.add(
            effectiveTransactions
                .where((t) =>
                    t.type == 'expense' &&
                    (_selectedWallet == 'All' || t.wallet == _selectedWallet) &&
                    t.date.isAfter(day.subtract(const Duration(seconds: 1))) &&
                    t.date.isBefore(nextDay))
                .fold(0.0, (sum, t) => sum + t.amount),
          );
        }
        return ChartSeriesData(
          title: 'Pengeluaran Mingguan',
          subtitle:
              '${DateFormat('d MMM').format(period.start)} - ${DateFormat('d MMM').format(period.end)}',
          legend: 'Pengeluaran per hari dalam minggu aktif',
          labels: labels,
          values: values,
        );
      case 'monthly':
        final labels = <String>[];
        final values = <double>[];
        for (int dayNumber = 1; dayNumber <= period.end.day; dayNumber++) {
          final day =
              DateTime(period.start.year, period.start.month, dayNumber);
          final nextDay =
              DateTime(period.start.year, period.start.month, dayNumber + 1);
          labels.add(dayNumber.toString());
          values.add(
            effectiveTransactions
                .where((t) =>
                    t.type == 'expense' &&
                    (_selectedWallet == 'All' || t.wallet == _selectedWallet) &&
                    t.date.isAfter(day.subtract(const Duration(seconds: 1))) &&
                    t.date.isBefore(nextDay))
                .fold(0.0, (sum, t) => sum + t.amount),
          );
        }
        return ChartSeriesData(
          title: 'Pengeluaran Bulanan',
          subtitle: DateFormat('MMMM yyyy').format(period.start),
          legend: 'Pengeluaran per hari dalam bulan aktif',
          labels: labels,
          values: values,
        );
      case 'yearly':
        final labels = <String>[];
        final values = <double>[];
        for (int month = 1; month <= 12; month++) {
          final monthStart = DateTime(period.start.year, month, 1);
          final nextMonth = DateTime(period.start.year, month + 1, 1);
          labels.add(DateFormat('MMM').format(monthStart));
          values.add(
            effectiveTransactions
                .where((t) =>
                    t.type == 'expense' &&
                    (_selectedWallet == 'All' || t.wallet == _selectedWallet) &&
                    t.date.isAfter(
                        monthStart.subtract(const Duration(seconds: 1))) &&
                    t.date.isBefore(nextMonth))
                .fold(0.0, (sum, t) => sum + t.amount),
          );
        }
        return ChartSeriesData(
          title: 'Pengeluaran Tahunan',
          subtitle: DateFormat('yyyy').format(period.start),
          legend: 'Pengeluaran per bulan dalam tahun aktif',
          labels: labels,
          values: values,
        );
      case 'range':
        final labels = <String>[];
        final values = <double>[];
        final totalDays = period.end.difference(period.start).inDays + 1;
        for (int index = 0; index < totalDays; index++) {
          final day = period.start.add(Duration(days: index));
          final nextDay = DateTime(day.year, day.month, day.day + 1);
          labels.add(DateFormat('d MMM').format(day));
          values.add(
            effectiveTransactions
                .where((t) =>
                    t.type == 'expense' &&
                    (_selectedWallet == 'All' || t.wallet == _selectedWallet) &&
                    t.date.isAfter(day.subtract(const Duration(seconds: 1))) &&
                    t.date.isBefore(nextDay))
                .fold(0.0, (sum, t) => sum + t.amount),
          );
        }
        return ChartSeriesData(
          title: 'Pengeluaran Rentang',
          subtitle:
              '${DateFormat('d MMM yyyy').format(period.start)} - ${DateFormat('d MMM yyyy').format(period.end)}',
          legend: 'Pengeluaran per hari dalam rentang terpilih',
          labels: labels,
          values: values,
        );
      default:
        return const ChartSeriesData(
          title: 'Pengeluaran',
          subtitle: '',
          legend: 'Pengeluaran',
          labels: [],
          values: [],
        );
    }
  }

  Widget _buildCuteFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      key: const Key('bottom_nav_add_transaction'),
      tooltip: 'Tambah Transaksi',
      onPressed: () => _showAddTransactionDialog(),
      backgroundColor: const Color(0xFFFF69B4),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withAlpha(102), // ✅ diperbaiki
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyGoalsState() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada target tabungan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yuk bikin target tabungan untuk\nmewujudkan impian kamu!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showAddGoalDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF69B4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(
                '+ Buat Target Baru',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsList() {
    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _savingGoals.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildGoalItem(_savingGoals[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalItem(SavingGoal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: goal.progress >= 1.0
                      ? Colors.green.withValues(alpha: 0.1)
                      : const Color(0xFFFF69B4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  goal.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Target: ${formatRupiah(goal.targetAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (goal.targetDate != null)
                      Text(
                        'Deadline: ${DateFormat('dd MMM yyyy').format(goal.targetDate!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'add_money') {
                    _showAddMoneyToGoalDialog(goal);
                  } else if (value == 'delete') {
                    _deleteGoal(goal.id!);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'add_money',
                    child: Text('💰 Tambah Uang'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('🗑️ Hapus Goal'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress bar
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: goal.progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: goal.progress >= 1.0
                            ? [Colors.green, Colors.lightGreen]
                            : [
                                const Color(0xFFFF69B4),
                                const Color(0xFFFF1493)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terkumpul',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    formatRupiah(goal.currentAmount),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: goal.progress >= 1.0
                      ? Colors.green
                      : const Color(0xFFFF69B4),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '${(goal.progress * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          if (goal.progress >= 1.0)
            Container(
              margin: const EdgeInsets.only(top: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Target tercapai! Selamat! 🎊',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Dialog Methods
  void _showAddTransactionDialog() {
    _showTransactionDialog();
  }

  Future<void> _showTransactionDialog({
    Transaction? initialTransaction,
  }) async {
    final isEditing = initialTransaction != null;
    final affectsBalance = initialTransaction?.affectsBalance ?? true;
    final now = DateTime.now();
    final TextEditingController amountController = TextEditingController(
      text: isEditing
          ? CurrencyInputFormatter.format(initialTransaction.amount.round())
          : '',
    );
    final TextEditingController descriptionController = TextEditingController(
      text: initialTransaction?.description ?? '',
    );
    String selectedType = initialTransaction?.type ?? 'expense';

    final List<String> expenseCategories = [
      'Makanan',
      'Transport',
      'Belanja',
      'Hiburan',
      'Kesehatan',
      'Pendidikan',
      'Tagihan',
      'Lainnya'
    ];

    final List<String> incomeCategories = [
      'Gaji',
      'Bonus',
      'Freelance',
      'Investasi',
      'Hadiah',
      'Lainnya'
    ];

    void ensureCategoryPresent(List<String> categories, String? category) {
      if (category != null && !categories.contains(category)) {
        categories.insert(0, category);
      }
    }

    if (selectedType == 'income') {
      ensureCategoryPresent(incomeCategories, initialTransaction?.category);
    } else {
      ensureCategoryPresent(expenseCategories, initialTransaction?.category);
    }

    String selectedCategory = initialTransaction?.category ??
        (selectedType == 'income'
            ? incomeCategories.first
            : expenseCategories.first);

    final availableWallets = List<Wallet>.from(_activeWallets);
    final fallbackWalletName = initialTransaction?.wallet ?? 'Cash';
    if (!availableWallets.any((wallet) => wallet.name == fallbackWalletName)) {
      availableWallets.insert(
        0,
        Wallet(
          name: fallbackWalletName,
          createdDate: now,
          updatedDate: now,
        ),
      );
    }
    if (availableWallets.isEmpty) {
      availableWallets.add(
        Wallet(
          name: fallbackWalletName,
          createdDate: now,
          updatedDate: now,
        ),
      );
    }

    String selectedWallet = availableWallets
        .firstWhere(
          (wallet) => wallet.name == fallbackWalletName,
          orElse: () => availableWallets.first,
        )
        .name;

    final hasNoActiveBuckets = _activeBuckets.isEmpty;
    final bucketConfigurationIncomplete =
        hasIncompleteBucketConfiguration(_activeBuckets);

    FinancialBucket? selectedExpenseBucket =
        _activeBuckets.isNotEmpty ? _activeBuckets.first : null;
    final Set<int> selectedIncomeBucketIds = <int>{};

    if (isEditing &&
        initialTransaction.id != null &&
        _activeBuckets.isNotEmpty) {
      final allocations = await _dbHelper.getTransactionBucketAllocations(
        initialTransaction.id!,
      );
      if (selectedType == 'income') {
        selectedIncomeBucketIds.addAll(
          allocations
              .where((allocation) => allocation.role == 'target')
              .map((allocation) => allocation.bucketId),
        );
      } else {
        final sourceAllocations = allocations
            .where((allocation) => allocation.role == 'source')
            .toList();
        if (sourceAllocations.isNotEmpty) {
          final matchingBuckets = _activeBuckets
              .where((bucket) => bucket.id == sourceAllocations.first.bucketId)
              .toList();
          if (matchingBuckets.isNotEmpty) {
            selectedExpenseBucket = matchingBuckets.first;
          }
        }
      }
    } else {
      selectedIncomeBucketIds.addAll(
        _activeBuckets
            .where((bucket) => bucket.id != null)
            .map((bucket) => bucket.id!),
      );
    }

    if (selectedType == 'income' &&
        selectedIncomeBucketIds.isEmpty &&
        affectsBalance) {
      selectedIncomeBucketIds.addAll(
        _activeBuckets
            .where((bucket) => bucket.id != null)
            .map((bucket) => bucket.id!),
      );
    }

    String? deriveWalletNameFromBucketSelection() {
      if (!affectsBalance ||
          hasNoActiveBuckets ||
          bucketConfigurationIncomplete) {
        return null;
      }

      if (selectedType == 'income') {
        final subsetBuckets = _activeBuckets
            .where((bucket) =>
                bucket.id != null &&
                selectedIncomeBucketIds.contains(bucket.id))
            .toList();
        if (!bucketsShareSameWallet(subsetBuckets)) return null;
        final walletId = subsetBuckets.first.walletId;
        final match = availableWallets.where((wallet) => wallet.id == walletId);
        return match.isEmpty ? null : match.first.name;
      }

      final walletId = selectedExpenseBucket?.walletId;
      if (walletId == null) return null;
      final match = availableWallets.where((wallet) => wallet.id == walletId);
      return match.isEmpty ? null : match.first.name;
    }

    void syncWalletToBucketSelection() {
      final derivedWalletName = deriveWalletNameFromBucketSelection();
      if (derivedWalletName != null) {
        selectedWallet = derivedWalletName;
      }
    }

    syncWalletToBucketSelection();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      key: const Key('sheet_drag_handle'),
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isEditing ? 'Edit Transaksi' : 'Tambah Transaksi 💰',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF69B4),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    'Tipe Transaksi',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: !affectsBalance
                              ? null
                              : () => setState(() {
                                    selectedType = 'expense';
                                    if (!expenseCategories
                                        .contains(selectedCategory)) {
                                      selectedCategory =
                                          expenseCategories.first;
                                    }
                                    if (_activeBuckets.isNotEmpty) {
                                      selectedExpenseBucket ??=
                                          _activeBuckets.first;
                                    }
                                    syncWalletToBucketSelection();
                                  }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color: selectedType == 'expense'
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: selectedType == 'expense'
                                    ? Colors.red
                                    : Colors.grey.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  color: selectedType == 'expense'
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pengeluaran',
                                  style: GoogleFonts.poppins(
                                    color: selectedType == 'expense'
                                        ? Colors.red
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: !affectsBalance
                              ? null
                              : () => setState(() {
                                    selectedType = 'income';
                                    if (!incomeCategories
                                        .contains(selectedCategory)) {
                                      selectedCategory = incomeCategories.first;
                                    }
                                    if (selectedIncomeBucketIds.isEmpty) {
                                      selectedIncomeBucketIds.addAll(
                                        _activeBuckets
                                            .where(
                                                (bucket) => bucket.id != null)
                                            .map((bucket) => bucket.id!),
                                      );
                                    }
                                    syncWalletToBucketSelection();
                                  }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color: selectedType == 'income'
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: selectedType == 'income'
                                    ? Colors.green
                                    : Colors.grey.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  color: selectedType == 'income'
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pemasukan',
                                  style: GoogleFonts.poppins(
                                    color: selectedType == 'income'
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Jumlah',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: 'Masukkan jumlah',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey),
                        prefixText: 'Rp ',
                        prefixStyle: GoogleFonts.poppins(
                          color: const Color(0xFFFF69B4),
                          fontWeight: FontWeight.bold,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Kategori',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFFFF69B4),
                        ),
                        style:
                            GoogleFonts.poppins(color: const Color(0xFF333333)),
                        onChanged: (String? newValue) {
                          if (newValue == null) return;
                          setState(() => selectedCategory = newValue);
                        },
                        items: (selectedType == 'expense'
                                ? expenseCategories
                                : incomeCategories)
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Dompet',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedWallet,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFFFF69B4),
                        ),
                        style:
                            GoogleFonts.poppins(color: const Color(0xFF333333)),
                        onChanged: deriveWalletNameFromBucketSelection() != null
                            ? null
                            : (String? newValue) {
                                if (newValue == null) return;
                                setState(() => selectedWallet = newValue);
                              },
                        items: availableWallets
                            .map<DropdownMenuItem<String>>((Wallet wallet) {
                          return DropdownMenuItem<String>(
                            value: wallet.name,
                            child: Row(
                              children: [
                                Icon(
                                  resolveWalletIcon(
                                      wallet.iconKey, wallet.name),
                                  size: 16,
                                  color: const Color(0xFFFF69B4),
                                ),
                                const SizedBox(width: 8),
                                Text(wallet.name),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    key: const Key('transaction_bucket_section'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pos Keuangan',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!affectsBalance)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              'Transaksi ini hanya catatan dan tidak memengaruhi saldo pos.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        else if (selectedType == 'income')
                          Container(
                            key: const Key('income_bucket_selector'),
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: bucketConfigurationIncomplete
                                ? Text(
                                    _bucketConfigurationIncompleteText,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  )
                                : hasNoActiveBuckets
                                    ? Text(
                                        'Belum ada pos keuangan aktif. Transaksi tetap bisa disimpan tanpa alokasi pos.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _activeBuckets.map((bucket) {
                                          final bucketId = bucket.id!;
                                          final isSelected =
                                              selectedIncomeBucketIds
                                                  .contains(bucketId);
                                          return FilterChip(
                                            label: Text(bucket.name),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              setState(() {
                                                if (selected) {
                                                  selectedIncomeBucketIds
                                                      .add(bucketId);
                                                } else {
                                                  selectedIncomeBucketIds
                                                      .remove(bucketId);
                                                }
                                                syncWalletToBucketSelection();
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                          )
                        else if (bucketConfigurationIncomplete ||
                            hasNoActiveBuckets)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              bucketConfigurationIncomplete
                                  ? _bucketConfigurationIncompleteText
                                  : 'Belum ada pos keuangan aktif. Transaksi tetap bisa disimpan tanpa pos sumber.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        else
                          DropdownButtonFormField<FinancialBucket>(
                            key: const Key('expense_bucket_dropdown'),
                            value: selectedExpenseBucket,
                            items: _activeBuckets
                                .map(
                                  (bucket) => DropdownMenuItem<FinancialBucket>(
                                    value: bucket,
                                    child: Text(bucket.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (bucket) => setState(() {
                              selectedExpenseBucket = bucket;
                              syncWalletToBucketSelection();
                            }),
                            decoration: InputDecoration(
                              hintText: 'Pilih pos sumber',
                              hintStyle: GoogleFonts.poppins(),
                              filled: true,
                              fillColor: Colors.grey.withValues(alpha: 0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Keterangan',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: descriptionController,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        hintText: 'Tambahkan keterangan...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (amountController.text.isEmpty) {
                          _showSnackBarMessage(
                            'Jumlah wajib diisi.',
                            backgroundColor: Colors.red,
                          );
                          return;
                        }

                        if (descriptionController.text.trim().isEmpty) {
                          _showSnackBarMessage(
                            'Keterangan wajib diisi.',
                            backgroundColor: Colors.red,
                          );
                          return;
                        }

                        try {
                          final amount =
                              parseCurrencyInput(amountController.text);
                          final description = descriptionController.text.trim();
                          final transactionDate =
                              initialTransaction?.date ?? DateTime.now();
                          final selectedWalletModel = availableWallets
                              .where((wallet) => wallet.name == selectedWallet)
                              .cast<Wallet?>()
                              .firstWhere(
                                (_) => true,
                                orElse: () => null,
                              );

                          if (!affectsBalance) {
                            if (initialTransaction?.id == null) {
                              _showSnackBarMessage(
                                'Transaksi catatan tidak bisa dibuat dari form ini.',
                                backgroundColor: Colors.red,
                              );
                              return;
                            }

                            await _dbHelper.updateTransaction(
                              transactionId: initialTransaction!.id!,
                              type: selectedType,
                              amount: amount,
                              category: selectedCategory,
                              description: description,
                              date: transactionDate,
                              walletName: selectedWallet,
                              walletId: selectedWalletModel?.id,
                              affectsBalance: false,
                            );
                          } else if (selectedType == 'income') {
                            if (bucketConfigurationIncomplete) {
                              _showSnackBarMessage(
                                _bucketConfigurationIncompleteMessage,
                                backgroundColor: Colors.red,
                              );
                              return;
                            }

                            if (hasNoActiveBuckets) {
                              if (isEditing) {
                                await _dbHelper.updateTransaction(
                                  transactionId: initialTransaction.id!,
                                  type: selectedType,
                                  amount: amount,
                                  category: selectedCategory,
                                  description: description,
                                  date: transactionDate,
                                  walletName: selectedWallet,
                                  walletId: selectedWalletModel?.id,
                                  affectsBalance: true,
                                  allowWithoutBucketAllocation: true,
                                );
                              } else {
                                await _dbHelper.insertTransaction(
                                  Transaction(
                                    type: selectedType,
                                    amount: amount,
                                    category: selectedCategory,
                                    description: description,
                                    date: transactionDate,
                                    wallet: selectedWallet,
                                    walletId: selectedWalletModel?.id,
                                    walletNameSnapshot: selectedWallet,
                                    affectsBalance: true,
                                  ),
                                );
                              }
                            } else {
                              final subsetBuckets = _activeBuckets
                                  .where((bucket) =>
                                      bucket.id != null &&
                                      selectedIncomeBucketIds
                                          .contains(bucket.id))
                                  .toList();
                              if (subsetBuckets.isEmpty) {
                                _showSnackBarMessage(
                                  'Pilih minimal satu pos tujuan.',
                                  backgroundColor: Colors.red,
                                );
                                return;
                              }

                              if (isEditing) {
                                await _dbHelper.updateTransaction(
                                  transactionId: initialTransaction.id!,
                                  type: selectedType,
                                  amount: amount,
                                  category: selectedCategory,
                                  description: description,
                                  date: transactionDate,
                                  walletName: selectedWallet,
                                  walletId: selectedWalletModel?.id,
                                  affectsBalance: true,
                                  subsetBuckets: subsetBuckets,
                                );
                              } else {
                                await _dbHelper.saveIncomeWithAllocations(
                                  amount: amount,
                                  category: selectedCategory,
                                  description: description,
                                  date: transactionDate,
                                  walletName: selectedWallet,
                                  subsetBuckets: subsetBuckets,
                                  walletId: selectedWalletModel?.id,
                                );
                              }
                            }
                          } else {
                            if (bucketConfigurationIncomplete) {
                              _showSnackBarMessage(
                                _bucketConfigurationIncompleteMessage,
                                backgroundColor: Colors.red,
                              );
                              return;
                            }

                            if (hasNoActiveBuckets) {
                              if (isEditing) {
                                await _dbHelper.updateTransaction(
                                  transactionId: initialTransaction.id!,
                                  type: selectedType,
                                  amount: amount,
                                  category: selectedCategory,
                                  description: description,
                                  date: transactionDate,
                                  walletName: selectedWallet,
                                  walletId: selectedWalletModel?.id,
                                  affectsBalance: true,
                                  allowWithoutBucketAllocation: true,
                                );
                              } else {
                                await _dbHelper.insertTransaction(
                                  Transaction(
                                    type: selectedType,
                                    amount: amount,
                                    category: selectedCategory,
                                    description: description,
                                    date: transactionDate,
                                    wallet: selectedWallet,
                                    walletId: selectedWalletModel?.id,
                                    walletNameSnapshot: selectedWallet,
                                    affectsBalance: true,
                                  ),
                                );
                              }
                            } else {
                              if (selectedExpenseBucket == null) {
                                _showSnackBarMessage(
                                  'Pilih satu pos sumber.',
                                  backgroundColor: Colors.red,
                                );
                                return;
                              }

                              if (isEditing) {
                                await _dbHelper.updateTransaction(
                                  transactionId: initialTransaction.id!,
                                  type: selectedType,
                                  amount: amount,
                                  category: selectedCategory,
                                  description: description,
                                  date: transactionDate,
                                  walletName: selectedWallet,
                                  walletId: selectedWalletModel?.id,
                                  affectsBalance: true,
                                  sourceBucket: selectedExpenseBucket!,
                                );
                              } else {
                                await _dbHelper.saveExpenseWithSource(
                                  amount: amount,
                                  category: selectedCategory,
                                  description: description,
                                  date: transactionDate,
                                  walletName: selectedWallet,
                                  sourceBucket: selectedExpenseBucket!,
                                  walletId: selectedWalletModel?.id,
                                );
                              }
                            }
                          }

                          await _loadAllData();

                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          _showSnackBarMessage(
                            isEditing
                                ? 'Transaksi berhasil diperbarui!'
                                : 'Transaksi berhasil ditambahkan!',
                          );
                        } on StateError catch (error) {
                          final rawMessage = error.message.toString();
                          final userMessage = rawMessage.contains(
                            'one effective wallet',
                          )
                              ? 'Pilih bucket pemasukan dari satu dompet yang sama.'
                              : rawMessage.contains('debt records')
                                  ? 'Transaksi dari hutang/piutang harus dikelola dari halaman hutang/piutang.'
                                  : 'Transaksi gagal diproses. Cek dompet dan pos yang dipilih.';
                          _showSnackBarMessage(
                            userMessage,
                            backgroundColor: Colors.red,
                          );
                        } on Exception catch (_) {
                          _showSnackBarMessage(
                            'Transaksi gagal disimpan. Coba lagi.',
                            backgroundColor: Colors.red,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF69B4),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Update Transaksi' : 'Simpan Transaksi',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddGoalDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController targetController = TextEditingController();
    String selectedEmoji = '💰';
    DateTime? selectedDate;

    final List<String> emojiOptions = [
      '💰',
      '🎯',
      '🏠',
      '🚗',
      '📱',
      '👗',
      '🎮',
      '📚',
      '✈️',
      '💍'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    key: const Key('sheet_drag_handle'),
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Buat Target Tabungan 🎯',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF69B4),
                  ),
                ),
                const SizedBox(height: 25),

                // Name input
                Text(
                  'Nama Target',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: nameController,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      hintText: 'Contoh: iPhone baru, Liburan ke Bali',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Target amount
                Text(
                  'Target Jumlah',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      hintText: 'Masukkan target jumlah',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey),
                      prefixText: 'Rp ',
                      prefixStyle: GoogleFonts.poppins(
                        color: const Color(0xFFFF69B4),
                        fontWeight: FontWeight.bold,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Emoji selection
                Text(
                  'Pilih Emoji',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: emojiOptions.length,
                    itemBuilder: (context, index) {
                      final emoji = emojiOptions[index];
                      return GestureDetector(
                        onTap: () => setState(() => selectedEmoji = emoji),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: selectedEmoji == emoji
                                ? const Color(0xFFFF69B4).withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: selectedEmoji == emoji
                                  ? const Color(0xFFFF69B4)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Target date (optional)
                Text(
                  'Target Tanggal (Opsional)',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: Color(0xFFFF69B4)),
                        const SizedBox(width: 15),
                        Text(
                          selectedDate != null
                              ? DateFormat('dd MMM yyyy').format(selectedDate!)
                              : 'Pilih tanggal target',
                          style: GoogleFonts.poppins(
                            color: selectedDate != null
                                ? const Color(0xFF333333)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          targetController.text.isEmpty) {
                        _showSnackBarMessage(
                          'Nama target dan jumlah wajib diisi.',
                          backgroundColor: Colors.red,
                        );
                        return;
                      }

                      try {
                        final goal = SavingGoal(
                          name: nameController.text,
                          targetAmount:
                              parseCurrencyInput(targetController.text),
                          emoji: selectedEmoji,
                          createdDate: DateTime.now(),
                          targetDate: selectedDate,
                        );

                        await _dbHelper.insertSavingGoal(goal);
                        await _loadAllData();

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _showSnackBarMessage(
                            'Target tabungan berhasil dibuat! 🎯');
                      } on Exception catch (_) {
                        _showSnackBarMessage(
                          'Target tabungan gagal disimpan. Coba lagi.',
                          backgroundColor: Colors.red,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF69B4),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'Buat Target 🎯',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Perbaikan untuk method _showAddWishlistDialog()
  void _showAddWishlistDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    String selectedEmoji = '🛍️';
    String selectedPriority = 'medium';

    final List<String> emojiOptions = [
      '🛍️',
      '👗',
      '👠',
      '💄',
      '📱',
      '💻',
      '🎮',
      '📚',
      '🏠',
      '🚗'
    ];

    final List<Map<String, dynamic>> priorities = [
      {'value': 'high', 'label': 'Prioritas Tinggi', 'color': Colors.red},
      {'value': 'medium', 'label': 'Prioritas Sedang', 'color': Colors.orange},
      {'value': 'low', 'label': 'Prioritas Rendah', 'color': Colors.green},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height *
              0.85, // Tinggi diperbesar jadi 85%
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    key: const Key('sheet_drag_handle'),
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tambah ke Wishlist 🛍️',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF69B4),
                  ),
                ),
                const SizedBox(height: 25),

                // BAGIAN FORM DALAM SCROLLABLE
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name input
                        Text(
                          'Nama Barang',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: TextField(
                            controller: nameController,
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              hintText: 'Contoh: Dress cantik, Sepatu heels',
                              hintStyle:
                                  GoogleFonts.poppins(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Price input
                        Text(
                          'Harga',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              hintText: 'Masukkan harga',
                              hintStyle:
                                  GoogleFonts.poppins(color: Colors.grey),
                              prefixText: 'Rp ',
                              prefixStyle: GoogleFonts.poppins(
                                color: const Color(0xFFFF69B4),
                                fontWeight: FontWeight.bold,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Emoji selection
                        Text(
                          'Pilih Emoji',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: emojiOptions.length,
                            itemBuilder: (context, index) {
                              final emoji = emojiOptions[index];
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => selectedEmoji = emoji),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: selectedEmoji == emoji
                                        ? const Color(0xFFFF69B4)
                                            .withValues(alpha: 0.2)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: selectedEmoji == emoji
                                          ? const Color(0xFFFF69B4)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(emoji,
                                      style: const TextStyle(fontSize: 24)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Priority selection
                        Text(
                          'Prioritas',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: priorities.map((priority) {
                            return GestureDetector(
                              onTap: () => setState(
                                  () => selectedPriority = priority['value']),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: selectedPriority == priority['value']
                                      ? priority['color'].withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: selectedPriority == priority['value']
                                        ? priority['color']
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: priority['color'],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Text(
                                      priority['label'],
                                      style: GoogleFonts.poppins(
                                        color: selectedPriority ==
                                                priority['value']
                                            ? priority['color']
                                            : Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(
                            height: 30), // Extra space sebelum tombol
                      ],
                    ),
                  ),
                ),

                // TOMBOL SELALU TERLIHAT DI BAWAH (TIDAK IKUT SCROLL)
                Container(
                  padding: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Validasi input
                        if (nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Nama barang tidak boleh kosong!',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (priceController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Harga tidak boleh kosong!',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        try {
                          final item = WishlistItem(
                            name: nameController.text.trim(),
                            price: parseCurrencyInput(priceController.text),
                            emoji: selectedEmoji,
                            priority: selectedPriority,
                            createdDate: DateTime.now(),
                          );

                          // Simpan ke database
                          await _dbHelper.insertWishlistItem(item);

                          // Refresh data
                          await _loadAllData();

                          // Tutup dialog jika context masih valid
                          if (context.mounted) {
                            Navigator.pop(context);
                          }

                          _showSnackBarMessage(
                            '✅ ${item.emoji} ${item.name} berhasil ditambahkan!',
                          );
                        } on FormatException {
                          _showSnackBarMessage(
                            'Format harga tidak valid! Masukkan angka saja.',
                            backgroundColor: Colors.red,
                          );
                        } on Exception catch (_) {
                          _showSnackBarMessage(
                            'Wishlist gagal disimpan. Coba lagi.',
                            backgroundColor: Colors.red,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF69B4),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 8,
                        shadowColor:
                            const Color(0xFFFF69B4).withValues(alpha: 0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🛍️', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Text(
                            'Tambah ke Wishlist',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMoneyToGoalDialog(SavingGoal goal) {
    final TextEditingController amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            key: const Key('sheet_drag_handle'),
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Goal info
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF69B4), Color(0xFFFF1493)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(goal.emoji,
                                    style: const TextStyle(fontSize: 24)),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${formatRupiah(goal.currentAmount)} / ${formatRupiah(goal.targetAmount)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),

                        Text(
                          'Tambah Uang ke Target 💰',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF69B4),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Jumlah Uang',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              hintText: 'Masukkan jumlah',
                              hintStyle:
                                  GoogleFonts.poppins(color: Colors.grey),
                              prefixText: 'Rp ',
                              prefixStyle: GoogleFonts.poppins(
                                color: const Color(0xFFFF69B4),
                                fontWeight: FontWeight.bold,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Jumlah Cepat',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            _buildQuickAmountButton(formatRupiahValue(50000),
                                50000, amountController),
                            const SizedBox(width: 10),
                            _buildQuickAmountButton(formatRupiahValue(100000),
                                100000, amountController),
                            const SizedBox(width: 10),
                            _buildQuickAmountButton(formatRupiahValue(500000),
                                500000, amountController),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (amountController.text.isEmpty) {
                                _showSnackBarMessage(
                                  'Jumlah top up wajib diisi.',
                                  backgroundColor: Colors.red,
                                );
                                return;
                              }

                              try {
                                final amount =
                                    parseCurrencyInput(amountController.text);
                                final updatedGoal = SavingGoal(
                                  id: goal.id,
                                  name: goal.name,
                                  targetAmount: goal.targetAmount,
                                  currentAmount: goal.currentAmount + amount,
                                  emoji: goal.emoji,
                                  createdDate: goal.createdDate,
                                  targetDate: goal.targetDate,
                                );

                                await _dbHelper.updateSavingGoal(updatedGoal);
                                await _loadAllData();

                                if (!context.mounted) return;

                                Navigator.pop(context);
                                _showSnackBarMessage(
                                  'Berhasil menambah ${formatRupiah(amount)} ke ${goal.name}! 💰',
                                );
                              } on Exception catch (_) {
                                _showSnackBarMessage(
                                  'Top up goal gagal disimpan. Coba lagi.',
                                  backgroundColor: Colors.red,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF69B4),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              'Tambah Uang 💰',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickAmountButton(
      String label, double amount, TextEditingController controller) {
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            controller.text = CurrencyInputFormatter.format(amount.toInt()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF69B4).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFF69B4).withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF69B4),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Delete methods
  void _deleteTransaction(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Transaksi? 🗑️',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Kamu yakin mau hapus transaksi ini?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _dbHelper.deleteTransaction(id);
                await _loadAllData();

                if (!context.mounted) return;

                Navigator.pop(context);
                _showSnackBarMessage(
                  'Transaksi berhasil dihapus! 🗑️',
                  backgroundColor: Colors.red,
                );
              } on StateError {
                if (!context.mounted) return;

                Navigator.pop(context);
                _showSnackBarMessage(
                  'Transaksi dari hutang/piutang harus dikelola dari halaman hutang/piutang.',
                  backgroundColor: Colors.red,
                );
              } on Exception catch (_) {
                _showSnackBarMessage(
                  'Transaksi gagal dihapus. Coba lagi.',
                  backgroundColor: Colors.red,
                );
              }
            },
            child: Text(
              'Hapus',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteGoal(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Target? 🎯',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Kamu yakin mau hapus target tabungan ini?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _dbHelper.deleteSavingGoal(id);
                await _loadAllData();

                if (!context.mounted) return;

                Navigator.pop(context);
                _showSnackBarMessage(
                  'Target berhasil dihapus! 🗑️',
                  backgroundColor: Colors.red,
                );
              } on Exception catch (_) {
                _showSnackBarMessage(
                  'Target gagal dihapus. Coba lagi.',
                  backgroundColor: Colors.red,
                );
              }
            },
            child: Text(
              'Hapus',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteWishlistItem(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus dari Wishlist? 🛍️',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Kamu yakin mau hapus item ini dari wishlist?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _dbHelper.deleteWishlistItem(id);
                await _loadAllData();

                if (!context.mounted) return;

                Navigator.pop(context);
                _showSnackBarMessage(
                  'Item berhasil dihapus dari wishlist! 🗑️',
                  backgroundColor: Colors.red,
                );
              } on Exception catch (_) {
                _showSnackBarMessage(
                  'Item wishlist gagal dihapus. Coba lagi.',
                  backgroundColor: Colors.red,
                );
              }
            },
            child: Text(
              'Hapus',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _buyWishlistItem(WishlistItem item) {
    final bucketConfigurationIncomplete =
        hasIncompleteBucketConfiguration(_activeBuckets);
    if (_activeWallets.isEmpty) {
      _showSnackBarMessage(
        'Aktifkan minimal satu dompet dulu sebelum membeli item wishlist.',
        backgroundColor: Colors.red,
      );
      return;
    }
    if (bucketConfigurationIncomplete) {
      _showSnackBarMessage(
        _bucketConfigurationIncompleteMessage,
        backgroundColor: Colors.red,
      );
      return;
    }

    Wallet selectedWallet =
        _activeWallets.where((wallet) => wallet.name == 'Cash').isNotEmpty
            ? _activeWallets.firstWhere((wallet) => wallet.name == 'Cash')
            : _activeWallets.first;
    FinancialBucket? selectedBucket =
        _activeBuckets.where((bucket) => bucket.name == 'Belanja').isNotEmpty
            ? _activeBuckets.firstWhere((bucket) => bucket.name == 'Belanja')
            : (_activeBuckets.isNotEmpty ? _activeBuckets.first : null);

    Wallet? deriveWalletFromBucket(FinancialBucket? bucket) {
      if (bucket?.walletId == null) return null;
      final matches =
          _activeWallets.where((wallet) => wallet.id == bucket?.walletId);
      return matches.isEmpty ? null : matches.first;
    }

    selectedWallet = deriveWalletFromBucket(selectedBucket) ?? selectedWallet;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Beli Item? 🛒',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kamu mau beli ${item.name}?',
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 10),
                Text(
                  'Harga: ${formatRupiah(item.price)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF69B4),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _activeBuckets.isEmpty
                      ? 'Belum ada pos keuangan aktif. Pembelian tetap dicatat tanpa pos sumber.'
                      : 'Pilih pos sumber; dompet akan mengikuti pos itu agar saldo tetap konsisten.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                if (_activeBuckets.isEmpty) ...[
                  Text(
                    'Dompet',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Wallet>(
                    value: selectedWallet,
                    items: _activeWallets
                        .map(
                          (wallet) => DropdownMenuItem<Wallet>(
                            value: wallet,
                            child: Text(wallet.name),
                          ),
                        )
                        .toList(),
                    onChanged: (wallet) {
                      if (wallet == null) return;
                      setDialogState(() => selectedWallet = wallet);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_activeBuckets.isNotEmpty) ...[
                  Text(
                    'Pos Sumber',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FinancialBucket>(
                    value: selectedBucket,
                    items: _activeBuckets
                        .map(
                          (bucket) => DropdownMenuItem<FinancialBucket>(
                            value: bucket,
                            child: Text(bucket.name),
                          ),
                        )
                        .toList(),
                    onChanged: (bucket) {
                      if (bucket == null) return;
                      setDialogState(() {
                        selectedBucket = bucket;
                        selectedWallet =
                            deriveWalletFromBucket(bucket) ?? selectedWallet;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedBucket != null) ...[
                    Text(
                      'Dompet Mengikuti Pos',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        selectedWallet.name,
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _dbHelper.purchaseWishlistItem(
                    item,
                    walletName: selectedWallet.name,
                    walletId: selectedWallet.id,
                    sourceBucket: selectedBucket,
                  );
                  await _loadAllData();

                  if (!mounted || !dialogContext.mounted) return;

                  Navigator.pop(dialogContext);
                  _showSnackBarMessage(
                    'Yeay! ${item.name} berhasil dibeli! 🛒✨',
                    backgroundColor: Colors.green,
                  );
                } on Exception catch (_) {
                  _showSnackBarMessage(
                    'Pembelian wishlist gagal diproses. Coba lagi.',
                    backgroundColor: Colors.red,
                  );
                }
              },
              child: Text(
                'Beli Sekarang',
                style: GoogleFonts.poppins(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelectionChanged);
    _tabController.dispose();
    super.dispose();
  }
}
