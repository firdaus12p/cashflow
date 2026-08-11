import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cashflow/core/constants/app_constants.dart';
import 'package:cashflow/core/formatters/currency_formatters.dart';
import 'package:cashflow/core/icons/app_icons.dart';
import 'package:cashflow/data/database/database_helper.dart';
import 'package:cashflow/features/badges/models/user_badge.dart';
import 'package:cashflow/features/buckets/helpers/bucket_helpers.dart';
import 'package:cashflow/features/buckets/models/bucket_models.dart';
import 'package:cashflow/features/buckets/presentation/pos_keuangan_page.dart';
import 'package:cashflow/features/debts/presentation/debt_pages.dart';
import 'package:cashflow/features/goals/models/saving_goal.dart';
import 'package:cashflow/features/home/helpers/home_helpers.dart';
import 'package:cashflow/features/notifications/models/reminder_preferences.dart';
import 'package:cashflow/features/notifications/models/notification_payload.dart';
import 'package:cashflow/features/notifications/presentation/pengingat_page.dart';
import 'package:cashflow/features/notifications/services/local_notification_service.dart';
import 'package:cashflow/features/notifications/services/reminder_scheduler.dart';
import 'package:cashflow/features/statistics/models/chart_series_data.dart';
import 'package:cashflow/features/transactions/models/transaction.dart';
import 'package:cashflow/features/wallets/models/wallet.dart';
import 'package:cashflow/features/wallets/presentation/dompet_page.dart';
import 'package:cashflow/features/wishlist/models/wishlist_item.dart';

const String _bucketConfigurationIncompleteText =
    bucketConfigurationIncompleteText;
const String _bucketConfigurationIncompleteMessage =
    bucketConfigurationIncompleteMessage;
const String _insufficientBalanceMessage = insufficientBalanceMessage;
const Duration _sheetFeedbackAutoHideDuration = Duration(seconds: 3);
const String _internalTransferCategory = internalTransferCategory;
const String _homeBalanceSourceTypePreferenceKey =
    homeBalanceSourceTypePreferenceKey;
const String _homeBalanceSourceIdPreferenceKey =
    homeBalanceSourceIdPreferenceKey;
const String _homeBalanceVisibilityHiddenPreferenceKey =
    homeBalanceVisibilityHiddenPreferenceKey;
Wallet? _findWalletInList(Iterable<Wallet> wallets, int? walletId) {
  return findWalletInList(wallets, walletId);
}

