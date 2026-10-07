// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/invitation_accept.dart';
import '../models/invitation_create.dart';
import '../models/invitation_created.dart';
import '../models/invitation_read.dart';
import '../models/member_read.dart';
import '../models/member_update.dart';
import '../models/my_invitation_read.dart';
import '../models/organization_create.dart';
import '../models/organization_read.dart';
import '../models/organization_update.dart';

part 'organizations_client.g.dart';

@RestApi()
abstract class OrganizationsClient {
  factory OrganizationsClient(Dio dio, {String? baseUrl}) =
      _OrganizationsClient;

  /// List My Invitations.
  ///
  /// Pending invitations sent to the caller's email address.
  @GET('/api/v1/invitations')
  Future<List<MyInvitationRead>> listMyInvitations();

  /// Accept Invitation.
  ///
  /// Join with the token from an invitation link. The caller's email must match.
  @POST('/api/v1/invitations/accept')
  Future<OrganizationRead> acceptInvitation({
    @Body() required InvitationAccept body,
  });

  /// Accept My Invitation.
  ///
  /// Accept one of the caller's pending invitations from inside the app.
  @POST('/api/v1/invitations/{invitation_id}/accept')
  Future<OrganizationRead> acceptMyInvitation({
    @Path('invitation_id') required String invitationId,
  });

  /// List Organizations.
  ///
  /// Organizations the caller belongs to.
  @GET('/api/v1/organizations')
  Future<List<OrganizationRead>> listOrganizations();

  /// Create Organization.
  ///
  /// Create an organization. The caller becomes its owner.
  @POST('/api/v1/organizations')
  Future<OrganizationRead> createOrganization({
    @Body() required OrganizationCreate body,
  });

  /// Delete Organization.
  ///
  /// Delete the organization with all its printers, jobs, and documents.
  @DELETE('/api/v1/organizations/{org_id}')
  Future<void> deleteOrganization({@Path('org_id') required String orgId});

  /// Get Organization
  @GET('/api/v1/organizations/{org_id}')
  Future<OrganizationRead> getOrganization({
    @Path('org_id') required String orgId,
  });

  /// Update Organization
  @PATCH('/api/v1/organizations/{org_id}')
  Future<OrganizationRead> updateOrganization({
    @Path('org_id') required String orgId,
    @Body() required OrganizationUpdate body,
  });

  /// List Invitations
  @GET('/api/v1/organizations/{org_id}/invitations')
  Future<List<InvitationRead>> listInvitations({
    @Path('org_id') required String orgId,
  });

  /// Create Invitation.
  ///
  /// Invite someone by email. The token appears only in this response.
  @POST('/api/v1/organizations/{org_id}/invitations')
  Future<InvitationCreated> createInvitation({
    @Path('org_id') required String orgId,
    @Body() required InvitationCreate body,
  });

  /// Revoke Invitation
  @DELETE('/api/v1/organizations/{org_id}/invitations/{invitation_id}')
  Future<void> revokeInvitation({
    @Path('invitation_id') required String invitationId,
    @Path('org_id') required String orgId,
  });

  /// List Members
  @GET('/api/v1/organizations/{org_id}/members')
  Future<List<MemberRead>> listMembers({@Path('org_id') required String orgId});

  /// Remove Member.
  ///
  /// Remove a member. Any member may remove themselves to leave.
  @DELETE('/api/v1/organizations/{org_id}/members/{user_id}')
  Future<void> removeMember({
    @Path('user_id') required String userId,
    @Path('org_id') required String orgId,
  });

  /// Change Member Role
  @PATCH('/api/v1/organizations/{org_id}/members/{user_id}')
  Future<MemberRead> changeMemberRole({
    @Path('user_id') required String userId,
    @Path('org_id') required String orgId,
    @Body() required MemberUpdate body,
  });
}
