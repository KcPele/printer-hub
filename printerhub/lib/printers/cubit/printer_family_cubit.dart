import 'package:bloc/bloc.dart';
import 'package:printers_repository/printers_repository.dart';

/// The family one printer belongs to, for the tips on its page. Null until
/// it is known, and when the catalogue has no such family.
class PrinterFamilyCubit extends Cubit<PrinterFamily?> {
  new({required this._printersRepository}) : super(null);

  final PrintersRepository _printersRepository;

  Future<void> load({String? manufacturer, String? model}) async {
    final family = await _printersRepository.familyOf(
      manufacturer: manufacturer,
      model: model,
    );
    if (family != null && !isClosed) emit(family);
  }
}
