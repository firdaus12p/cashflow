import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/icons/app_icons.dart';
import '../../../data/database/database_helper.dart';
import '../models/wallet.dart';

class DompetPage extends StatefulWidget {
  const DompetPage({
    super.key,
    this.initialWallets,
    @visibleForTesting this.transactionCountForWallet,
    @visibleForTesting this.deleteWalletById,
    @visibleForTesting this.archiveWalletById,
  });

  final List<Wallet>? initialWallets;
  final Future<int> Function(Wallet)? transactionCountForWallet;
  final Future<void> Function(int walletId)? deleteWalletById;
  final Future<void> Function(int walletId)? archiveWalletById;

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

  Future<void> _refreshWalletsAfterMutation(int walletId) async {
    if (widget.initialWallets != null) {
      if (!mounted) return;
      setState(() {
        _wallets = _wallets.where((wallet) => wallet.id != walletId).toList();
      });
      return;
    }

    await _loadWallets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('page_dompet'),
      backgroundColor: AppPalette.background,
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
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dompet',
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
                    key: const Key('dompet_fab'),
                    onPressed: () => _showAddWalletSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      '+ Tambah Dompet',
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
                    ? _buildLoadingWallets()
                    : _wallets.isEmpty
                        ? _buildEmptyWallets()
                        : ListView.builder(
                            key: const Key('wallet_list'),
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _wallets.length,
                            itemBuilder: (_, i) => _buildWalletItem(_wallets[i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWallets() {
    return Container(
      key: const Key('dompet_loading_state'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          'Memuat dompet...',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppPalette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWallets() {
    return Container(
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
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: AppPalette.textSecondary,
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada dompet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yuk tambahkan dompet baru\nbiar keuangan kamu makin rapi!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('dompet_empty_add_btn'),
              onPressed: () => _showAddWalletSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(
                '+ Tambah Dompet',
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

  Widget _buildWalletItem(Wallet wallet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppPalette.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            resolveWalletIcon(wallet.iconKey, wallet.name),
            color: AppPalette.primary,
          ),
        ),
        title: Text(
          wallet.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('wallet_edit_btn'),
              icon: const Icon(Icons.edit_outlined, color: AppPalette.info),
              tooltip: 'Edit',
              onPressed: () => _showAddWalletSheet(context, wallet: wallet),
            ),
            IconButton(
              key: const Key('wallet_archive_btn'),
              icon: const Icon(
                Icons.archive_outlined,
                color: AppPalette.textSecondary,
              ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Arsipkan Dompet?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"${wallet.name}" masih dipakai di $count catatan historis. '
            'Arsip direkomendasikan agar riwayat dan cicilan tetap konsisten.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(color: AppPalette.textSecondary),
              ),
            ),
            TextButton(
              key: const Key('wallet_remove_btn'),
              onPressed: () async {
                Navigator.pop(context);
                await (widget.deleteWalletById ??
                    (int walletId) => DatabaseHelper().deleteWallet(walletId))(
                  wallet.id!,
                );
                await _refreshWalletsAfterMutation(wallet.id!);
              },
              child: Text(
                'Keluarkan dari daftar aktif',
                style: GoogleFonts.poppins(color: AppPalette.danger),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await (widget.archiveWalletById ??
                    (int walletId) => DatabaseHelper().archiveWallet(walletId))(
                  wallet.id!,
                );
                await _refreshWalletsAfterMutation(wallet.id!);
              },
              child: Text(
                'Arsipkan',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      await (widget.deleteWalletById ??
          (int walletId) => DatabaseHelper().deleteWallet(walletId))(
        wallet.id!,
      );
      await _refreshWalletsAfterMutation(wallet.id!);
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
          decoration: const BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
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
                        color: AppPalette.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    wallet == null ? 'Tambah Dompet' : 'Edit Dompet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('wallet_name_field'),
                    controller: nameCtrl,
                    autofocus: wallet == null,
                    decoration: InputDecoration(
                      hintText: 'Nama dompet',
                      hintStyle: GoogleFonts.poppins(),
                      filled: true,
                      fillColor: AppPalette.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ikon Dompet',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableWalletIcons.entries.map((entry) {
                      final isSelected = selectedIconKey == entry.key;
                      return GestureDetector(
                        key: Key('wallet_icon_${entry.key}'),
                        onTap: () =>
                            setModal(() => selectedIconKey = entry.key),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppPalette.primary.withValues(alpha: 0.12)
                                : AppPalette.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('wallet_save_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final now = DateTime.now();
                        if (wallet == null) {
                          await DatabaseHelper().insertWallet(
                            Wallet(
                              name: name,
                              iconKey: selectedIconKey,
                              createdDate: now,
                              updatedDate: now,
                            ),
                          );
                        } else {
                          await DatabaseHelper().updateWallet(
                            Wallet(
                              id: wallet.id,
                              name: name,
                              iconKey: selectedIconKey,
                              color: wallet.color,
                              isArchived: wallet.isArchived,
                              createdDate: wallet.createdDate,
                              updatedDate: now,
                            ),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadWallets();
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
        ),
      ),
    );
  }
}
