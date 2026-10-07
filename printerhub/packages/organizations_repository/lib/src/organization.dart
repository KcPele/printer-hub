import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';

/// A workspace: the people and printers that belong together.
class Organization extends Equatable {
  const new({required this.id, required this.name, required this.role});

  factory fromApi(OrganizationRead organization) {
    return Organization(
      id: organization.id,
      name: organization.name,
      role: organization.role.json ?? 'viewer',
    );
  }

  factory fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }

  final String id;
  final String name;

  /// The signed-in user's role here: `owner`, `admin`, `operator`, `user`,
  /// or `viewer`.
  final String role;

  /// Whether the user may change the workspace, its members, and its
  /// printers.
  bool get canManage => role == 'owner' || role == 'admin';

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};

  @override
  List<Object> get props => [id, name, role];
}
