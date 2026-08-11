import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatters.dart';
import '../../../core/icons/app_icons.dart';
import '../../../data/database/database_helper.dart';
import '../../buckets/helpers/bucket_helpers.dart';
import '../../buckets/models/bucket_models.dart';
import '../../wallets/models/wallet.dart';
import '../models/debt_models.dart';

const String _bucketConfigurationIncompleteMessage =
    bucketConfigurationIncompleteMessage;
const String _insufficientBalanceMessage = insufficientBalanceMessage;
const Duration _sheetFeedbackAutoHideDuration = Duration(seconds: 3);

class HutangPiutangPage extends StatefulWidget {
  const HutangPiutangPage({
    super.key,
    this.initialDebts,
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
        title: Text(
          'Hutang / Piutang',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
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
                  itemBuilder: (_, index) => _buildDebtItem(_debts[index]),
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
            Text(
              'Belum ada hutang/piutang',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + untuk mencatat hutang atau piutang',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );

  Widget _buildDebtItem(Debt debt) {
    final normalizedType = debt.type.trim().toLowerCase();
    final isDebt = normalizedType == 'debt' || normalizedType == 'hutang';
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
            Text(
              debt.personName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
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
                  fontWeight: FontWeight.w600,
                ),
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
              child: Text(
                statusLabel,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              builder: (_) => HutangDetailPage(
                debt: debt,
                initialPayments: widget.initialDebts != null ? const [] : null,
                initialWallets: _wallets,
                initialBuckets: _buckets,
              ),
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
      builder: (ctx) => DebtFormSheet(
        initialWallets: _wallets.isEmpty ? null : _wallets,
        initialBuckets: _buckets.isEmpty ? null : _buckets,
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
  String? _sheetFeedbackMessage;
  Color _sheetFeedbackColor = Colors.red;
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _feedbackTimer;
  double _sheetDragOffset = 0;

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
    _feedbackTimer?.cancel();
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scheduleValidationMessageClear() {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(_sheetFeedbackAutoHideDuration, () {
      if (!mounted || _sheetFeedbackMessage == null) return;
      setState(() => _sheetFeedbackMessage = null);
    });
  }

  void _updateSheetDragOffset(DragUpdateDetails details) {
    final nextOffset =
        (_sheetDragOffset + (details.primaryDelta ?? details.delta.dy))
            .clamp(0.0, 220.0)
            .toDouble();
    if (nextOffset == _sheetDragOffset) return;
    setState(() => _sheetDragOffset = nextOffset);
  }

  void _resetSheetDragOffset() {
    if (_sheetDragOffset == 0) return;
    setState(() => _sheetDragOffset = 0);
  }

  void _finishSheetDrag(DragEndDetails details) {
    final shouldDismiss =
        _sheetDragOffset > 120 || (details.primaryVelocity ?? 0) > 700;
    if (shouldDismiss) {
      Navigator.of(context).pop();
      return;
    }
    _resetSheetDragOffset();
  }

  void _showValidationMessage(
    String message, {
    Color backgroundColor = Colors.red,
  }) {
    _feedbackTimer?.cancel();
    setState(() {
      _sheetFeedbackMessage = message;
      _sheetFeedbackColor = backgroundColor;
    });
    _scheduleValidationMessageClear();
  }

  void _clearValidationMessage() {
    _feedbackTimer?.cancel();
    if (_sheetFeedbackMessage == null) return;
    setState(() => _sheetFeedbackMessage = null);
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
    _clearValidationMessage();

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
        'Buat pos keuangan aktif dulu untuk mode Masuk ke saldo',
      );
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
      try {
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
      } on InsufficientBalanceException {
        _showValidationMessage(_insufficientBalanceMessage);
        return;
      }
    }

    if (existing == null) {
      await db.insertDebt(
        Debt(
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
        ),
      );
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
      await db.updateDebt(
        Debt(
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
        ),
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialDebt != null;
    final lockBalanceFields =
        isEditMode && widget.initialDebt!.recordingMode == 'balance';
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Transform.translate(
        offset: Offset(0, _sheetDragOffset),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: _updateSheetDragOffset,
                      onVerticalDragEnd: _finishSheetDrag,
                      onVerticalDragCancel: _resetSheetDragOffset,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_sheetFeedbackMessage != null) ...[
                    Container(
                      key: const Key('debt_sheet_feedback'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _sheetFeedbackColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _sheetFeedbackColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: _sheetFeedbackColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _sheetFeedbackMessage!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _sheetFeedbackColor,
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
                      controller: _scrollCtrl,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
                      child: Column(
                        key: const Key('debt_form_sheet'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                      : () => setState(
                                          () => _selectedType = 'debt'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedType == 'debt'
                                          ? Colors.redAccent
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Saya Berhutang',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        color: _selectedType == 'debt'
                                            ? Colors.white
                                            : Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedType == 'receivable'
                                          ? Colors.green
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Piutang Saya',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        color: _selectedType == 'receivable'
                                            ? Colors.white
                                            : Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                                      icon: const Icon(
                                          Icons.calendar_today_outlined),
                                      label: Text(
                                        DateFormat('dd MMM yyyy')
                                            .format(_borrowedDate),
                                      ),
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
                                      icon: const Icon(
                                          Icons.event_available_outlined),
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
                            onChanged: lockBalanceFields ||
                                    _selectedMode == 'balance'
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
                                .map(
                                  (bucket) => DropdownMenuItem<FinancialBucket>(
                                    value: bucket,
                                    child: Row(
                                      children: [
                                        Icon(
                                          bucket.resolvedIcon,
                                          size: 16,
                                          color: const Color(0xFFFF69B4),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(bucket.name),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: lockBalanceFields
                                ? null
                                : (bucket) => setState(() {
                                      _selectedBucket = bucket;
                                      if (_selectedMode == 'balance' &&
                                          bucket?.walletId != null) {
                                        final matches = _wallets.where(
                                          (wallet) =>
                                              wallet.id == bucket?.walletId,
                                        );
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
                              Text(
                                'Mode Pencatatan',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600),
                              ),
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _save,
                              child: Text(
                                isEditMode ? 'Simpan Perubahan' : 'Simpan',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    helper,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
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

class HutangDetailPage extends StatefulWidget {
  const HutangDetailPage({
    super.key,
    required this.debt,
    this.initialPayments,
    this.initialWallets,
    this.initialBuckets,
    this.recordDebtPayment,
    this.loadDebtById,
    this.loadPaymentsByDebt,
  });

  final Debt debt;
  final List<DebtPayment>? initialPayments;
  final List<Wallet>? initialWallets;
  final List<FinancialBucket>? initialBuckets;
  final Future<void> Function({
    required int debtId,
    required double amount,
    required DateTime paymentDate,
    required String recordingMode,
    int? walletId,
    int? bucketId,
    FinancialBucket? affectedBucket,
  })? recordDebtPayment;
  final Future<Debt?> Function(int debtId)? loadDebtById;
  final Future<List<DebtPayment>> Function(int debtId)? loadPaymentsByDebt;

  @override
  State<HutangDetailPage> createState() => _HutangDetailPageState();
}

class _HutangDetailPageState extends State<HutangDetailPage> {
  late Debt _debt;
  late List<DebtPayment> _payments;
  List<Wallet> _availableWallets = const [];
  List<FinancialBucket> _availableBuckets = const [];
  String? _paymentSheetFeedbackMessage;
  Color _paymentSheetFeedbackColor = Colors.red;
  Timer? _paymentSheetFeedbackTimer;

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

  Future<Debt?> _fetchDebt(int debtId) {
    final loader = widget.loadDebtById;
    if (loader != null) {
      return loader(debtId);
    }
    return DatabaseHelper().getDebtById(debtId);
  }

  Future<List<DebtPayment>> _fetchPayments(int debtId) {
    final loader = widget.loadPaymentsByDebt;
    if (loader != null) {
      return loader(debtId);
    }
    return DatabaseHelper().getDebtPaymentsByDebt(debtId);
  }

  Future<void> _loadPayments() async {
    final payments = await _fetchPayments(_debt.id!);
    if (!mounted) return;
    setState(() => _payments = payments);
  }

  Future<void> _refresh() async {
    final debt = await _fetchDebt(_debt.id!);
    final payments = await _fetchPayments(_debt.id!);
    if (!mounted || debt == null) return;
    setState(() {
      _debt = debt;
      _payments = payments;
    });
  }

  @override
  void dispose() {
    _paymentSheetFeedbackTimer?.cancel();
    super.dispose();
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
        title: Text(
          _debt.personName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
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
                builder: (ctx) => DebtFormSheet(
                  initialDebt: _debt,
                  initialWallets:
                      _availableWallets.isEmpty ? null : _availableWallets,
                  initialBuckets:
                      _availableBuckets.isEmpty ? null : _availableBuckets,
                ),
              );
              await _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final hasBalanceEffect = _debt.recordingMode == 'balance';
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(
                    'Hapus catatan?',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    hasBalanceEffect
                        ? 'Catatan ini sudah memengaruhi saldo. Menghapusnya tidak akan mengembalikan saldo kamu.'
                        : 'Catatan hutang/piutang ini akan dihapus permanen.',
                    style: GoogleFonts.poppins(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Batal', style: GoogleFonts.poppins()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'Hapus',
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm != true || !mounted) return;
              await DatabaseHelper().deleteDebt(_debt.id!);
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _debt.personName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(_debt.progressFraction * 100).toStringAsFixed(0)}% lunas',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _metaRow('Nominal awal', formatRupiah(_debt.principalAmount)),
            _metaRow(
              'Tanggal pinjam',
              DateFormat('dd MMM yyyy').format(_debt.borrowedDate),
            ),
            _metaRow(
              'Status',
              _debt.status == 'settled'
                  ? 'Lunas'
                  : (_debt.isOverdue ? 'Terlambat' : 'Aktif'),
            ),
            _metaRow(
              'Mode',
              _debt.recordingMode == 'balance'
                  ? 'Masuk ke saldo'
                  : 'Catatan saja',
            ),
            if (linkedWallet != null) _metaRow('Dompet', linkedWallet.name),
            if (linkedBucket != null)
              _metaRow('Pos Keuangan', linkedBucket.name),
            if (_debt.dueDate != null)
              _metaRow(
                'Jatuh tempo',
                DateFormat('dd MMM yyyy').format(_debt.dueDate!),
              ),
            if (_debt.note?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'Catatan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
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
            Text(
              'Riwayat Pembayaran',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (_payments.isEmpty)
              Text(
                'Belum ada cicilan',
                style: GoogleFonts.poppins(color: Colors.grey),
              )
            else
              ..._payments.map(_paymentItem),
          ],
        ),
      ),
      floatingActionButton: isActive
          ? FloatingActionButton.extended(
              key: const Key('debt_pay_btn'),
              backgroundColor: const Color(0xFFFF69B4),
              icon: const Icon(Icons.payments_outlined, color: Colors.white),
              label: Text(
                'Catat Pembayaran',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );

  Widget _paymentItem(DebtPayment payment) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.check_circle_outline, color: Colors.green),
          title: Text(
            formatRupiah(payment.amount),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            DateFormat('dd MMM yyyy').format(payment.paymentDate),
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ),
      );

  void _showPaymentSheetFeedback(
    BuildContext sheetContext,
    void Function(void Function()) setModalState,
    String message, {
    Color backgroundColor = Colors.red,
  }) {
    _paymentSheetFeedbackTimer?.cancel();
    setModalState(() {
      _paymentSheetFeedbackMessage = message;
      _paymentSheetFeedbackColor = backgroundColor;
    });
    _paymentSheetFeedbackTimer = Timer(_sheetFeedbackAutoHideDuration, () {
      if (!mounted || !sheetContext.mounted) return;
      if (_paymentSheetFeedbackMessage == null) return;
      setModalState(() => _paymentSheetFeedbackMessage = null);
    });
  }

  void _clearPaymentSheetFeedback(
    void Function(void Function()) setModalState,
  ) {
    _paymentSheetFeedbackTimer?.cancel();
    if (_paymentSheetFeedbackMessage == null) return;
    setModalState(() => _paymentSheetFeedbackMessage = null);
  }

  Future<void> _showPaymentSheet(BuildContext context) async {
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
    double sheetDragOffset = 0;
    _paymentSheetFeedbackTimer?.cancel();
    _paymentSheetFeedbackMessage = null;

    final shouldRefresh = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => FractionallySizedBox(
          heightFactor: 0.88,
          child: Transform.translate(
            offset: Offset(0, sheetDragOffset),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            final nextOffset = (sheetDragOffset +
                                    (details.primaryDelta ?? details.delta.dy))
                                .clamp(0.0, 220.0)
                                .toDouble();
                            if (nextOffset == sheetDragOffset) return;
                            setModalState(() => sheetDragOffset = nextOffset);
                          },
                          onVerticalDragEnd: (details) {
                            final shouldDismiss = sheetDragOffset > 120 ||
                                (details.primaryVelocity ?? 0) > 700;
                            if (shouldDismiss) {
                              Navigator.of(ctx).pop();
                              return;
                            }
                            if (sheetDragOffset == 0) return;
                            setModalState(() => sheetDragOffset = 0);
                          },
                          onVerticalDragCancel: () {
                            if (sheetDragOffset == 0) return;
                            setModalState(() => sheetDragOffset = 0);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_paymentSheetFeedbackMessage != null) ...[
                        Container(
                          key: const Key('payment_sheet_feedback'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _paymentSheetFeedbackColor.withValues(
                                alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _paymentSheetFeedbackColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: _paymentSheetFeedbackColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _paymentSheetFeedbackMessage!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _paymentSheetFeedbackColor,
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
                            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Catat Pembayaran',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                key: const Key('payment_mode_indicator'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
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
                                    Expanded(
                                      child: Text(
                                        _debt.recordingMode == 'balance'
                                            ? 'Masuk ke saldo — memengaruhi pos keuangan'
                                            : 'Catatan saja — tidak mengubah saldo',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color:
                                              _debt.recordingMode == 'balance'
                                                  ? Colors.green
                                                  : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (paymentWallet != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        resolveWalletIcon(
                                          paymentWallet.iconKey,
                                          paymentWallet.name,
                                        ),
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
                              if (paymentWallet != null)
                                const SizedBox(height: 16),
                              if (_debt.recordingMode == 'balance') ...[
                                DropdownButtonFormField<FinancialBucket>(
                                  key: const Key('payment_bucket_dropdown'),
                                  value: selectedBucket,
                                  items: _availableBuckets
                                      .map(
                                        (bucket) =>
                                            DropdownMenuItem<FinancialBucket>(
                                          value: bucket,
                                          child: Text(bucket.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (bucket) => setModalState(() {
                                    selectedBucket = bucket;
                                  }),
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
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  onPressed: () async {
                                    _clearPaymentSheetFeedback(setModalState);
                                    final amount = tryParseCurrencyInput(
                                            amountCtrl.text.trim()) ??
                                        0;
                                    if (amount <= 0) {
                                      _showPaymentSheetFeedback(
                                        ctx,
                                        setModalState,
                                        'Nominal cicilan harus lebih besar dari 0.',
                                      );
                                      return;
                                    }
                                    if (amount > _debt.remainingAmount) {
                                      _showPaymentSheetFeedback(
                                        ctx,
                                        setModalState,
                                        'Nominal cicilan melebihi sisa yang harus dibayar.',
                                      );
                                      return;
                                    }
                                    if (_debt.recordingMode == 'balance' &&
                                        _availableBuckets.isEmpty) {
                                      _showPaymentSheetFeedback(
                                        ctx,
                                        setModalState,
                                        'Buat pos keuangan aktif dulu untuk pembayaran ini.',
                                      );
                                      return;
                                    }
                                    if (_debt.recordingMode == 'balance' &&
                                        hasIncompleteBucketConfiguration(
                                            _availableBuckets)) {
                                      _showPaymentSheetFeedback(
                                        ctx,
                                        setModalState,
                                        _bucketConfigurationIncompleteMessage,
                                      );
                                      return;
                                    }
                                    if (_debt.recordingMode == 'balance' &&
                                        selectedBucket == null) {
                                      _showPaymentSheetFeedback(
                                        ctx,
                                        setModalState,
                                        'Pilih pos keuangan untuk pembayaran ini.',
                                      );
                                      return;
                                    }
                                    try {
                                      final recorder = widget.recordDebtPayment;
                                      if (recorder != null) {
                                        await recorder(
                                          debtId: _debt.id!,
                                          amount: amount,
                                          paymentDate: DateTime.now(),
                                          recordingMode: _debt.recordingMode,
                                          walletId: _debt.walletId,
                                          bucketId: _debt.bucketId,
                                          affectedBucket: selectedBucket,
                                        );
                                      } else {
                                        await DatabaseHelper()
                                            .recordDebtPayment(
                                          debtId: _debt.id!,
                                          amount: amount,
                                          paymentDate: DateTime.now(),
                                          recordingMode: _debt.recordingMode,
                                          walletId: _debt.walletId,
                                          bucketId: _debt.bucketId,
                                          affectedBucket: selectedBucket,
                                        );
                                      }
                                    } on RangeError {
                                      _showPaymentSheetFeedback(
                                        ctx,
                                        setModalState,
                                        'Nominal cicilan melebihi sisa yang harus dibayar.',
                                      );
                                      return;
                                    } on ArgumentError {
                                      _showPaymentSheetFeedback(
                                        ctx,
                                        setModalState,
                                        'Nominal cicilan tidak valid.',
                                      );
                                      return;
                                    } on InsufficientBalanceException {
                                      _showPaymentSheetFeedback(
                                        ctx,
                                        setModalState,
                                        _insufficientBalanceMessage,
                                      );
                                      return;
                                    } on StateError {
                                      _showPaymentSheetFeedback(
                                        ctx,
                                        setModalState,
                                        'Catatan ini sudah lunas.',
                                      );
                                      return;
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx, true);
                                  },
                                  child: Text(
                                    'Simpan',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      _paymentSheetFeedbackTimer?.cancel();
      _paymentSheetFeedbackTimer = null;
    });
    if (shouldRefresh == true && mounted) {
      await _refresh();
    }
  }
}
