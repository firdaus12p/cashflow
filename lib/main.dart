import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/notifications/services/local_notification_service.dart';
import 'features/home/presentation/main_screen.dart';

export 'app/app.dart';
export 'core/constants/app_constants.dart';
export 'core/formatters/currency_formatters.dart';
export 'core/icons/app_icons.dart';
export 'data/database/database_helper.dart';
export 'features/badges/models/user_badge.dart';
export 'features/buckets/helpers/bucket_helpers.dart';
export 'features/buckets/models/bucket_models.dart';
export 'features/buckets/presentation/pos_keuangan_page.dart';
export 'features/debts/models/debt_models.dart';
export 'features/debts/presentation/debt_pages.dart';
export 'features/goals/models/saving_goal.dart';
export 'features/home/helpers/home_helpers.dart';
export 'features/home/presentation/main_screen.dart';
export 'features/statistics/models/chart_series_data.dart';
export 'features/transactions/models/transaction.dart';
export 'features/wallets/models/wallet.dart';
export 'features/wallets/presentation/dompet_page.dart';
export 'features/wishlist/models/wishlist_item.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final launchPayload = await LocalNotificationService.instance.initialize();
  runApp(
      CashflowApp(home: MainScreen(initialNotificationPayload: launchPayload)));
}
