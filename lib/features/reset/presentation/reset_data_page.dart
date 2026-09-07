import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../notifications/services/reminder_scheduler.dart';

/// Full-screen page that explains the scope of a full data reset and lets the
/// user confirm the irreversible action.
///
/// [resetHandler] and [onResetComplete] are injectable for widget testing.
/// By default, the scheduler coordinates DB reset and notification cleanup.
class ResetDataPage extends StatefulWidget {
  const ResetDataPage({
    super.key,
    this.resetHandler,
    this.onResetComplete,
  });

  /// Override for testing — replaces the real DB + notification reset.
  final Future<void> Function()? resetHandler;

  /// Called after the DB commits, even if notification cleanup fails.
  final VoidCallback? onResetComplete;

  @override
  State<ResetDataPage> createState() => _ResetDataPageState();
}

class _ResetDataPageState extends State<ResetDataPage> {
  bool _isResetting = false;

  static const _domains = [
    'Transaksi pemasukan & pengeluaran',
    'Target tabungan',
    'Wishlist belanja',
    'Badge & pencapaian',
    'Dompet (dompet kustom akan dihapus)',
    'Hutang & piutang beserta cicilan',
    'Pos keuangan & histori alokasi',
    'Preferensi aplikasi',
    'Pengingat lokal yang terjadwal',
  ];

  Future<void> _doReset() async {
    if (widget.resetHandler != null) {
      await widget.resetHandler!();
    } else {
      await ReminderScheduler().resetAllData();
    }
  }

  Future<void> _onCtaTapped() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        key: const Key('reset_confirm_dialog'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Semua Data?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Seluruh data lokal akan dihapus secara permanen dan tidak bisa dikembalikan. '
          'Aplikasi akan kembali ke kondisi awal.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            key: const Key('reset_dialog_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(color: AppPalette.textSecondary),
            ),
          ),
          TextButton(
            key: const Key('reset_dialog_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Reset',
              style: GoogleFonts.poppins(
                color: AppPalette.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final onResetComplete = widget.onResetComplete;
    var cleanupFailed = false;
    setState(() => _isResetting = true);
    try {
      await _doReset();
    } on ReminderCleanupException {
      cleanupFailed = true;
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Reset gagal. Silakan coba lagi.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: AppPalette.danger,
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }

    // Use the captured messenger: the shell callback may pop this route.
    if (cleanupFailed && messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Data sudah direset, tetapi pengingat terjadwal gagal dibatalkan.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppPalette.danger,
        ),
      );
    }
    onResetComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('page_reset_data'),
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: Text(
          'Reset Data',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildWarningCard(),
            const SizedBox(height: 20),
            _buildDomainList(),
            const SizedBox(height: 32),
            _buildCtaButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.danger.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppPalette.danger, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aksi ini permanen',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppPalette.danger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seluruh data lokal akan dihapus dan tidak bisa dikembalikan. '
                  'Aplikasi akan kembali ke kondisi awal seperti baru dipakai pertama kali.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppPalette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data yang akan dihapus:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._domains.map(
            (domain) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.remove_circle_outline,
                      size: 14, color: AppPalette.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      domain,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppPalette.textPrimary,
                      ),
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

  Widget _buildCtaButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: const Key('reset_data_cta_button'),
        onPressed: _isResetting ? null : _onCtaTapped,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.danger,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isResetting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Reset Semua Data',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }
}
