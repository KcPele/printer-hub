import 'package:auth_repository/src/models.dart';
import 'package:equatable/equatable.dart';

/// Whether someone is signed in on this device.
sealed class AuthStatus extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Not known yet: the stored session has not been read.
final class AuthUnknown extends AuthStatus {
  const new();
}

final class SignedOut extends AuthStatus {
  const new();
}

final class SignedIn extends AuthStatus {
  const new(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}
