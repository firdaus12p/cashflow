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
    @visibleForTesting this.bucketBalanceOverride,
  });

  final List<FinancialBucket>? initialBuckets;
  final List<Wallet>? initialWallets;
  final Map<int, double>? bucketBalanceOverride;

  @override
  State<PosKeuanganPage> createState() => _PosKeuanganPageState();
}

class _PosKeuanganPageState extends State<PosKeuanganPage> {
  late List<FinancialBucket> _buckets;
  late List<Wallet> _wallets;
  bool _isLoading = false;
  Timer? _bucketSheetFeedbackTimer;
  Timer? _transferSheetFeedbackTimer;

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
  void dispose() {
    _bucketSheetFeedbackTimer?.cancel();
    _transferSheetFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                '${getBucketPercentageTotal(_buckets).toStringAsFixed(0)}%',
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
        backgroundColor: AppPalette.primary,
        onPressed: () => _showAddBucketSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: AppPalette.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada pos keuangan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + untuk membuat pos keuangan global',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppPalette.textSecondary,
              ),
            ),
          ],
        ),
      );

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
                  key: const Key('bucket_archive_btn'),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  icon: const Icon(
                    Icons.archive_outlined,
                    color: AppPalette.textSecondary,
                  ),
                  tooltip: 'Arsipkan',
                  onPressed: () => _handleArchive(bucket),
                ),
              ],
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
                                  value: selectedWallet,
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
                                _loadBuckets();
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
                                  value: selectedTarget,
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
                                _loadBuckets();
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
