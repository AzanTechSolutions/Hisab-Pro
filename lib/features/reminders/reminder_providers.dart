import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/features/reminders/data/reminder_service.dart';

final reminderServiceProvider = Provider<ReminderService>((ref) {
  final service = ReminderService();
  service.initialize();
  return service;
});

