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
    final preferences = await _dbHelper.getReminderPreferences();
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _isLoading = false;
    });
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() => _isSaving = true);
    try {
      var permissionGranted = true;
      if (value) {
        permissionGranted = await LocalNotificationService.instance
            .requestPermissionsIfNeeded();
      }
      if (!permissionGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Izin notifikasi belum diberikan.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppPalette.danger,
          ),
        );
        return;
      }

      await _dbHelper.setReminderEnabled(value);
      await _scheduler.rescheduleForTonight();
      await widget.onPreferencesChanged?.call();
      await _loadPreferences();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

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
          ? const SizedBox.shrink()
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
                          color: Colors.white70,
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
                    activeColor: AppPalette.primary,
                    title: Text(
                      'Aktifkan reminder malam',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Kalau ada hutang aktif yang lewat jatuh tempo, reminder hutang menggantikan reminder umum dan membuka halaman Hutang/Piutang saat diketuk.',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
