import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hisab_pro/core/logging/app_logger.dart';

class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  static const String _loanChannelId = 'hisab_loans_channel';
  static const String _loanChannelName = 'Loan & Repayment Reminders';
  static const String _budgetChannelId = 'hisab_budget_channel';
  static const String _budgetChannelName = 'Budget Alerts';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          AppLogger.info('Notification tapped: ${response.payload}');
        },
      );

      _isInitialized = true;
      AppLogger.info('ReminderService initialized successfully.');
    } catch (e) {
      AppLogger.warning('ReminderService initialization skipped or failed: $e');
    }
  }

  /// Displays an immediate budget warning notification when threshold is exceeded.
  Future<void> showBudgetThresholdNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const androidDetails = AndroidNotificationDetails(
        _budgetChannelId,
        _budgetChannelName,
        channelDescription: 'Alerts when monthly budget utilization exceeds configured limits',
        importance: Importance.high,
        priority: Priority.high,
      );
      const darwinDetails = DarwinNotificationDetails();
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      AppLogger.warning('Failed to show budget threshold notification: $e');
    }
  }

  /// Displays or schedules a loan repayment reminder.
  Future<void> showLoanReminderNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const androidDetails = AndroidNotificationDetails(
        _loanChannelId,
        _loanChannelName,
        channelDescription: 'Notifications for upcoming loan receivables and payables due dates',
        importance: Importance.high,
        priority: Priority.high,
      );
      const darwinDetails = DarwinNotificationDetails();
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      AppLogger.warning('Failed to show loan reminder notification: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      AppLogger.warning('Failed to cancel notification $id: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      AppLogger.warning('Failed to cancel all notifications: $e');
    }
  }
}

