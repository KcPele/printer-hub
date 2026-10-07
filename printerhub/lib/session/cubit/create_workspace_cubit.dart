import 'package:printerhub/auth/cubit/submit_cubit.dart';
import 'package:printerhub/session/cubit/session_cubit.dart';

class CreateWorkspaceCubit extends SubmitCubit {
  new({required this._sessionCubit});

  final SessionCubit _sessionCubit;

  Future<void> submit({required String name}) {
    return run(() => _sessionCubit.createWorkspace(name));
  }
}
