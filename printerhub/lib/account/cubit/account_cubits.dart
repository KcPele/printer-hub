import 'package:auth_repository/auth_repository.dart';
import 'package:printerhub/auth/cubit/submit_cubit.dart';

/// Changes the name shown to the rest of a workspace.
class UpdateNameCubit extends SubmitCubit {
  new({required this._authRepository});

  final AuthRepository _authRepository;

  Future<void> submit({required String name}) {
    return run(() => _authRepository.updateName(name));
  }
}

class ChangePasswordCubit extends SubmitCubit {
  new({required this._authRepository});

  final AuthRepository _authRepository;

  Future<void> submit({
    required String currentPassword,
    required String newPassword,
  }) {
    return run(
      () => _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
  }
}

/// Deletes the account for good. Succeeding ends the session, and the
/// router leaves for the sign-in screen.
class DeleteAccountCubit extends SubmitCubit {
  new({required this._authRepository});

  final AuthRepository _authRepository;

  Future<void> submit({required String password}) {
    return run(() => _authRepository.deleteAccount(password: password));
  }
}
