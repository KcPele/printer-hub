import 'package:api_client/testing.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobs_repository/jobs_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/activity/activity.dart';
import 'package:printerhub/l10n/l10n.dart';

import '../helpers/helpers.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Job job({String type = 'print', String status = 'queued', String? title}) {
    return Job.fromJson(
      jobBody(type: type, status: status, title: title).cast(),
    );
  }

  test('a job goes by its document, or by what kind of job it was', () {
    expect(JobWords.title(l10n, job(title: 'Report.pdf')), 'Report.pdf');
    expect(JobWords.title(l10n, job(title: '')), 'A print');
    expect(JobWords.title(l10n, job()), 'A print');
    expect(JobWords.title(l10n, job(type: 'scan')), 'A scan');
    expect(JobWords.title(l10n, job(type: 'copy')), 'A copy');
  });

  test('each kind has a name and a picture', () {
    expect(JobWords.kind(l10n, job()), 'Print');
    expect(JobWords.kind(l10n, job(type: 'scan')), 'Scan');
    expect(JobWords.kind(l10n, job(type: 'copy')), 'Copy');
    expect(JobWords.icon(job()), Icons.print_outlined);
    expect(JobWords.icon(job(type: 'scan')), Icons.document_scanner_outlined);
    expect(JobWords.icon(job(type: 'copy')), Icons.copy_outlined);
  });

  test('each step has a word', () {
    expect(
      [
        for (final status in [
          'queued',
          'processing',
          'printing',
          'scanning',
          'completed',
          'failed',
          'cancelled',
        ])
          JobWords.step(l10n, status),
      ],
      [
        'Waiting',
        'Getting ready',
        'Printing',
        'Scanning',
        'Done',
        'Failed',
        'Cancelled',
      ],
    );
  });

  test('where a job stands has a colour', () {
    AppStatus of(String status) =>
        JobWords.standing(l10n, job(status: status)).status;

    expect(of('completed'), AppStatus.success);
    expect(of('failed'), AppStatus.error);
    expect(of('cancelled'), AppStatus.neutral);
    expect(of('printing'), AppStatus.info);
    expect(JobWords.standing(l10n, job(status: 'printing')).label, 'Printing');
  });

  test('a failure is worded from its code, or from what was said', () {
    expect(JobWords.failure(l10n, code: null), isNull);
    expect(
      JobWords.failure(l10n, code: 'print.unreachable'),
      l10n.printFailedUnreachable,
    );
    expect(
      JobWords.failure(l10n, code: null, said: 'Out of memory'),
      l10n.printFailedRefusedWhy('Out of memory'),
    );
  });

  testWidgets('a moment is a date and a time of day', (tester) async {
    late String words;
    await tester.pumpApp(
      Builder(
        builder: (context) {
          words = JobWords.when(context, DateTime(2026, 10, 7, 14, 5));
          return const SizedBox();
        },
      ),
    );

    expect(words, 'Wed, Oct 7 at 2:05 PM');
  });
}
