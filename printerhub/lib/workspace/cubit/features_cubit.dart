import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:organizations_repository/organizations_repository.dart';

/// What is switched on for the workspace in use, by name. It follows the
/// workspace: another workspace has its own.
///
/// A screen asks `context.read<FeaturesCubit>().enabled('local_ocr')`.
/// Something that is not named, or was never known, is off. What was
/// known the last time the API was reached holds while it cannot be.
class FeaturesCubit extends Cubit<Map<String, bool>> {
  new({
    required this._organizationsRepository,
    required Stream<String?> organizationChanges,
    this._organizationId,
  }) : super(const {}) {
    _organizations = organizationChanges.listen((id) {
      _organizationId = id;
      emit(const {});
      unawaited(load());
    });
  }

  final OrganizationsRepository _organizationsRepository;
  late final StreamSubscription<String?> _organizations;
  String? _organizationId;

  bool enabled(String feature) => state[feature] ?? false;

  Future<void> load() async {
    final organizationId = _organizationId;
    if (organizationId == null) return;
    // What was known last time holds until the API answers, and after it
    // if it cannot be reached.
    final kept = await _organizationsRepository.keptFeatures(organizationId);
    if (!isClosed && organizationId == _organizationId && state.isEmpty) {
      emit(kept);
    }
    try {
      final features = await _organizationsRepository.features(organizationId);
      if (!isClosed && organizationId == _organizationId) emit(features);
    } on ApiException {
      // What was known last time stands. With nothing known, everything
      // stays off.
    }
  }

  @override
  Future<void> close() async {
    await _organizations.cancel();
    await super.close();
  }
}
