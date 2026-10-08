import 'package:api_client/api_client.dart';
import 'package:equatable/equatable.dart';
import 'package:organizations_repository/src/organization.dart';

/// The rules a workspace sets for everyone in it.
class WorkspacePolicy extends Equatable {
  const new({
    this.maxCopiesPerJob,
    this.cloudDocuments = true,
    this.documentRetentionDays,
    this.colorPrintingRoles = const [
      'owner',
      'admin',
      'operator',
      'user',
      'viewer',
    ],
  });

  factory fromJson(Map<String, dynamic> json) {
    return WorkspacePolicy(
      maxCopiesPerJob: json['max_copies_per_job'] as int?,
      cloudDocuments: json['document_storage_mode'] != 'local_only',
      documentRetentionDays: json['document_retention_days'] as int?,
      colorPrintingRoles: [
        for (final role in json['color_printing_roles'] as List<dynamic>? ?? [])
          '$role',
      ],
    );
  }

  /// The most copies one job may ask for. Null is no limit.
  final int? maxCopiesPerJob;

  /// True when documents may be kept in the workspace's storage. False
  /// keeps every document on the device that made it.
  final bool cloudDocuments;

  /// How many days a kept document stays. Null keeps it until deleted.
  final int? documentRetentionDays;

  /// The roles that may print in colour.
  final List<String> colorPrintingRoles;

  WorkspacePolicy copyWith({
    int? Function()? maxCopiesPerJob,
    bool? cloudDocuments,
    int? Function()? documentRetentionDays,
  }) {
    return WorkspacePolicy(
      maxCopiesPerJob: maxCopiesPerJob == null
          ? this.maxCopiesPerJob
          : maxCopiesPerJob(),
      cloudDocuments: cloudDocuments ?? this.cloudDocuments,
      documentRetentionDays: documentRetentionDays == null
          ? this.documentRetentionDays
          : documentRetentionDays(),
      colorPrintingRoles: colorPrintingRoles,
    );
  }

  OrganizationSettingsInput toApi() {
    return OrganizationSettingsInput(
      maxCopiesPerJob: maxCopiesPerJob,
      documentStorageMode:
          OrganizationSettingsInputDocumentStorageMode.fromJson(
            cloudDocuments ? 'cloud_allowed' : 'local_only',
          ),
      documentRetentionDays: documentRetentionDays,
      colorPrintingRoles: colorPrintingRoles.map(Role.fromJson).toList(),
    );
  }

  @override
  List<Object?> get props => [
    maxCopiesPerJob,
    cloudDocuments,
    documentRetentionDays,
    colorPrintingRoles,
  ];
}

/// A workspace with its rules.
class Workspace extends Equatable {
  const new({required this.organization, required this.policy});

  factory fromApi(OrganizationRead organization) {
    return Workspace(
      organization: Organization.fromApi(organization),
      policy: WorkspacePolicy.fromJson(
        organization.toJson()['settings']! as Map<String, dynamic>,
      ),
    );
  }

  final Organization organization;
  final WorkspacePolicy policy;

  @override
  List<Object?> get props => [organization, policy];
}

/// Someone who belongs to a workspace.
class Member extends Equatable {
  const new({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  factory fromApi(MemberRead member) {
    return Member(
      userId: member.user.id,
      name: member.user.name,
      email: member.user.email,
      role: member.role.json ?? 'viewer',
      joinedAt: member.joinedAt,
    );
  }

  final String userId;
  final String name;
  final String email;

  /// `owner`, `admin`, `operator`, `user`, or `viewer`.
  final String role;
  final DateTime joinedAt;

  @override
  List<Object?> get props => [userId, name, email, role, joinedAt];
}

/// An invitation a workspace has sent, not yet taken up.
class Invitation extends Equatable {
  const new({
    required this.id,
    required this.email,
    required this.role,
    required this.expiresAt,
    this.code,
  });

  final String id;
  final String email;
  final String role;
  final DateTime expiresAt;

  /// What the invited person types to join. Known only as the invitation
  /// is made: the API shows it once.
  final String? code;

  @override
  List<Object?> get props => [id, email, role, expiresAt, code];
}

/// An invitation the signed-in person has been sent.
class ReceivedInvitation extends Equatable {
  const new({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.role,
    required this.expiresAt,
  });

  factory fromApi(MyInvitationRead invitation) {
    return ReceivedInvitation(
      id: invitation.id,
      organizationId: invitation.organizationId,
      organizationName: invitation.organizationName,
      role: invitation.role.json ?? 'viewer',
      expiresAt: invitation.expiresAt,
    );
  }

  final String id;
  final String organizationId;
  final String organizationName;
  final String role;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [
    id,
    organizationId,
    organizationName,
    role,
    expiresAt,
  ];
}

/// Something that was done in a workspace, as its log records it.
class LoggedAction extends Equatable {
  const new({
    required this.id,
    required this.action,
    required this.targetType,
    required this.succeeded,
    required this.at,
    this.actorUserId,
    this.detail = const {},
  });

  factory fromApi(AuditLogRead entry) {
    final detail = entry.detail;
    return LoggedAction(
      id: entry.id,
      action: entry.action,
      targetType: entry.targetType,
      succeeded: entry.outcome.json != 'failure',
      at: entry.createdAt,
      actorUserId: entry.actorUserId,
      detail: detail is Map
          ? {for (final entry in detail.entries) '${entry.key}': entry.value}
          : const {},
    );
  }

  final String id;

  /// What was done, such as `printer.created` or `member.role_changed`.
  final String action;

  /// What it was done to: `printer`, `invitation`, `membership`.
  final String targetType;
  final bool succeeded;
  final DateTime at;

  /// Who did it. Null when the system did.
  final String? actorUserId;

  /// What else is known, such as the email an invitation went to.
  final Map<String, Object?> detail;

  @override
  List<Object?> get props => [
    id,
    action,
    targetType,
    succeeded,
    at,
    actorUserId,
    detail,
  ];
}
