import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:printers_repository/printers_repository.dart';

enum CatalogueStatus { loading, ready, failed }

/// Which kind of printer the catalogue is narrowed to.
enum CatalogueFilter { all, home, office }

class CatalogueState extends Equatable {
  const new({
    this.status = CatalogueStatus.loading,
    this.families = const [],
    this.query = '',
    this.filter = CatalogueFilter.all,
    this.error,
  });

  final CatalogueStatus status;

  /// Every family, the ones most people have first.
  final List<PrinterFamily> families;

  /// What was typed into the search field.
  final String query;
  final CatalogueFilter filter;

  /// Why the catalogue could not be read. Pass it to `errorMessage`.
  final ApiException? error;

  /// The families that match the search and the filter, in order.
  List<PrinterFamily> get visible => [
    for (final family in families)
      if (family.matches(query.trim()) &&
          switch (filter) {
            CatalogueFilter.all => true,
            CatalogueFilter.home => family.isHome,
            CatalogueFilter.office => !family.isHome,
          })
        family,
  ];

  CatalogueState _with({String? query, CatalogueFilter? filter}) {
    return CatalogueState(
      status: status,
      families: families,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, families, query, filter, error];
}

/// The catalogue of printer families, with a search and a filter.
class CatalogueCubit extends Cubit<CatalogueState> {
  new({required this._printersRepository}) : super(const CatalogueState());

  final PrintersRepository _printersRepository;

  Future<void> load() async {
    emit(CatalogueState(query: state.query, filter: state.filter));
    try {
      final families = await _printersRepository.families();
      emit(
        CatalogueState(
          status: CatalogueStatus.ready,
          families: families,
          query: state.query,
          filter: state.filter,
        ),
      );
    } on ApiException catch (error) {
      emit(
        CatalogueState(
          status: CatalogueStatus.failed,
          query: state.query,
          filter: state.filter,
          error: error,
        ),
      );
    }
  }

  void search(String query) => emit(state._with(query: query));

  void show(CatalogueFilter filter) => emit(state._with(filter: filter));
}
