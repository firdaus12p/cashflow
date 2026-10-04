import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/database/database_helper.dart';
import '../models/reminder_preferences.dart';
import '../services/local_notification_service.dart';
import '../services/reminder_scheduler.dart';

class PengingatPage extends StatefulWidget {
  const PengingatPage({
    super.key,
    this.onPreferencesChanged,
    this.initialPreferences,
    this.isReminderSupported,
  });

  final Future<void> Function()? onPreferencesChanged;
  final ReminderPreferences? initialPreferences;
  final bool? isReminderSupported;

  @override
  State<PengingatPage> createState() => _PengingatPageState();
}

class _PengingatPageState extends State<PengingatPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late final ReminderScheduler _scheduler;
  ReminderPreferences _preferences = const ReminderPreferences();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _loadFailed = false;

  bool get _isReminderSupported =>
      widget.isReminderSupported ??
      LocalNotificationService.instance.supportsScheduledNotifications;

  @override
  void initState() {
    super.initState();
    _scheduler = ReminderScheduler(databaseHelper: _dbHelper);
    final initialPreferences = widget.initialPreferences;
    if (initialPreferences != null) {
      _preferences = initialPreferences;
      _isLoading = false;
      return;
    }
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await _dbHelper.getReminderPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _toggleReminder(bool value) async {
    if (_isSaving || !mounted) return;
    setState(() => _isSaving = true);
    var preferenceSaved = false;
    String? failureMessage;
    try {
      var permissionGranted = true;
      if (value) {
        permissionGranted = await LocalNotificationService.instance
            .requestPermissionsIfNeeded();
      }
      if (!permissionGranted) {
        failureMessage = 'Izin notifikasi belum diberikan.';
      } else if (mounted) {
        await _dbHelper.setReminderEnabled(value);
        preferenceSaved = true;
        await _scheduler.rescheduleForTonight();
        if (mounted) await widget.onPreferencesChanged?.call();
      }
    } catch (_) {
      failureMessage = preferenceSaved
          ? 'Pengaturan tersimpan, tetapi jadwal pengingat gagal diperbarui. Buka kembali aplikasi untuk mencoba lagi.'
          : 'Pengaturan pengingat gagal disimpan. Coba lagi.';
    } finally {
      await _loadPreferences();
      if (mounted) {
        setState(() => _isSaving = false);
        if (failureMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failureMessage, style: GoogleFonts.poppins()),
              backgroundColor: AppPalette.danger,
            ),
          );
        }
      }
    }
  }

  Widget _buildLoadError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pengaturan pengingat gagal dimuat.'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadPreferences();
                },
                child: const Text('Muat ulang pengaturan'),
              ),
            ],
          ),
        ),
      );

  Widget _buildLoadingState() => Center(
        key: const Key('pengingat_loading_state'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppPalette.primary),
              const SizedBox(height: 16),
              Text(
                'Memuat pengingat...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppPalette.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('page_pengingat'),
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: Text(
          'Pengingat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _loadFailed
              ? _buildLoadError()
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppPalette.heroGradient,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengingat malam',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'cashflow akan mengingatkan kamu pukul 22:00 bila malam itu kamu belum sempat membuka aplikasi atau mencatat keuangan.',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: SwitchListTile(
                        key: const Key('reminder_enabled_switch'),
                        value: _preferences.isEnabled,
                        onChanged: !_isReminderSupported || _isSaving
                            ? null
                            : _toggleReminder,
                        activeThumbColor: AppPalette.primary,
                        title: Text(
                          'Aktifkan reminder malam',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _isReminderSupported
                              ? 'Pengingat umum jam 22:00. Tidak dikirim kalau app sudah dibuka sejak jam 20:00 atau kamu sudah mencatat keuangan hari itu.'
                              : 'Reminder malam belum didukung penuh di platform ini.',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.schedule_rounded,
                            color: AppPalette.primary),
                        title: Text(
                          'Jam reminder',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '22:00 setiap malam',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.nights_stay_outlined,
                            color: AppPalette.primary),
                        title: Text(
                          'Ambang malam',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Kalau app sudah dibuka sejak 20:00, reminder umum malam itu dibatalkan.',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded,
                            color: AppPalette.danger),
                        title: Text(
                          'Prioritas hutang overdue',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Kalau ada hutang aktif yang lewat jatuh tempo, reminder hutang menggantikan reminder umum dan membuka halaman Hutang/Piutang saat diketuk.',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Jadwal mencakup 6 atau 7 malam ke depan, tergantung waktu aplikasi dibuka. '
                        'Buka aplikasi lagi sebelum jadwal habis untuk memperpanjang pengingat. '
                        'Jika aplikasi tidak dibuka, pengingat berhenti setelah malam terakhir yang terjadwal.',
                        key: const Key('reminder_schedule_horizon'),
                        style:
                            GoogleFonts.poppins(color: AppPalette.textPrimary),
                      ),
                    ),
                  ],
                ),
    );
  }
}
