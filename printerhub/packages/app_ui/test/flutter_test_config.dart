import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden files are compared with a small tolerance, because anti-aliasing
/// differs by a few pixels between a developer's Mac and CI's Linux. A token
/// or layout change moves far more than this.
const double _tolerance = 0.005;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(
      Uri.parse('${current.basedir}placeholder_test.dart'),
    );
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  new(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
