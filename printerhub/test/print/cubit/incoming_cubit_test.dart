import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/print/print.dart';

import '../../helpers/helpers.dart';

void main() {
  group('IncomingCubit', () {
    late FakeIncomingDocuments otherApps;
    late IncomingCubit cubit;

    setUp(() {
      otherApps = FakeIncomingDocuments();
      cubit = IncomingCubit(incoming: otherApps);
    });
    tearDown(() => cubit.close());

    test('starts with nothing waiting', () {
      expect(cubit.state, isNull);
    });

    test('holds a document another app hands over', () async {
      otherApps.open(pickedPdf(name: 'Invoice.pdf'));
      await pumpEventQueue();

      expect(cubit.state?.name, 'Invoice.pdf');
    });

    test('keeps the latest when a second arrives first', () async {
      otherApps
        ..open(pickedPdf(name: 'First.pdf'))
        ..open(pickedPdf(name: 'Second.pdf'));
      await pumpEventQueue();

      expect(cubit.state?.name, 'Second.pdf');
    });

    test('does not offer a kind of file the app cannot print', () async {
      otherApps.open(pickedPdf(name: 'Budget.xlsx'));
      await pumpEventQueue();

      expect(cubit.state, isNull);
    });

    test('has nothing waiting once the document is taken', () async {
      otherApps.open(pickedPdf());
      await pumpEventQueue();

      cubit.taken();

      expect(cubit.state, isNull);
    });
  });
}
