import 'package:api_client/api_client.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:printers_repository/printers_repository.dart';

/// Settles the jobs the app was closed during.
///
/// A print that was on its way when the app closed would otherwise be left
/// "Printing" for ever. The printer is asked what became of it, and the
/// answer goes on the job's record. A job is only ever marked done when the
/// printer says so: one it no longer knows of is marked as unknown.
class JobRecovery {
  new({
    required this._jobsRepository,
    required this._printersRepository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final JobsRepository _jobsRepository;
  final PrintersRepository _printersRepository;
  final DateTime Function() _now;

  /// How long a printer that cannot be reached is waited for before its
  /// job is given up as unknown.
  static const Duration patience = Duration(hours: 24);

  bool _recovering = false;

  /// Settles what can be settled now. What cannot, because the printer is
  /// out of reach or still printing, is left for the next time. Never
  /// throws.
  Future<void> recover(String organizationId) async {
    if (_recovering) return;
    _recovering = true;
    try {
      for (final job in await _jobsRepository.interrupted(organizationId)) {
        final update = await _fateOf(organizationId, job);
        if (update != null) {
          await _jobsRepository.report(organizationId, job.jobId, update);
        }
      }
    } finally {
      _recovering = false;
    }
  }

  /// How [job] ended, or null when that cannot be known yet.
  Future<JobUpdate?> _fateOf(String organizationId, RunningJob job) async {
    // A scan lives on the phone: closed part way, its pages are gone.
    if (job.kind != 'print') {
      return const JobUpdate(status: 'failed', errorCode: 'scan.interrupted');
    }
    final lost = JobUpdate(
      status: 'failed',
      errorCode: job.printerJobRef == null
          ? 'print.interrupted'
          : 'print.outcome_unknown',
    );

    final PrinterRead printer;
    try {
      printer = await _printersRepository.get(
        organizationId: organizationId,
        printerId: job.printerId,
      );
    } on ApiUnreachable {
      return null;
    } on ApiProblem {
      // The printer is no longer in the workspace: there is nobody to ask.
      return lost;
    }

    final fate = await _printersRepository.fate(
      organizationId: organizationId,
      printer: printer,
      title: job.title ?? '',
      // The same short code the print was sent with.
      reference: job.jobId.substring(0, 8),
      printerJobRef: job.printerJobRef,
    );
    return switch (fate?.stage) {
      PrintStage.completed => const JobUpdate(status: 'completed'),
      PrintStage.cancelled => const JobUpdate(status: 'cancelled'),
      PrintStage.failed || PrintStage.unknown => JobUpdate(
        status: 'failed',
        errorCode: fate!.errorCode,
        errorMessage: fate.errorMessage,
      ),
      // The printer cannot be asked. It is tried again, for a day.
      null => _now().toUtc().difference(job.startedAt) > patience ? lost : null,
      // Still on the printer.
      _ => null,
    };
  }
}