FinancialBucket? _findBucketInList(
  Iterable<FinancialBucket> buckets,
  int? bucketId,
) {
  return findBucketInList(buckets, bucketId);
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
    @visibleForTesting this.initialReminderPreferences,
    this.initialNotificationPayload,
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
  final ReminderPreferences? initialReminderPreferences;

  final NotificationPayload? initialNotificationPayload;

  @visibleForTesting
  final bool persistHomeHeroPreferences;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
  Timer? _transactionSheetFeedbackTimer;
  late final ReminderScheduler _reminderScheduler;
  StreamSubscription<NotificationPayload>? _notificationPayloadSubscription;

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

  Future<void> _syncReminderSchedule() {
    if (widget.skipInitialLoad) {
      return Future.value();
    }
    return _reminderScheduler.rescheduleForTonight();
  }

  Future<void> _markEveningAppOpenIfNeeded() async {
    if (widget.skipInitialLoad) return;
    final now = DateTime.now();
    if (now.hour < 20) return;
    await _dbHelper.markReminderAppOpenedAt(now);
  }

  void _handleNotificationPayload(NotificationPayload payload) {
    if (!mounted) return;

    switch (payload.target) {
      case NotificationRouteTarget.home:
        _tabController.animateTo(0);
        break;
      case NotificationRouteTarget.debts:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HutangPiutangPage(
              initialDebts: widget.skipInitialLoad ? const [] : null,
              initialWallets: widget.skipInitialLoad ? _activeWallets : null,
              initialBuckets: widget.skipInitialLoad ? _activeBuckets : null,
            ),
          ),
        ).then((_) => _syncReminderSchedule());
        break;
    }
  }

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
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelectionChanged);
    _reminderScheduler = ReminderScheduler(databaseHelper: _dbHelper);
    _notificationPayloadSubscription =
        LocalNotificationService.instance.payloadStream.listen(
      _handleNotificationPayload,
    );
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialNotificationPayload();
      });
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncReminderSchedule();
      _handleInitialNotificationPayload();
    });
  }

  void _handleInitialNotificationPayload() {
    final payload = widget.initialNotificationPayload;
    if (payload == null) return;
    _handleNotificationPayload(payload);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markEveningAppOpenIfNeeded().then((_) => _syncReminderSchedule());
    }
  }

  void _handleTabSelectionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _showSnackBarMessage(
    String message, {
    Color backgroundColor = AppPalette.primaryDark,
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
      await _markEveningAppOpenIfNeeded();
      await _syncReminderSchedule();
    } on StateError catch (_) {
      _showSnackBarMessage(
        'Gagal memuat data aplikasi. Coba lagi.',
        backgroundColor: AppPalette.danger,
        deferToNextFrame: true,
      );
    } on Exception catch (_) {
      _showSnackBarMessage(
        'Gagal memuat data aplikasi. Coba lagi.',
        backgroundColor: AppPalette.danger,
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

  List<Transaction> _filterInjectedTransactionsForHome(
    Iterable<Transaction> transactions,
  ) {
    final now = DateTime.now();
    final range = resolveHomeFilterRange(_selectedHomeFilter, now);

    return transactions.where((transaction) {
      final matchesWallet = _selectedHomeWallet == 'All' ||
          transaction.wallet == _selectedHomeWallet;
      final matchesRange = transaction.date
              .isAfter(range.start.subtract(const Duration(seconds: 1))) &&
          transaction.date.isBefore(range.end.add(const Duration(seconds: 1)));
      return matchesWallet && matchesRange;
    }).toList(growable: false);
  }

  Future<void> _loadTransactions() async {
    if (widget.skipInitialLoad) {
      final transactions = _filterInjectedTransactionsForHome(_allTransactions);
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
      });

      await _loadBucketHeroSummaries();
      return;
    }

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
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppPalette.backgroundGradient,
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
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 12),
        child: _buildEnhancedTabBar(),
      ),
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
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppPalette.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo Kak!',
                  style: GoogleFonts.poppins(
                    fontSize: 22, // Kecilkan sedikit
                    fontWeight: FontWeight.bold,
                    color: AppPalette.primaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Yuk kelola uang kamu hari ini',
                  style: GoogleFonts.poppins(
                    fontSize: 13, // Kecilkan sedikit
                    color: AppPalette.textSecondary,
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
                  color: AppPalette.warmAccent,
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
      height: 84,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
            const SizedBox(width: 64),
            _buildBottomNavItem(
              itemKey: const Key('bottom_nav_target_tabungan'),
              icon: Icons.flag_rounded,
              label: 'Target',
              tabIndex: 2,
            ),
            _buildBottomNavItem(
              itemKey: const Key('bottom_nav_wishlist_belanja'),
              icon: Icons.shopping_bag_outlined,
              label: 'Wishlist',
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
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: AppPalette.heroGradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.24),
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
                size: 22,
                color: isSelected ? Colors.white : AppPalette.primary,
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 12,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppPalette.primary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
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
            color: AppPalette.primary,
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
              color: AppPalette.primary,
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
                color: AppPalette.primary,
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
                color: AppPalette.primary,
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.date_range,
            size: 40,
            color: AppPalette.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Pilih rentang tanggal dulu',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppPalette.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Statistik rentang akan tampil setelah kamu memilih tanggal mulai dan tanggal akhir.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppPalette.textSecondary,
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
          color: isSelected ? AppPalette.primary : AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppPalette.border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: 0.08),
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
              color: isSelected ? Colors.white : AppPalette.primary,
            ),
            const SizedBox(width: 6),
            Text(
              wallet,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : AppPalette.primary,
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
                MaterialPageRoute(
                  builder: (_) => HutangPiutangPage(
                    initialDebts: widget.skipInitialLoad ? const [] : null,
                    initialWallets:
                        widget.skipInitialLoad ? _activeWallets : null,
                    initialBuckets:
                        widget.skipInitialLoad ? _activeBuckets : null,
                  ),
                ),
              ).then((_) async {
                await _loadAllTransactions();
                await _loadTransactions();
              }),
            ),
            const SizedBox(width: 12),
            _buildQuickMenuItem(
              itemKey: const Key('quick_menu_pos_keuangan'),
              icon: Icons.pie_chart_outline,
              label: 'Pos Keuangan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PosKeuanganPage(
                    initialBuckets:
                        widget.skipInitialLoad ? _activeBuckets : null,
                    initialWallets:
                        widget.skipInitialLoad ? _activeWallets : null,
                  ),
                ),
              ).then((_) => _loadBuckets()),
            ),
            const SizedBox(width: 12),
            _buildQuickMenuItem(
              itemKey: const Key('quick_menu_pengingat'),
              icon: Icons.notifications_active_outlined,
              label: 'Pengingat',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PengingatPage(
                    initialPreferences: widget.skipInitialLoad
                        ? (widget.initialReminderPreferences ??
                            const ReminderPreferences())
                        : null,
                    onPreferencesChanged: _syncReminderSchedule,
                  ),
                ),
              ).then((_) => _syncReminderSchedule()),
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
                    backgroundColor: AppPalette.background,
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
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppPalette.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              shortLabel,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppPalette.textPrimary,
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
    Color insightColor = AppPalette.success;

    if (thisMonthExpense < 500000) {
      insightText = 'Kamu hemat banget bulan ini! Keep it up!';
      insightIcon = Icons.auto_awesome_outlined;
      insightColor = AppPalette.success;
    } else if (thisMonthExpense > 1000000) {
      insightText = 'Pengeluaran lumayan besar nih, coba lebih hemat ya!';
      insightIcon = Icons.warning_amber_rounded;
      insightColor = AppPalette.warning;
    } else {
      insightText = 'Pengeluaran kamu masih wajar, good job!';
      insightIcon = Icons.thumb_up_off_alt_rounded;
      insightColor = AppPalette.info;
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
                    color: AppPalette.textSecondary,
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
                color: AppPalette.primary,
              ),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppPalette.primary,
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
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.08),
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
                              color: AppPalette.textPrimary,
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
                        color: AppPalette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: goal.progress,
                      backgroundColor: AppPalette.surfaceDisabled,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        goal.progress >= 1.0
                            ? AppPalette.success
                            : AppPalette.primary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${(goal.progress * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: goal.progress >= 1.0
                            ? AppPalette.success
                            : AppPalette.primary,
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
            color: isSelected ? AppPalette.primary : AppPalette.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppPalette.primary.withValues(alpha: 0.12),
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
                  color: isSelected ? Colors.white : AppPalette.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : AppPalette.primary,
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
          color: isSelected ? AppPalette.primary : AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: 0.12),
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
              color: isSelected ? Colors.white : AppPalette.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : AppPalette.primary,
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
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: AppPalette.info),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDateRange != null
                        ? formatSelectedDateRangeLabel(_selectedDateRange!)
                        : 'Pilih Rentang Tanggal',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.primaryDark,
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
                color: AppPalette.textPrimary,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      headerInfo.title,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (headerInfo.subtitle != null)
                      Text(
                        headerInfo.subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppPalette.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _shiftSelectedPeriod(1),
                icon: const Icon(Icons.chevron_right, size: 36),
                color: AppPalette.textPrimary,
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
          colors: AppPalette.heroGradient,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.25),
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
                    color: Colors.white,
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
                              color: AppPalette.successLight, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Pemasukan',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
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
                              color: AppPalette.danger, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Pengeluaran',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
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
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: 0.08),
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
                color: AppPalette.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada pengeluaran nih',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppPalette.textSecondary,
                ),
              ),
              Text(
                'Yuk mulai catat pengeluaran kamu!',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    List<PieChartSectionData> sections = [];
    const colors = AppPalette.categoryChartColors;

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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.08),
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
                      color: AppPalette.textSecondary,
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppPalette.textSecondary,
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada transaksi',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yuk mulai catat pemasukan dan\npengeluaran kamu!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showAddTransactionDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
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
        color: AppPalette.surface,
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
              color: AppPalette.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppPalette.textPrimary,
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
          final accentColor = transaction.type == 'income'
              ? AppPalette.success
              : AppPalette.danger;
          final typeLabel =
              transaction.type == 'income' ? 'Pemasukan' : 'Pengeluaran';
          final amountLabel =
              '${transaction.type == 'income' ? '+' : '-'} ${formatRupiah(transaction.amount)}';

          return Scaffold(
            key: const Key('transaction_detail_page'),
            backgroundColor: AppPalette.background,
            appBar: AppBar(
              title: Text(
                'Detail Transaksi',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textPrimary,
                ),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: AppPalette.textPrimary,
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
                        color: AppPalette.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.primary.withValues(alpha: 0.10),
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
                              color: AppPalette.textPrimary,
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
                              foregroundColor: AppPalette.danger,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: AppPalette.danger),
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
                              backgroundColor: AppPalette.primary,
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
        transaction.type == 'income' ? AppPalette.success : AppPalette.danger;
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
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppPalette.primary.withValues(alpha: 0.08),
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
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          transaction.category,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '• ${transaction.wallet}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(transaction.date),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppPalette.textSecondary,
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
          color: AppPalette.danger,
          icon: Icons.delete_outline,
          label: 'Delete',
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _buildTransactionActionBackground(
          color: AppPalette.info,
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
                    color: AppPalette.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _showAddGoalDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
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
                    color: AppPalette.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _showAddWishlistDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: AppPalette.textSecondary,
            ),
            const SizedBox(height: 20),
            Text(
              'Wishlist masih kosong',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yuk tambahkan barang impian\nyang pengen kamu beli!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showAddWishlistDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.08),
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
                    color: AppPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  formatRupiah(item.price),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.primary,
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
                color: AppPalette.primary,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Badge Kamu',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppPalette.primary,
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
          colors: AppPalette.heroGradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.2),
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
            color: Colors.white,
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: AppPalette.textSecondary,
            ),
            const SizedBox(height: 15),
            Text(
              'Belum ada badge',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppPalette.textSecondary,
              ),
            ),
            Text(
              'Yuk mulai catat transaksi dan\ncapai goal untuk dapetin badge!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppPalette.textSecondary,
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
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.08),
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
                      colors: AppPalette.badgeGradient,
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
                    color: AppPalette.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  badge.description,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppPalette.textSecondary,
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
                    color: AppPalette.textSecondary,
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
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: 0.08),
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
                  color: AppPalette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Mulai catat pengeluaran untuk melihat grafik',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppPalette.textSecondary,
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.08),
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
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  if (chartData.subtitle.isNotEmpty)
                    Text(
                      chartData.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Trend',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppPalette.accent,
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
                      color: AppPalette.border.withValues(alpha: 0.7),
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
                              color: AppPalette.textSecondary,
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
                                color: AppPalette.textSecondary,
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
                    left: BorderSide(color: AppPalette.border, width: 1),
                    bottom: BorderSide(color: AppPalette.border, width: 1),
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
                    tooltipBgColor: AppPalette.primaryDark,
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
                      colors: AppPalette.lineChartGradient,
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
                          color: AppPalette.surface,
                          strokeWidth: 3,
                          strokeColor: AppPalette.primary,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppPalette.primary.withValues(alpha: 0.22),
                          AppPalette.info.withValues(alpha: 0.10),
                          AppPalette.accent.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    shadow: Shadow(
                      color: AppPalette.primary.withValues(alpha: 0.22),
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
              color: AppPalette.accentSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppPalette.accent.withValues(alpha: 0.3),
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
                      colors: AppPalette.lineChartGradient,
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
                      color: AppPalette.accent,
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      disabledElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppPalette.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: 0.24),
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 64,
              color: AppPalette.textSecondary,
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada target tabungan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yuk bikin target tabungan untuk\nmewujudkan impian kamu!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showAddGoalDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
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
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.08),
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
                      ? AppPalette.success.withValues(alpha: 0.1)
                      : AppPalette.primary.withValues(alpha: 0.1),
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
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Target: ${formatRupiah(goal.targetAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                    if (goal.targetDate != null)
                      Text(
                        'Deadline: ${DateFormat('dd MMM yyyy').format(goal.targetDate!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppPalette.textSecondary,
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
                    color: AppPalette.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: AppPalette.textSecondary,
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
              color: AppPalette.surfaceDisabled,
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
                            ? AppPalette.goalCompleteGradient
                            : AppPalette.heroGradient,
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
                      color: AppPalette.textSecondary,
                    ),
                  ),
                  Text(
                    formatRupiah(goal.currentAmount),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: goal.progress >= 1.0
                      ? AppPalette.success
                      : AppPalette.primary,
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

    String? sheetFeedbackMessage;
    Color sheetFeedbackColor = Colors.red;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) {
          final categoryOptions =
              selectedType == 'expense' ? expenseCategories : incomeCategories;
          final isWalletLocked = deriveWalletNameFromBucketSelection() != null;

          void showSheetFeedback(
            String message, {
            Color backgroundColor = Colors.red,
          }) {
            _transactionSheetFeedbackTimer?.cancel();
            setState(() {
              sheetFeedbackMessage = message;
              sheetFeedbackColor = backgroundColor;
            });
            _transactionSheetFeedbackTimer = Timer(
              _sheetFeedbackAutoHideDuration,
              () {
                if (!sheetContext.mounted) return;
                if (sheetFeedbackMessage == null) return;
                setState(() => sheetFeedbackMessage = null);
              },
            );
          }

          void clearSheetFeedback() {
            _transactionSheetFeedbackTimer?.cancel();
            if (sheetFeedbackMessage == null) return;
            setState(() => sheetFeedbackMessage = null);
          }

          Future<void> handleSaveTransaction() async {
            clearSheetFeedback();

            if (amountController.text.isEmpty) {
              showSheetFeedback(
                'Jumlah wajib diisi.',
                backgroundColor: Colors.red,
              );
              return;
            }

            if (descriptionController.text.trim().isEmpty) {
              showSheetFeedback(
                'Keterangan wajib diisi.',
                backgroundColor: Colors.red,
              );
              return;
            }

            try {
              final amount = parseCurrencyInput(amountController.text);
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
                  showSheetFeedback(
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
                  showSheetFeedback(
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
                          selectedIncomeBucketIds.contains(bucket.id))
                      .toList();
                  if (subsetBuckets.isEmpty) {
                    showSheetFeedback(
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
                  showSheetFeedback(
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
                    showSheetFeedback(
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
            } on InsufficientBalanceException {
              showSheetFeedback(
                _insufficientBalanceMessage,
                backgroundColor: Colors.red,
              );
            } on StateError catch (error) {
              final rawMessage = error.message.toString();
              final userMessage = rawMessage.contains('one effective wallet')
                  ? 'Pilih bucket pemasukan dari satu dompet yang sama.'
                  : rawMessage.contains('debt records')
                      ? 'Transaksi dari hutang/piutang harus dikelola dari halaman hutang/piutang.'
                      : 'Transaksi gagal diproses. Cek dompet dan pos yang dipilih.';
              showSheetFeedback(
                userMessage,
                backgroundColor: Colors.red,
              );
            } on Exception catch (_) {
              showSheetFeedback(
                'Transaksi gagal disimpan. Coba lagi.',
                backgroundColor: Colors.red,
              );
            }
          }

          return FractionallySizedBox(
            heightFactor: 0.88,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                      if (sheetFeedbackMessage != null) ...[
                        Container(
                          key: const Key('transaction_sheet_feedback'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: sheetFeedbackColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sheetFeedbackColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: sheetFeedbackColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  sheetFeedbackMessage!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: sheetFeedbackColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(sheetContext).viewInsets.bottom +
                                    20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing
                                    ? 'Edit Transaksi'
                                    : 'Tambah Transaksi 💰',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppPalette.primary,
                                ),
                              ),
                              const SizedBox(height: 25),
                              Text(
                                'Tipe Transaksi',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.textPrimary,
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
                                                if (!expenseCategories.contains(
                                                  selectedCategory,
                                                )) {
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
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selectedType == 'expense'
                                              ? Colors.red.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.grey.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                            color: selectedType == 'expense'
                                                ? Colors.red
                                                : Colors.grey.withValues(
                                                    alpha: 0.3,
                                                  ),
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
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
                                                if (!incomeCategories.contains(
                                                  selectedCategory,
                                                )) {
                                                  selectedCategory =
                                                      incomeCategories.first;
                                                }
                                                if (selectedIncomeBucketIds
                                                    .isEmpty) {
                                                  selectedIncomeBucketIds
                                                      .addAll(
                                                    _activeBuckets
                                                        .where((bucket) =>
                                                            bucket.id != null)
                                                        .map(
                                                          (bucket) =>
                                                              bucket.id!,
                                                        ),
                                                  );
                                                }
                                                syncWalletToBucketSelection();
                                              }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selectedType == 'income'
                                              ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                              : Colors.grey.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                            color: selectedType == 'income'
                                                ? Colors.green
                                                : Colors.grey.withValues(
                                                    alpha: 0.3,
                                                  ),
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
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
                                'Kategori',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 42,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: categoryOptions.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final category = categoryOptions[index];
                                    final isSelected =
                                        category == selectedCategory;
                                    return ChoiceChip(
                                      label: Text(category),
                                      selected: isSelected,
                                      showCheckmark: false,
                                      onSelected: (_) => setState(
                                        () => selectedCategory = category,
                                      ),
                                      side: BorderSide(
                                        color: isSelected
                                            ? AppPalette.primary
                                            : AppPalette.border,
                                      ),
                                      backgroundColor: AppPalette.surface,
                                      selectedColor: AppPalette.primary,
                                      labelStyle: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppPalette.primary,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      'Jumlah',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppPalette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppPalette.surfaceMuted,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppPalette.surface,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Text(
                                              'Rp',
                                              style: GoogleFonts.poppins(
                                                color: AppPalette.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 190,
                                            child: TextField(
                                              controller: amountController,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                CurrencyInputFormatter(),
                                              ],
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 36,
                                                fontWeight: FontWeight.bold,
                                                color: AppPalette.textPrimary,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                hintStyle: GoogleFonts.poppins(
                                                  color:
                                                      AppPalette.textSecondary,
                                                  fontSize: 36,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Masukkan jumlah',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppPalette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Dompet',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppPalette.surfaceMuted,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedWallet,
                                    isExpanded: true,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: AppPalette.primary,
                                    ),
                                    style: GoogleFonts.poppins(
                                      color: AppPalette.textPrimary,
                                    ),
                                    onChanged: isWalletLocked
                                        ? null
                                        : (String? newValue) {
                                            if (newValue == null) return;
                                            setState(() =>
                                                selectedWallet = newValue);
                                          },
                                    items: availableWallets
                                        .map<DropdownMenuItem<String>>(
                                      (Wallet wallet) {
                                        return DropdownMenuItem<String>(
                                          value: wallet.name,
                                          child: Row(
                                            children: [
                                              Icon(
                                                resolveWalletIcon(
                                                  wallet.iconKey,
                                                  wallet.name,
                                                ),
                                                size: 16,
                                                color: AppPalette.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(wallet.name),
                                            ],
                                          ),
                                        );
                                      },
                                    ).toList(),
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
                                        color: AppPalette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (!affectsBalance)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(15),
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
                                        key: const Key(
                                          'income_bucket_selector',
                                        ),
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(15),
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
                                                    children: _activeBuckets
                                                        .map((bucket) {
                                                      final bucketId =
                                                          bucket.id!;
                                                      final isSelected =
                                                          selectedIncomeBucketIds
                                                              .contains(
                                                        bucketId,
                                                      );
                                                      return FilterChip(
                                                        label: Text(
                                                          bucket.name,
                                                        ),
                                                        selected: isSelected,
                                                        onSelected: (selected) {
                                                          setState(() {
                                                            if (selected) {
                                                              selectedIncomeBucketIds
                                                                  .add(
                                                                bucketId,
                                                              );
                                                            } else {
                                                              selectedIncomeBucketIds
                                                                  .remove(
                                                                bucketId,
                                                              );
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
                                          color: Colors.grey.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(15),
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
                                        key: const Key(
                                          'expense_bucket_dropdown',
                                        ),
                                        value: selectedExpenseBucket,
                                        items: _activeBuckets
                                            .map(
                                              (bucket) => DropdownMenuItem<
                                                  FinancialBucket>(
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
                                          fillColor: AppPalette.surfaceMuted,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
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
                                  color: AppPalette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppPalette.surfaceMuted,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: TextField(
                                  controller: descriptionController,
                                  style: GoogleFonts.poppins(),
                                  decoration: InputDecoration(
                                    hintText: 'Tambahkan keterangan...',
                                    hintStyle: GoogleFonts.poppins(
                                      color: AppPalette.textSecondary,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(20),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: 12,
                          bottom:
                              MediaQuery.of(sheetContext).viewInsets.bottom +
                                  20,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: handleSaveTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.primary,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              isEditing
                                  ? 'Update Transaksi'
                                  : 'Simpan Transaksi',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
        },
      ),
    ).whenComplete(() {
      _transactionSheetFeedbackTimer?.cancel();
      _transactionSheetFeedbackTimer = null;
    });
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
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(height: 25),

                // Name input
                Text(
                  'Nama Target',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceMuted,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: nameController,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      hintText: 'Contoh: iPhone baru, Liburan ke Bali',
                      hintStyle:
                          GoogleFonts.poppins(color: AppPalette.textSecondary),
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
                    color: AppPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppPalette.surfaceMuted,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      hintText: 'Masukkan target jumlah',
                      hintStyle:
                          GoogleFonts.poppins(color: AppPalette.textSecondary),
                      prefixText: 'Rp ',
                      prefixStyle: GoogleFonts.poppins(
                        color: AppPalette.primary,
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
                    color: AppPalette.textPrimary,
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
                                ? AppPalette.primary.withValues(alpha: 0.2)
                                : AppPalette.surfaceMuted,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: selectedEmoji == emoji
                                  ? AppPalette.primary
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
                    color: AppPalette.textPrimary,
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
                      color: AppPalette.surfaceMuted,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppPalette.primary),
                        const SizedBox(width: 15),
                        Text(
                          selectedDate != null
                              ? DateFormat('dd MMM yyyy').format(selectedDate!)
                              : 'Pilih tanggal target',
                          style: GoogleFonts.poppins(
                            color: selectedDate != null
                                ? AppPalette.textPrimary
                                : AppPalette.textSecondary,
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
                      backgroundColor: AppPalette.primary,
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
    String? sheetFeedbackMessage;
    Color sheetFeedbackColor = Colors.red;

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
        builder: (context, setState) {
          void showSheetFeedback(
            String message, {
            Color backgroundColor = Colors.red,
          }) {
            _transactionSheetFeedbackTimer?.cancel();
            setState(() {
              sheetFeedbackMessage = message;
              sheetFeedbackColor = backgroundColor;
            });
            _transactionSheetFeedbackTimer = Timer(
              _sheetFeedbackAutoHideDuration,
              () {
                if (!context.mounted || sheetFeedbackMessage == null) return;
                setState(() => sheetFeedbackMessage = null);
              },
            );
          }

          void clearSheetFeedback() {
            _transactionSheetFeedbackTimer?.cancel();
            if (sheetFeedbackMessage == null) return;
            setState(() => sheetFeedbackMessage = null);
          }

          return Container(
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
                  if (sheetFeedbackMessage != null) ...[
                    Container(
                      key: const Key('wishlist_sheet_feedback'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: sheetFeedbackColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: sheetFeedbackColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: sheetFeedbackColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              sheetFeedbackMessage!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sheetFeedbackColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Tambah ke Wishlist 🛍️',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.primary,
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
                              color: AppPalette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppPalette.surfaceMuted,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: TextField(
                              controller: nameController,
                              style: GoogleFonts.poppins(),
                              decoration: InputDecoration(
                                hintText: 'Contoh: Dress cantik, Sepatu heels',
                                hintStyle: GoogleFonts.poppins(
                                  color: AppPalette.textSecondary,
                                ),
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
                              color: AppPalette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppPalette.surfaceMuted,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              style: GoogleFonts.poppins(),
                              decoration: InputDecoration(
                                hintText: 'Masukkan harga',
                                hintStyle: GoogleFonts.poppins(
                                  color: AppPalette.textSecondary,
                                ),
                                prefixText: 'Rp ',
                                prefixStyle: GoogleFonts.poppins(
                                  color: AppPalette.primary,
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
                              color: AppPalette.textPrimary,
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
                                          ? AppPalette.primary
                                              .withValues(alpha: 0.2)
                                          : AppPalette.surfaceMuted,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: selectedEmoji == emoji
                                            ? AppPalette.primary
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
                              color: AppPalette.textPrimary,
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
                                        ? priority['color']
                                            .withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color:
                                          selectedPriority == priority['value']
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
                                          borderRadius:
                                              BorderRadius.circular(10),
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
                      color: AppPalette.surface,
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.border.withValues(alpha: 0.8),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          clearSheetFeedback();
                          // Validasi input
                          if (nameController.text.isEmpty) {
                            showSheetFeedback(
                              'Nama barang tidak boleh kosong!',
                            );
                            return;
                          }

                          if (priceController.text.isEmpty) {
                            showSheetFeedback(
                              'Harga tidak boleh kosong!',
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
                              backgroundColor: AppPalette.danger,
                            );
                          } on Exception catch (_) {
                            _showSnackBarMessage(
                              'Wishlist gagal disimpan. Coba lagi.',
                              backgroundColor: AppPalette.danger,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 8,
                          shadowColor:
                              AppPalette.primary.withValues(alpha: 0.4),
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
          );
        },
      ),
    ).whenComplete(() {
      _transactionSheetFeedbackTimer?.cancel();
      _transactionSheetFeedbackTimer = null;
    });
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
                              colors: AppPalette.heroGradient,
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
                                        color: Colors.white
                                            .withValues(alpha: 0.78),
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
                            color: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Jumlah Uang',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          decoration: BoxDecoration(
                            color: AppPalette.surfaceMuted,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              hintText: 'Masukkan jumlah',
                              hintStyle: GoogleFonts.poppins(
                                color: AppPalette.textSecondary,
                              ),
                              prefixText: 'Rp ',
                              prefixStyle: GoogleFonts.poppins(
                                color: AppPalette.primary,
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
                            color: AppPalette.textPrimary,
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
                                  backgroundColor: AppPalette.danger,
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
                                  backgroundColor: AppPalette.danger,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppPalette.primary,
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
            color: AppPalette.accentSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppPalette.accent.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: AppPalette.accent,
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
    String? dialogFeedbackMessage;
    Color dialogFeedbackColor = Colors.red;

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
        builder: (dialogContext, setDialogState) {
          void showDialogFeedback(
            String message, {
            Color backgroundColor = Colors.red,
          }) {
            _transactionSheetFeedbackTimer?.cancel();
            setDialogState(() {
              dialogFeedbackMessage = message;
              dialogFeedbackColor = backgroundColor;
            });
            _transactionSheetFeedbackTimer = Timer(
              _sheetFeedbackAutoHideDuration,
              () {
                if (!dialogContext.mounted || dialogFeedbackMessage == null) {
                  return;
                }
                setDialogState(() => dialogFeedbackMessage = null);
              },
            );
          }

          void clearDialogFeedback() {
            _transactionSheetFeedbackTimer?.cancel();
            if (dialogFeedbackMessage == null) return;
            setDialogState(() => dialogFeedbackMessage = null);
          }

          return AlertDialog(
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
                  if (dialogFeedbackMessage != null) ...[
                    Container(
                      key: const Key('wishlist_buy_feedback'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: dialogFeedbackColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: dialogFeedbackColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: dialogFeedbackColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dialogFeedbackMessage!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: dialogFeedbackColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Kamu mau beli ${item.name}?',
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Harga: ${formatRupiah(item.price)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppPalette.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _activeBuckets.isEmpty
                        ? 'Belum ada pos keuangan aktif. Pembelian tetap dicatat tanpa pos sumber.'
                        : 'Pilih pos sumber; dompet akan mengikuti pos itu agar saldo tetap konsisten.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppPalette.textSecondary,
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
                onPressed: () {
                  clearDialogFeedback();
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  'Batal',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () async {
                  clearDialogFeedback();
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
                  } on InsufficientBalanceException {
                    showDialogFeedback(
                      _insufficientBalanceMessage,
                    );
                  } on Exception catch (_) {
                    showDialogFeedback(
                      'Pembelian wishlist gagal diproses. Coba lagi.',
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
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _transactionSheetFeedbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _notificationPayloadSubscription?.cancel();
    _tabController.removeListener(_handleTabSelectionChanged);
    _tabController.dispose();
    super.dispose();
  }
}
