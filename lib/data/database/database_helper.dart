import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../../core/constants/app_constants.dart';
import '../../features/badges/models/user_badge.dart';
import '../../features/buckets/helpers/bucket_helpers.dart';
import '../../features/buckets/models/bucket_models.dart';
import '../../features/debts/models/debt_models.dart';
import '../../features/goals/models/saving_goal.dart';
import '../../features/notifications/models/reminder_preferences.dart';
import '../../features/transactions/models/transaction.dart';
import '../../features/wallets/models/wallet.dart';
import '../../features/wishlist/models/wishlist_item.dart';

class InsufficientBalanceException implements Exception {
  const InsufficientBalanceException([
    this.message = insufficientBalanceMessage,
  ]);

  final String message;

  @override
  String toString() => message;
}

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
      await db.execute('ALTER TABLE transactions ADD COLUMN walletId INTEGER');
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN walletNameSnapshot TEXT DEFAULT ''");
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN affectsBalance INTEGER DEFAULT 1');

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

  Future<ReminderPreferences> getReminderPreferences() async {
    final preferences = await getAppPreferences([
      reminderEnabledPreferenceKey,
      reminderHourPreferenceKey,
      reminderEveningStartHourPreferenceKey,
      reminderLastAppOpenedAtPreferenceKey,
      reminderLastFinancialActivityAtPreferenceKey,
    ]);

    DateTime? parseEpoch(String? rawValue) {
      if (rawValue == null || rawValue.isEmpty) return null;
      final parsed = int.tryParse(rawValue);
      if (parsed == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(parsed);
    }

    return ReminderPreferences(
      isEnabled: preferences[reminderEnabledPreferenceKey] == '1',
      reminderHour:
          int.tryParse(preferences[reminderHourPreferenceKey] ?? '') ?? 22,
      eveningStartHour: int.tryParse(
              preferences[reminderEveningStartHourPreferenceKey] ?? '') ??
          20,
      lastAppOpenedAt: parseEpoch(
        preferences[reminderLastAppOpenedAtPreferenceKey],
      ),
      lastFinancialActivityAt: parseEpoch(
        preferences[reminderLastFinancialActivityAtPreferenceKey],
      ),
    );
  }

  Future<void> setReminderEnabled(bool isEnabled) async {
    await setAppPreference(
      reminderEnabledPreferenceKey,
      isEnabled ? '1' : '0',
    );
  }

  Future<void> markReminderAppOpenedAt(DateTime openedAt) async {
    await setAppPreference(
      reminderLastAppOpenedAtPreferenceKey,
      openedAt.millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> markFinancialActivity(DateTime occurredAt) async {
    await setAppPreference(
      reminderLastFinancialActivityAtPreferenceKey,
      occurredAt.millisecondsSinceEpoch.toString(),
    );
  }

  Future<int> getActiveOverdueDebtCount({
    DateTime? referenceTime,
  }) async {
    final db = await database;
    final now = referenceTime ?? DateTime.now();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS overdueCount
      FROM debts
      WHERE status = 'active'
        AND remainingAmount > 0
        AND dueDate IS NOT NULL
        AND dueDate < ?
        AND LOWER(type) IN ('debt', 'hutang')
      ''',
      [DateTime(now.year, now.month, now.day).millisecondsSinceEpoch],
    );
    return Sqflite.firstIntValue(result) ?? 0;
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

  Future<({String walletName, int? walletId})> _resolveIncomeSummaryWalletTxn(
    DatabaseExecutor executor, {
    required List<FinancialBucket> subsetBuckets,
    required String fallbackName,
    int? fallbackWalletId,
  }) async {
    if (subsetBuckets.isEmpty) {
      return (walletName: fallbackName, walletId: fallbackWalletId);
    }

    if (bucketsShareSameWallet(subsetBuckets)) {
      return _resolveWalletContextFromBucketTxn(
        executor,
        bucket: subsetBuckets.first,
        fallbackName: fallbackName,
        fallbackWalletId: fallbackWalletId,
      );
    }

    return (walletName: 'Multi Dompet', walletId: null);
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
      if (allocation.role == 'target') {
        await _ensureBucketHasSufficientBalanceTxn(
          txn,
          bucketId: allocation.bucketId,
          amount: allocation.allocatedAmount,
        );
      }
    }

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

  Future<int?> _resolveWalletIdByNameTxn(
    DatabaseExecutor executor,
    String walletName,
  ) async {
    final trimmedWalletName = walletName.trim();
    if (trimmedWalletName.isEmpty) return null;

    final rows = await executor.query(
      'wallets',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [trimmedWalletName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  Future<Map<int, int?>> _loadBucketWalletMapTxn(
    DatabaseExecutor executor,
    Iterable<int> bucketIds,
  ) async {
    final ids = bucketIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};

    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await executor.query(
      'financial_buckets',
      columns: ['id', 'walletId'],
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    return {
      for (final row in rows) row['id'] as int: row['walletId'] as int?,
    };
  }

  double _readBalanceAggregate(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return 0;
    final rawValue = rows.first['balance'];
    if (rawValue is num) return rawValue.toDouble();
    return 0;
  }

  Future<double> _calculateWalletBalanceTxn(
    DatabaseExecutor executor, {
    required int? walletId,
    required String walletName,
  }) async {
    final trimmedWalletName = walletName.trim();
    final resolvedWalletId = walletId ??
        await _resolveWalletIdByNameTxn(executor, trimmedWalletName);
    if (resolvedWalletId == null && trimmedWalletName.isEmpty) {
      return 0;
    }

    if (resolvedWalletId == null) {
      final directRows = await executor.rawQuery(
        '''
        SELECT COALESCE(SUM(
          CASE
            WHEN type = 'income' THEN amount
            WHEN type = 'expense' THEN -amount
            ELSE 0
          END
        ), 0) AS balance
        FROM transactions
        WHERE affectsBalance = 1
          AND wallet = ?
        ''',
        [trimmedWalletName],
      );
      return _readBalanceAggregate(directRows);
    }

    final directRows = await executor.rawQuery(
      '''
      SELECT COALESCE(SUM(
        CASE
          WHEN t.type = 'income' THEN t.amount
          WHEN t.type = 'expense' THEN -t.amount
          ELSE 0
        END
      ), 0) AS balance
      FROM transactions t
      WHERE t.affectsBalance = 1
        AND t.walletId = ?
        AND NOT EXISTS (
          SELECT 1
          FROM transaction_bucket_allocations a
          JOIN financial_buckets b ON b.id = a.bucketId
          WHERE a.transactionId = t.id
            AND b.walletId = ?
            AND (
              (t.type = 'income' AND a.role = 'target')
              OR (t.type = 'expense' AND a.role = 'source')
            )
        )
      ''',
      [resolvedWalletId, resolvedWalletId],
    );
    final allocationRows = await executor.rawQuery(
      '''
      SELECT COALESCE(SUM(
        CASE
          WHEN t.type = 'income' AND a.role = 'target' THEN a.allocatedAmount
          WHEN t.type = 'expense' AND a.role = 'source' THEN -a.allocatedAmount
          ELSE 0
        END
      ), 0) AS balance
      FROM transaction_bucket_allocations a
      JOIN transactions t ON t.id = a.transactionId
      JOIN financial_buckets b ON b.id = a.bucketId
      WHERE t.affectsBalance = 1
        AND b.walletId = ?
        AND (
          (t.type = 'income' AND a.role = 'target')
          OR (t.type = 'expense' AND a.role = 'source')
        )
      ''',
      [resolvedWalletId],
    );

    return _readBalanceAggregate(directRows) +
        _readBalanceAggregate(allocationRows);
  }

  Future<void> _ensureWalletHasSufficientBalanceTxn(
    DatabaseExecutor executor, {
    required double amount,
    required int? walletId,
    required String walletName,
  }) async {
    final balance = await _calculateWalletBalanceTxn(
      executor,
      walletId: walletId,
      walletName: walletName,
    );
    if (balance + 0.001 < amount) {
      throw const InsufficientBalanceException();
    }
  }

  Future<void> _ensureBucketHasSufficientBalanceTxn(
    DatabaseExecutor executor, {
    required int bucketId,
    required double amount,
  }) async {
    final rows = await executor.query(
      'financial_buckets',
      columns: ['currentBalance'],
      where: 'id = ?',
      whereArgs: [bucketId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Financial bucket not found.');
    }
    final currentBalance =
        (rows.first['currentBalance'] as num?)?.toDouble() ?? 0;
    if (currentBalance + 0.001 < amount) {
      throw const InsufficientBalanceException();
    }
  }

  Future<int> insertTransaction(Transaction transaction) async {
    final db = await database;
    if (transaction.affectsBalance && transaction.type == 'expense') {
      await _ensureWalletHasSufficientBalanceTxn(
        db,
        amount: transaction.amount,
        walletId: transaction.walletId,
        walletName: transaction.wallet,
      );
    }
    final id = await db.insert('transactions', transaction.toMap());
    await markFinancialActivity(DateTime.now());
    return id;
  }

  Future<List<Transaction>> getTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'date DESC',
    );
    return maps.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getTransactionsByWallet(String wallet) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'wallet = ?',
      whereArgs: [wallet],
      orderBy: 'date DESC',
    );
    return maps.map(Transaction.fromMap).toList();
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
    final whereArgs = <dynamic>[];

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

    final maps = await db.query(
      'transactions',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date DESC',
    );

    return maps.map(Transaction.fromMap).toList();
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

      return txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
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

      String resolvedWalletNameForWrite = walletName;
      int? resolvedWalletIdForWrite = resolvedWalletId;
      if (resolvedAffectsBalance &&
          type == 'income' &&
          subsetBuckets != null &&
          subsetBuckets.isNotEmpty) {
        final resolvedIncomeWallet = await _resolveIncomeSummaryWalletTxn(
          txn,
          subsetBuckets: subsetBuckets,
          fallbackName: walletName,
          fallbackWalletId: resolvedWalletId,
        );
        resolvedWalletNameForWrite = resolvedIncomeWallet.walletName;
        resolvedWalletIdForWrite = resolvedIncomeWallet.walletId;
      }

      final updatedRows = await txn.update(
        'transactions',
        {
          'id': transactionId,
          'type': type,
          'amount': amount,
          'category': category,
          'description': description,
          'date': date.millisecondsSinceEpoch,
          'wallet': resolvedWalletNameForWrite,
          'walletId': resolvedWalletIdForWrite,
          'walletNameSnapshot': resolvedWalletNameForWrite,
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
            await _ensureWalletHasSufficientBalanceTxn(
              txn,
              amount: amount,
              walletId: resolvedWalletId,
              walletName: walletName,
            );
            return updatedRows;
          }
          throw StateError(
            'Expense transactions that affect balance require a source bucket.',
          );
        }

        final resolvedWallet = await _resolveWalletContextFromBucketTxn(
          txn,
          bucket: sourceBucket,
          fallbackName: walletName,
          fallbackWalletId: resolvedWalletId,
        );
        await _ensureWalletHasSufficientBalanceTxn(
          txn,
          amount: amount,
          walletId: resolvedWallet.walletId,
          walletName: resolvedWallet.walletName,
        );
        await _ensureBucketHasSufficientBalanceTxn(
          txn,
          bucketId: sourceBucket.id!,
          amount: amount,
        );

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

  Future<int> insertSavingGoal(SavingGoal goal) async {
    final db = await database;
    return db.insert('saving_goals', goal.toMap());
  }

  Future<List<SavingGoal>> getSavingGoals() async {
    final db = await database;
    final maps = await db.query('saving_goals', orderBy: 'createdDate DESC');
    return maps.map(SavingGoal.fromMap).toList();
  }

  Future<int> updateSavingGoal(SavingGoal goal) async {
    final db = await database;
    return db.update(
      'saving_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteSavingGoal(int id) async {
    final db = await database;
    return db.delete('saving_goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertWishlistItem(WishlistItem item) async {
    final db = await database;
    return db.insert('wishlist', item.toMap());
  }

  Future<List<WishlistItem>> getWishlistItems() async {
    final db = await database;
    final maps = await db.query('wishlist', orderBy: 'createdDate DESC');
    return maps.map(WishlistItem.fromMap).toList();
  }

  Future<int> deleteWishlistItem(int id) async {
    final db = await database;
    return db.delete('wishlist', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertBadge(UserBadge badge) async {
    final db = await database;
    return db.insert('badges', badge.toMap());
  }

  Future<List<UserBadge>> getBadges() async {
    final db = await database;
    final maps = await db.query('badges', orderBy: 'earnedDate DESC');
    return maps.map(UserBadge.fromMap).toList();
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
    await _ensureWalletHasSufficientBalanceTxn(
      txn,
      amount: amount,
      walletId: resolvedWallet.walletId,
      walletName: resolvedWallet.walletName,
    );
    await _ensureBucketHasSufficientBalanceTxn(
      txn,
      bucketId: sourceBucket.id!,
      amount: amount,
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
        await _ensureWalletHasSufficientBalanceTxn(
          txn,
          amount: item.price,
          walletId: walletId,
          walletName: walletName,
        );
      }
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

  Future<int> insertWallet(Wallet wallet) async {
    final db = await database;
    return db.insert('wallets', wallet.toMap());
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

    return db.transaction((txn) async {
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
    return db.update(
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
      return db.update(
        'wallets',
        {
          'isArchived': 1,
          'updatedDate': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return db.delete('wallets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertDebt(Debt debt) async {
    final db = await database;
    final id = await db.insert('debts', debt.toMap());
    await markFinancialActivity(DateTime.now());
    return id;
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
    final updatedRows = await db.update(
      'debts',
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
    await markFinancialActivity(DateTime.now());
    return updatedRows;
  }

  Future<int> deleteDebt(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final debtRows = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (debtRows.isEmpty) {
        return 0;
      }

      // transactions stay intact so riwayat & saldo are preserved ("diikhlaskan")
      await txn.delete('debt_payments', where: 'debtId = ?', whereArgs: [id]);
      return txn.delete('debts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> insertDebtPayment(DebtPayment payment) async {
    final db = await database;
    return db.insert('debt_payments', payment.toMap());
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
      if (recordingMode == 'balance' &&
          affectedBucket != null &&
          debt.type == 'debt') {
        await _ensureWalletHasSufficientBalanceTxn(
          txn,
          amount: amount,
          walletId: resolvedWalletId,
          walletName: resolvedWalletName,
        );
        await _ensureBucketHasSufficientBalanceTxn(
          txn,
          bucketId: affectedBucket.id!,
          amount: amount,
        );
      }

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

      await txn.rawUpdate(
        'UPDATE debts SET remainingAmount = MAX(0, remainingAmount - ?), updatedDate = ? WHERE id = ?',
        [amount, now, debtId],
      );

      await txn.rawUpdate(
        "UPDATE debts SET status = 'settled', updatedDate = ? WHERE id = ? AND remainingAmount <= 0",
        [now, debtId],
      );

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
          await txn.rawUpdate(
            'UPDATE financial_buckets SET currentBalance = currentBalance - ?, updatedDate = ? WHERE id = ?',
            [amount, now, affectedBucket.id!],
          );
        } else {
          await txn.rawUpdate(
            'UPDATE financial_buckets SET currentBalance = currentBalance + ?, updatedDate = ? WHERE id = ?',
            [amount, now, affectedBucket.id!],
          );
        }
      }
    });

    await markFinancialActivity(DateTime.now());
  }

  Future<int> insertFinancialBucket(FinancialBucket bucket) async {
    final db = await database;
    return db.transaction((txn) async {
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
    return db.transaction((txn) async {
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
    return db.update(
      'financial_buckets',
      {'isArchived': 1, 'updatedDate': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionBucketAllocation>> getTransactionBucketAllocations(
    int transactionId,
  ) async {
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

  Future<Map<int, int?>> getBucketWalletIds(Iterable<int> bucketIds) async {
    final db = await database;
    return _loadBucketWalletMapTxn(db, bucketIds);
  }

  Future<List<BucketTransfer>> getBucketTransfers() async {
    final db = await database;
    final maps =
        await db.query('bucket_transfers', orderBy: 'transferDate DESC');
    return maps.map(BucketTransfer.fromMap).toList();
  }

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
      if (fromRows.isEmpty || toRows.isEmpty) {
        throw StateError('Financial bucket not found.');
      }
      final fromWalletId = fromRows.first['walletId'] as int?;
      final fromWallet = await _resolveWalletContextByIdTxn(
        txn,
        walletId: fromWalletId,
        fallbackName: 'Cash',
        fallbackWalletId: fromWalletId,
      );
      await _ensureWalletHasSufficientBalanceTxn(
        txn,
        amount: amount,
        walletId: fromWallet.walletId,
        walletName: fromWallet.walletName,
      );
      await _ensureBucketHasSufficientBalanceTxn(
        txn,
        bucketId: fromBucketId,
        amount: amount,
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

      final toWalletId =
          toRows.isEmpty ? null : toRows.first['walletId'] as int?;
      if (fromWalletId != null &&
          toWalletId != null &&
          fromWalletId != toWalletId) {
        final toWallet = await _resolveWalletContextByIdTxn(
          txn,
          walletId: toWalletId,
          fallbackName: 'Cash',
          fallbackWalletId: toWalletId,
        );

        await txn.insert('transactions', {
          'type': 'expense',
          'amount': amount,
          'category': internalTransferCategory,
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
          'category': internalTransferCategory,
          'description': 'Transfer dari ${fromWallet.walletName}',
          'date': transferDate.millisecondsSinceEpoch,
          'wallet': toWallet.walletName,
          'walletId': toWallet.walletId,
          'walletNameSnapshot': toWallet.walletName,
          'affectsBalance': 1,
        });
      }
    });

    await markFinancialActivity(DateTime.now());
  }

  Future<int> saveIncomeWithAllocations({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required String walletName,
    required List<FinancialBucket> subsetBuckets,
    int? walletId,
  }) async {
    final db = await database;
    final allocations = allocateIncomeToBuckets(amount, subsetBuckets);
    final normalized = normalizeSubsetAllocation(subsetBuckets);
    final now = DateTime.now().millisecondsSinceEpoch;

    final txId = await db.transaction((txn) async {
      final resolvedWallet = await _resolveIncomeSummaryWalletTxn(
        txn,
        subsetBuckets: subsetBuckets,
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
    await markFinancialActivity(DateTime.now());
    return txId;
  }

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

    final txId = await db.transaction((txn) async {
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
    await markFinancialActivity(DateTime.now());
    return txId;
  }

  Future<int> saveExpenseNoteOnly({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    required String walletName,
    int? walletId,
  }) async {
    final db = await database;
    final txId = await db.insert('transactions', {
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
    await markFinancialActivity(DateTime.now());
    return txId;
  }
}
