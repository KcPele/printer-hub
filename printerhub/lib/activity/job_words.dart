import 'package:app_ui/app_ui.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/print/print_words.dart';

/// The words the app uses for a job in the history: what it was, where it
/// has got to, and why it stopped. One place, so the list and the job's own
/// page read the same.
abstract final class JobWords {
  /// The name a job goes by: its document, or what kind of job it was.
  static String title(AppLocalizations l10n, Job job) {
    final title = job.title;
    if (title != null && title.isNotEmpty) return title;
    return switch (job.kind) {
      'scan' => l10n.jobUntitledScan,
      'copy' => l10n.jobUntitledCopy,
      _ => l10n.jobUntitledPrint,
    };
  }

  static String kind(AppLocalizations l10n, Job job) {
    return switch (job.kind) {
      'scan' => l10n.jobKindScan,
      'copy' => l10n.jobKindCopy,
      _ => l10n.jobKindPrint,
    };
  }

  static IconData icon(Job job) {
    return switch (job.kind) {
      'scan' => Icons.document_scanner_outlined,
      'copy' => Icons.copy_outlined,
      _ => Icons.print_outlined,
    };
  }

  /// A step in a job's life, in a word or two.
  static String step(AppLocalizations l10n, String status) {
    return switch (status) {
      'processing' => l10n.jobStatusProcessing,
      'printing' => l10n.jobStatusPrinting,
      'scanning' => l10n.jobStatusScanning,
      'completed' => l10n.jobStatusCompleted,
      'failed' => l10n.jobStatusFailed,
      'cancelled' => l10n.jobStatusCancelled,
      _ => l10n.jobStatusQueued,
    };
  }

  /// Where a job has got to, and how that should look.
  static ({AppStatus status, String label}) standing(
    AppLocalizations l10n,
    Job job,
  ) {
    return (
      status: switch (job.status) {
        'completed' => AppStatus.success,
        'failed' => AppStatus.error,
        'cancelled' => AppStatus.neutral,
        _ => AppStatus.info,
      },
      label: step(l10n, job.status),
    );
  }

  /// Why a job or one of its steps failed. Null when it did not.
  static String? failure(
    AppLocalizations l10n, {
    required String? code,
    String? said,
  }) {
    if (code == null && said == null) return null;
    return PrintWords.failureOf(l10n, code: code, said: said);
  }

  /// A moment as a date and a time of day, in the phone's own way.
  static String when(BuildContext context, DateTime moment) {
    final local = moment.toLocal();
    final words = MaterialLocalizations.of(context);
    return context.l10n.jobWhen(
      words.formatMediumDate(local),
      words.formatTimeOfDay(TimeOfDay.fromDateTime(local)),
    );
  }
}
