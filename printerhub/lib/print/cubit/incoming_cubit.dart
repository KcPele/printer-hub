import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:printerhub/print/documents.dart';

/// The document another app handed over that is still waiting to be
/// printed. Null when there is none.
///
/// It may arrive before anyone is signed in, or before the printers are
/// known. It waits here until the app can do something with it, and
/// [taken] is called when it does.
class IncomingCubit extends Cubit<PickedDocument?> {
  new({required IncomingDocuments incoming}) : super(null) {
    _arrivals = incoming.documents.listen((document) {
      // A kind of file the app does not print is not offered at all.
      if (document.mimeType != null) emit(document);
    });
  }

  late final StreamSubscription<PickedDocument> _arrivals;

  /// The waiting document is being dealt with.
  void taken() => emit(null);

  @override
  Future<void> close() async {
    await _arrivals.cancel();
    await super.close();
  }
}
