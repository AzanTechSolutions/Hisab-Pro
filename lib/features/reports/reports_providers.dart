import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/features/reports/data/reports_repository.dart';
import 'package:hisab_pro/features/reports/domain/report_data.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return ReportsRepository(databaseService: dbService);
});

enum ReportTimeRange {
  thisMonth,
  lastThreeMonths,
  thisYear,
}

final reportTimeRangeProvider = StateProvider<ReportTimeRange>((ref) {
  return ReportTimeRange.thisMonth;
});

/// Loads financial report for current user based on selected time range.
final activeReportProvider = FutureProvider<FinancialSummaryReport?>((ref) async {
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return null;
  final range = ref.watch(reportTimeRangeProvider);
  final repo = ref.watch(reportsRepositoryProvider);

  final now = DateTime.now();
  int start;
  int end = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

  switch (range) {
    case ReportTimeRange.thisMonth:
      start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      break;
    case ReportTimeRange.lastThreeMonths:
      start = DateTime(now.year, now.month - 2, 1).millisecondsSinceEpoch;
      break;
    case ReportTimeRange.thisYear:
      start = DateTime(now.year, 1, 1).millisecondsSinceEpoch;
      break;
  }

  return repo.generateReport(activeProfile.id, startDate: start, endDate: end);
});

