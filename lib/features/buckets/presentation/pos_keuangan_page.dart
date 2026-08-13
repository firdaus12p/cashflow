import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatters.dart';
import '../../../core/icons/app_icons.dart';
import '../../../data/database/database_helper.dart';
import '../helpers/bucket_helpers.dart';
import '../models/bucket_models.dart';
import '../../wallets/models/wallet.dart';

const Map<String, IconData> _availableBucketIcons = availableBucketIcons;
const String _insufficientBalanceMessage = insufficientBalanceMessage;
const Duration _sheetFeedbackAutoHideDuration = Duration(seconds: 3);

class PosKeuanganPage extends StatefulWidget {
  const PosKeuanganPage({
    super.key,
    this.initialBuckets,
    this.initialWallets,
    this.initialBucketSystemEnabled,
    this.previewBucketReconciliations,
    this.applyBucketReconciliations,
    this.setBucketSystemEnabled,
    @visibleForTesting this.bucketBalanceOverride,
  });

  final List<FinancialBucket>? initialBuckets;
  final List<Wallet>? initialWallets;
  final bool? initialBucketSystemEnabled;
  final Future<Map<int, BucketReconciliationPreview>> Function()?
      previewBucketReconciliations;
  final Future<void> Function()? applyBucketReconciliations;
  final Future<void> Function(bool isEnabled)? setBucketSystemEnabled;
  final Map<int, double>? bucketBalanceOverride;

  @override
  State<PosKeuanganPage> createState() => _PosKeuanganPageState();
}

class _PosKeuanganPageState extends State<PosKeuanganPage> {
  late List<FinancialBucket> _buckets;
  late List<Wallet> _wallets;
  bool _bucketSystemEnabled = true;
  bool _isLoading = false;
  Timer? _bucketSheetFeedbackTimer;
  Timer? _transferSheetFeedbackTimer;

  @override
  void initState() {
    super.initState();
    final provided = widget.initialBuckets;
    _wallets = widget.initialWallets ?? const [];
    _bucketSystemEnabled =
        widget.initialBucketSystemEnabled ?? _bucketSystemEnabled;
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
    final bucketSystemEnabled = widget.initialBucketSystemEnabled ??
        await DatabaseHelper().getBucketSystemEnabled();
    if (!mounted) return;
    setState(() {
      _buckets = buckets;
      _wallets = wallets;
      _bucketSystemEnabled = bucketSystemEnabled;
      _isLoading = false;
    });
  }

