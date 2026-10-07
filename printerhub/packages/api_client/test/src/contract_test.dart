import 'dart:convert';
import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:test/test.dart';

/// The generated models are not covered line by line. These tests pin the
/// parts the app leans on hardest: the job union and forward-compatible
/// enums.
void main() {
  // Samples written from the contract by tool/make_fixtures.py.
  Map<String, dynamic> sample(String name) {
    final file = File('test/fixtures/$name.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('JobRead', () {
    test('decodes each kind of job by its type', () {
      expect(JobRead.fromJson(sample('PrintJobRead')), isA<PrintJobRead>());
      expect(JobRead.fromJson(sample('ScanJobRead')), isA<ScanJobRead>());
      expect(JobRead.fromJson(sample('CopyJobRead')), isA<CopyJobRead>());
    });

    test('keeps the fields of the job', () {
      final job = JobRead.fromJson(sample('PrintJobRead')) as PrintJobRead;

      expect(job.status, JobStatus.queued);
      expect(job.submittedAt, DateTime.utc(2026, 10, 7, 10));
      expect(job.settings.copies, 1);
    });

    test('encodes back to what it decoded', () {
      for (final name in ['PrintJobRead', 'ScanJobRead', 'CopyJobRead']) {
        final json = sample(name);
        final encoded = jsonDecode(
          jsonEncode(JobRead.fromJson(json).toJson()),
        ) as Map<String, dynamic>;

        // Fields that are null are left out when encoding.
        final settings = Map<String, dynamic>.of(
          json['settings'] as Map<String, dynamic>,
        )..removeWhere((key, value) => value == null);
        expect(encoded['settings'], settings);
        expect(encoded['execution_mode'], json['execution_mode']);
        expect(encoded['submitted_at'], '2026-10-07T10:00:00.000Z');
      }
    });

    test('rejects a kind of job it does not know', () {
      final fax = sample('PrintJobRead')..['type'] = 'fax';

      expect(() => JobRead.fromJson(fax), throwsFormatException);
    });
  });

  group('JobCreate', () {
    test('encodes a request the API accepts', () {
      const printerId = '0198c0de-0000-7000-8000-00000000000c';
      final json = jsonDecode(
        jsonEncode(
          JobCreatePrintJobCreate(
            printerId: printerId,
            type: 'print',
            title: 'Quarterly report',
            settings: const PrintSettingsInput(copies: 2),
            submittedAt: DateTime.utc(2026, 10, 7, 10),
            executionMode: ExecutionMode.local,
            connectionId: null,
            documentId: null,
            id: null,
            pageCount: null,
          ).toJson(),
        ),
      ) as Map<String, dynamic>;

      expect(json['type'], 'print');
      expect(json['printer_id'], printerId);
      expect(json['execution_mode'], 'local');
      expect(json['submitted_at'], '2026-10-07T10:00:00.000Z');
      expect((json['settings'] as Map<String, dynamic>)['copies'], 2);
      expect((json['settings'] as Map<String, dynamic>)['color_mode'], 'auto');
    });
  });

  group('enums', () {
    test('read a value added to the API later as unknown', () {
      expect(JobStatus.fromJson('printing'), JobStatus.printing);
      expect(JobStatus.fromJson('collating'), JobStatus.$unknown);
    });
  });
}
