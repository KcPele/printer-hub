import 'package:auth_repository/auth_repository.dart';
import 'package:printerhub/auth/cubit/submit_cubit.dart';

class SignInCubit extends SubmitCubit {
  new({required this._authRepository});

  final AuthRepository _authRepository;

  Future<void> submit({required String email, required String password}) {
    return run(() => _authRepository.signIn(email: email, password: password));
  }
}

class RegisterCubit extends SubmitCubit {
  new({required this._authRepository});

  final AuthRepository _authRepository;

  Future<void> submit({
    required String name,
    required String email,
    required String password,
  }) {
    return run(
      () => _authRepository.register(
        name: name,
        email: email,
        password: password,
      ),
    );
  }
}

class ForgotPasswordCubit extends SubmitCubit {
  new({required this._authRepository});

  final AuthRepository _authRepository;

  Future<void> submit({required String email}) {
    return run(() => _authRepository.requestPasswordReset(email));
  }
}

class ResetPasswordCubit extends SubmitCubit {
  new({required this._authRepository});

  final AuthRepository _authRepository;

  Future<void> submit({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return run(
      () => _authRepository.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      ),
    );
  }
}

class VerifyEmailCubit extends SubmitCubit {
  new({required this._authRepository});

  final AuthRepository _authRepository;

  Future<void> submit({required String code}) {
    return run(() => _authRepository.verifyEmail(code));
  }
}

/// Asks for another verification code.
class ResendCodeCubit extends SubmitCubit {
  new({required this._authRepository});

  final AuthRepository _authRepository;

  Future<void> submit() => run(_authRepository.resendVerification);
}