  Future<void> _loadBuckets() async {
    final buckets = await DatabaseHelper().getActiveBuckets();
    final bucketSystemEnabled = widget.initialBucketSystemEnabled ??
        await DatabaseHelper().getBucketSystemEnabled();
    if (!mounted) return;
    setState(() {
      _buckets = buckets;
      _bucketSystemEnabled = bucketSystemEnabled;
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
  void dispose() {
    _bucketSheetFeedbackTimer?.cancel();
    _transferSheetFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalPercentage = getBucketPercentageTotal(_buckets);
    final isValid = validateBucketPercentages(_buckets);
    return Scaffold(
      key: const Key('page_pos_keuangan'),
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: Text(
          'Pos Keuangan',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
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
                '${totalPercentage.toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: isValid ? AppPalette.success : AppPalette.danger,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pos Keuangan',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                key: const Key('bucket_header_controls'),
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _bucketSystemEnabled
                            ? AppPalette.primary.withValues(alpha: 0.18)
                            : AppPalette.border,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        key: const Key('bucket_toggle_control'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Mode Pos',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Switch(
                            key: const Key('bucket_system_toggle_btn'),
                            value: _bucketSystemEnabled,
                            onChanged: _isLoading
                                ? null
                                : (_) => _handleBucketSystemToggle(),
                            activeThumbColor: AppPalette.primary,
                            activeTrackColor:
                                AppPalette.primary.withValues(alpha: 0.35),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: AppPalette.textSecondary
                                .withValues(alpha: 0.35),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    key: const Key('pos_fab'),
                    onPressed: () => _showAddBucketSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      '+ Tambah Pos',
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
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _buckets.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            key: const Key('bucket_list'),
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _buckets.length,
                            itemBuilder: (_, i) =>
                                _buildBucketItem(_buckets[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() => Container(
        key: const Key('pos_loading_state'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'Memuat pos keuangan...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppPalette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  Widget _buildEmpty() => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.pie_chart_outline,
                size: 64,
                color: AppPalette.textSecondary,
              ),
              const SizedBox(height: 20),
              Text(
                'Belum ada pos keuangan',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Yuk buat pos keuangan global\nbiar alokasi uang makin rapi!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('pos_empty_add_btn'),
                onPressed: () => _showAddBucketSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: Text(
                  '+ Tambah Pos Keuangan',
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

  Future<void> _handleBucketSystemToggle() async {
    final setBucketSystemEnabled = widget.setBucketSystemEnabled ??
        DatabaseHelper().setBucketSystemEnabled;
    final previewBucketReconciliations = widget.previewBucketReconciliations ??
        DatabaseHelper().previewBucketReconciliations;
    final applyBucketReconciliations = widget.applyBucketReconciliations ??
        DatabaseHelper().applyBucketReconciliations;

    if (_bucketSystemEnabled) {
      await setBucketSystemEnabled(false);
      if (!mounted) return;
      setState(() {
        _bucketSystemEnabled = false;
      });
      await _loadBuckets();
      return;
    }

    if (!validateBucketPercentages(_buckets)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bucketConfigurationIncompleteMessage,
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    final previews = await previewBucketReconciliations();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('bucket_system_activate_dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Aktifkan Pos?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Uang tetap di dompet yang sama. Pos hanya membagi saldo dompet itu ke pos-pos miliknya.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  key: const Key('bucket_reconciliation_list'),
                  shrinkWrap: true,
                  children: previews.entries.map((entry) {
                    final wallet = _wallets.firstWhere(
                      (candidate) => candidate.id == entry.key,
                      orElse: () => Wallet(
                        id: entry.key,
                        name: 'Dompet ${entry.key}',
                        createdDate: DateTime.now(),
                        updatedDate: DateTime.now(),
                      ),
                    );
                    final preview = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wallet.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              color: AppPalette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Saldo dompet ${formatRupiah(preview.walletBalance)} | Delta ${formatRupiah(preview.delta)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: preview.canApply
                                  ? AppPalette.textSecondary
                                  : AppPalette.danger,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._buckets
                              .where((bucket) => bucket.walletId == wallet.id)
                              .map((bucket) {
                            final bucketId = bucket.id;
                            final change = bucketId == null
                                ? 0.0
                                : (preview.balanceChanges[bucketId] ?? 0.0);
                            final resultingBalance = bucketId == null
                                ? bucket.currentBalance
                                : (preview.resultingBalances[bucketId] ??
                                    bucket.currentBalance);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${bucket.name}: ${formatRupiah(bucket.currentBalance)} -> ${formatRupiah(resultingBalance)} (${change >= 0 ? '+' : ''}${formatRupiah(change)})',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppPalette.textSecondary,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: AppPalette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await applyBucketReconciliations();
                await setBucketSystemEnabled(true);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                setState(() {
                  _bucketSystemEnabled = true;
                });
                await _loadBuckets();
              } on StateError {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Salah satu dompet belum bisa disinkronkan karena hasilnya akan membuat saldo pos negatif.',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Sinkronkan & Aktifkan',
              style: GoogleFonts.poppins(color: AppPalette.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBucketItem(FinancialBucket bucket) {
    final linkedWallet =
        _wallets.where((wallet) => wallet.id == bucket.walletId);
    final walletLabel =
        linkedWallet.isEmpty ? 'Dompet belum diatur' : linkedWallet.first.name;
    final percentageText = '${bucket.allocationPercentage.toStringAsFixed(1)}%';
    final balanceText = formatRupiah(bucket.currentBalance);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(bucket.resolvedIcon, color: AppPalette.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              bucket.name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: AppPalette.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 112),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  walletLabel,
                                  key: const Key('bucket_wallet_text'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.textSecondary,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  percentageText,
                                  key: const Key('bucket_percentage_text'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.info,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(text: balanceText),
                            key: const Key('bucket_balance_text'),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.textPrimary,
                            ),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: const Key('bucket_edit_btn'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(Icons.edit_outlined, color: AppPalette.info),
                  tooltip: 'Edit Pos',
                  onPressed: () => _showAddBucketSheet(context, bucket: bucket),
                ),
                IconButton(
                  key: const Key('bucket_transfer_btn'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(Icons.swap_horiz, color: AppPalette.info),
                  tooltip: 'Transfer Saldo',
                  onPressed: () => _showTransferSheet(context, bucket),
                ),
                IconButton(
                  key: const Key('bucket_delete_btn'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppPalette.textSecondary,
                  ),
                  tooltip: 'Hapus Pos',
                  onPressed: () => _handleDelete(bucket),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDelete(FinancialBucket bucket) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('bucket_delete_dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Pos?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Pos ini hanya bisa dihapus jika saldonya sudah 0. Pindahkan dulu semua isi pos ke pos lain sebelum menghapusnya.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: AppPalette.textSecondary),
            ),
          ),
          TextButton(
            key: const Key('bucket_delete_confirm_btn'),
            onPressed: () async {
              try {
                await DatabaseHelper()
                    .removeFinancialBucketFromActive(bucket.id!);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                await _loadBuckets();
              } on StateError catch (error) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error.message.toString().contains('emptied')
                          ? 'Saldo pos harus dipindahkan dulu sampai 0 sebelum dihapus.'
                          : 'Minimal harus ada satu pos aktif yang tersisa.',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Hapus',
              style: GoogleFonts.poppins(color: AppPalette.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetDragHandle({
    required ValueChanged<DragUpdateDetails> onVerticalDragUpdate,
    required ValueChanged<DragEndDetails> onVerticalDragEnd,
    required VoidCallback onVerticalDragCancel,
  }) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onVerticalDragEnd: onVerticalDragEnd,
        onVerticalDragCancel: onVerticalDragCancel,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            key: const Key('sheet_drag_handle'),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: AppPalette.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetFeedbackBanner({
    required Key key,
    required String message,
    required Color color,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBucketSheet(BuildContext context, {FinancialBucket? bucket}) {
    final nameCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    String selectedIconKey = bucket?.iconKey ?? 'chart';
    String? sheetFeedbackMessage;
    Color sheetFeedbackColor = Colors.red;
    double sheetDragOffset = 0;
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
          void showSheetFeedback(
            String message, {
            Color backgroundColor = AppPalette.danger,
          }) {
            _bucketSheetFeedbackTimer?.cancel();
            setModal(() {
              sheetFeedbackMessage = message;
              sheetFeedbackColor = backgroundColor;
            });
            _bucketSheetFeedbackTimer = Timer(
              _sheetFeedbackAutoHideDuration,
              () {
                if (!ctx.mounted || sheetFeedbackMessage == null) return;
                setModal(() => sheetFeedbackMessage = null);
              },
            );
          }

          void clearSheetFeedback() {
            _bucketSheetFeedbackTimer?.cancel();
            if (sheetFeedbackMessage == null) return;
            setModal(() => sheetFeedbackMessage = null);
          }

          void resetSheetDragOffset() {
            if (sheetDragOffset == 0) return;
            setModal(() => sheetDragOffset = 0);
          }

          final mediaQuery = MediaQuery.of(ctx);

          return SafeArea(
            top: false,
            child: FractionallySizedBox(
              heightFactor: 0.85,
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, sheetDragOffset),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSheetDragHandle(
                          onVerticalDragUpdate: (details) {
                            final nextOffset = (sheetDragOffset +
                                    (details.primaryDelta ?? details.delta.dy))
                                .clamp(0.0, 220.0)
                                .toDouble();
                            if (nextOffset == sheetDragOffset) return;
                            setModal(() => sheetDragOffset = nextOffset);
                          },
                          onVerticalDragEnd: (details) {
                            final shouldDismiss = sheetDragOffset > 120 ||
                                (details.primaryVelocity ?? 0) > 700;
                            if (shouldDismiss) {
                              Navigator.of(ctx).pop();
                              return;
                            }
                            resetSheetDragOffset();
                          },
                          onVerticalDragCancel: resetSheetDragOffset,
                        ),
                        const SizedBox(height: 8),
                        if (sheetFeedbackMessage != null) ...[
                          _buildSheetFeedbackBanner(
                            key: const Key('bucket_sheet_feedback'),
                            message: sheetFeedbackMessage!,
                            color: sheetFeedbackColor,
                          ),
                          const SizedBox(height: 16),
                        ],
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              4,
                              0,
                              4,
                              mediaQuery.viewInsets.bottom + 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bucket == null
                                      ? 'Tambah Pos Keuangan'
                                      : 'Edit Pos Keuangan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  key: const Key('bucket_name_field'),
                                  controller: nameCtrl,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Nama pos (mis. Tabungan, Sedekah)',
                                    hintStyle: GoogleFonts.poppins(),
                                    filled: true,
                                    fillColor: AppPalette.surfaceMuted,
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
                                    fillColor: AppPalette.surfaceMuted,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Dompet Aktif',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<Wallet>(
                                  key: const Key('bucket_wallet_dropdown'),
                                  initialValue: selectedWallet,
                                  items: _wallets
                                      .map(
                                        (wallet) => DropdownMenuItem<Wallet>(
                                          value: wallet,
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
                                    fillColor: AppPalette.surfaceMuted,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Ikon Pos',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: _availableBucketIcons.entries
                                      .map((entry) {
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
                                              ? AppPalette.primary
                                                  .withValues(alpha: 0.12)
                                              : AppPalette.surfaceMuted,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppPalette.primary
                                                : AppPalette.border,
                                          ),
                                        ),
                                        child: Icon(
                                          entry.value,
                                          color: isSelected
                                              ? AppPalette.primary
                                              : AppPalette.textSecondary,
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
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const Key('bucket_save_btn'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppPalette.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                clearSheetFeedback();
                                final name = nameCtrl.text.trim();
                                final pct =
                                    double.tryParse(pctCtrl.text.trim()) ?? 0;
                                if (name.isEmpty) {
                                  showSheetFeedback(
                                    'Nama pos tidak boleh kosong.',
                                  );
                                  return;
                                }
                                if (pct <= 0) {
                                  showSheetFeedback(
                                    'Persentase harus lebih besar dari 0.',
                                  );
                                  return;
                                }
                                if (selectedWallet == null) {
                                  showSheetFeedback(
                                    _wallets.isEmpty
                                        ? 'Buat dompet aktif dulu sebelum membuat pos.'
                                        : 'Pilih tepat satu dompet aktif untuk pos ini.',
                                  );
                                  return;
                                }

                                final draftBuckets = [
                                  ..._buckets.where(
                                    (item) => item.id != bucket?.id,
                                  ),
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
                                  showSheetFeedback(
                                    'Total persentase semua pos tidak boleh lebih dari 100%.',
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

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                await _loadBuckets();
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
    ).whenComplete(() {
      _bucketSheetFeedbackTimer?.cancel();
      _bucketSheetFeedbackTimer = null;
    });
  }

  void _showTransferSheet(BuildContext context, FinancialBucket from) {
    final amountCtrl = TextEditingController();
    FinancialBucket? selectedTarget;
    String? sheetFeedbackMessage;
    Color sheetFeedbackColor = Colors.red;
    double sheetDragOffset = 0;

    final targets = _buckets.where((bucket) => bucket.id != from.id).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tidak ada pos tujuan lain',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }
    selectedTarget = targets.first;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          void showSheetFeedback(
            String message, {
            Color backgroundColor = AppPalette.danger,
          }) {
            _transferSheetFeedbackTimer?.cancel();
            setModal(() {
              sheetFeedbackMessage = message;
              sheetFeedbackColor = backgroundColor;
            });
            _transferSheetFeedbackTimer = Timer(
              _sheetFeedbackAutoHideDuration,
              () {
                if (!ctx.mounted || sheetFeedbackMessage == null) return;
                setModal(() => sheetFeedbackMessage = null);
              },
            );
          }

          void clearSheetFeedback() {
            _transferSheetFeedbackTimer?.cancel();
            if (sheetFeedbackMessage == null) return;
            setModal(() => sheetFeedbackMessage = null);
          }

          void resetSheetDragOffset() {
            if (sheetDragOffset == 0) return;
            setModal(() => sheetDragOffset = 0);
          }

          return SafeArea(
            top: false,
            child: FractionallySizedBox(
              heightFactor: 0.72,
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, sheetDragOffset),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSheetDragHandle(
                          onVerticalDragUpdate: (details) {
                            final nextOffset = (sheetDragOffset +
                                    (details.primaryDelta ?? details.delta.dy))
                                .clamp(0.0, 220.0)
                                .toDouble();
                            if (nextOffset == sheetDragOffset) return;
                            setModal(() => sheetDragOffset = nextOffset);
                          },
                          onVerticalDragEnd: (details) {
                            final shouldDismiss = sheetDragOffset > 120 ||
                                (details.primaryVelocity ?? 0) > 700;
                            if (shouldDismiss) {
                              Navigator.of(ctx).pop();
                              return;
                            }
                            resetSheetDragOffset();
                          },
                          onVerticalDragCancel: resetSheetDragOffset,
                        ),
                        const SizedBox(height: 8),
                        if (sheetFeedbackMessage != null) ...[
                          _buildSheetFeedbackBanner(
                            key: const Key('transfer_sheet_feedback'),
                            message: sheetFeedbackMessage!,
                            color: sheetFeedbackColor,
                          ),
                          const SizedBox(height: 16),
                        ],
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: 4,
                              right: 4,
                              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transfer dari ${from.name}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<FinancialBucket>(
                                  key: const Key('transfer_target_dropdown'),
                                  initialValue: selectedTarget,
                                  items: targets
                                      .map(
                                        (bucket) => DropdownMenuItem(
                                          value: bucket,
                                          child: Text(bucket.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setModal(() => selectedTarget = value),
                                  decoration: InputDecoration(
                                    labelText: 'Pos tujuan',
                                    filled: true,
                                    fillColor: AppPalette.surfaceMuted,
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
                                  inputFormatters: [CurrencyInputFormatter()],
                                  decoration: InputDecoration(
                                    hintText: 'Nominal transfer',
                                    hintStyle: GoogleFonts.poppins(),
                                    prefixText: 'Rp ',
                                    prefixStyle: GoogleFonts.poppins(
                                      color: AppPalette.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    filled: true,
                                    fillColor: AppPalette.surfaceMuted,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const Key('transfer_confirm_btn'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppPalette.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                clearSheetFeedback();
                                final amount = tryParseCurrencyInput(
                                        amountCtrl.text.trim()) ??
                                    0;
                                if (amount <= 0) {
                                  showSheetFeedback(
                                    'Nominal transfer harus lebih besar dari 0.',
                                  );
                                  return;
                                }
                                if (selectedTarget == null) {
                                  showSheetFeedback(
                                    'Pilih pos tujuan terlebih dahulu.',
                                  );
                                  return;
                                }

                                try {
                                  await DatabaseHelper().executeBucketTransfer(
                                    fromBucketId: from.id!,
                                    toBucketId: selectedTarget!.id!,
                                    amount: amount,
                                    transferDate: DateTime.now(),
                                  );
                                } on InsufficientBalanceException {
                                  if (!ctx.mounted) return;
                                  showSheetFeedback(
                                    _insufficientBalanceMessage,
                                  );
                                  return;
                                }

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (!mounted) return;
                                await _loadBuckets();
                              },
                              child: Text(
                                'Transfer',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
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
            ),
          );
        },
      ),
    ).whenComplete(() {
      _transferSheetFeedbackTimer?.cancel();
      _transferSheetFeedbackTimer = null;
    });
  }
}
