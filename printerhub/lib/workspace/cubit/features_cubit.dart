import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:bloc/bloc.dart';
import 'package:organizations_repository/organizations_repository.dart';

/// What is switched on for the workspace in use, by name. It follows the
/// workspace: another workspace has its own.
///
/// A screen asks `context.read<FeaturesCubit>().enabled('local_ocr')`.
/// Something that is not named, or not yet known, is off.
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
    try {
      final features = await _organizationsRepository.features(organizationId);
      if (!isClosed && organizationId == _organizationId) emit(features);
    } on ApiException {
      // Everything stays off until they can be read.
    }
  }

  @override
  Future<void> close() async {
    await _organizations.cancel();
    await super.close();
  }
}
