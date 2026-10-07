// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/job_create.dart';
import '../models/job_event_create.dart';
import '../models/job_event_read.dart';
import '../models/job_read.dart';
import '../models/job_status.dart';
import '../models/job_sync_request.dart';
import '../models/job_sync_response.dart';
import '../models/job_type.dart';
import '../models/page_job_read.dart';

part 'jobs_client.g.dart';

@RestApi()
abstract class JobsClient {
  factory JobsClient(Dio dio, {String? baseUrl}) = _JobsClient;

  /// List Jobs.
  ///
  /// Job history, newest first. Members without `jobs.read_all` see only their own jobs.
  ///
  /// [userId] - Ignored unless the caller may read all jobs.
  ///
  /// [cursor] - `next_cursor` from the previous page.
  @GET('/api/v1/organizations/{org_id}/jobs')
  Future<PageJobRead> listJobs({
    @Path('org_id') required String orgId,
    @Query('limit') int? limit = 50,
    @Query('printer_id') String? printerId,
    @Query('user_id') String? userId,
    @Query('type') JobType? type,
    @Query('status') List<JobStatus>? status,
    @Query('submitted_from') DateTime? submittedFrom,
    @Query('submitted_to') DateTime? submittedTo,
    @Query('cursor') String? cursor,
  });

  /// Create Job.
  ///
  /// Record a job the client is about to execute.
  ///
  /// Send a fresh `Idempotency-Key` per job and reuse it on every retry of the.
  /// request, so a lost response never creates a second job (FR-PRN-022).
  ///
  /// [idempotencyKey] - Unique per logical request. Reuse it when retrying.
  @POST('/api/v1/organizations/{org_id}/jobs')
  Future<JobRead> createJob({
    @Path('org_id') required String orgId,
    @Header('Idempotency-Key') required String idempotencyKey,
    @Body() required JobCreate body,
  });

  /// Sync Jobs.
  ///
  /// Upload jobs and their state history recorded while offline.
  ///
  /// Items are independent: one failing does not affect the others. The call.
  /// is safe to repeat.
  @POST('/api/v1/organizations/{org_id}/jobs/batch')
  Future<JobSyncResponse> syncJobs({
    @Path('org_id') required String orgId,
    @Body() required JobSyncRequest body,
  });

  /// Get Job
  @GET('/api/v1/organizations/{org_id}/jobs/{job_id}')
  Future<JobRead> getJob({
    @Path('job_id') required String jobId,
    @Path('org_id') required String orgId,
  });

  /// Cancel Job
  @POST('/api/v1/organizations/{org_id}/jobs/{job_id}/cancel')
  Future<JobRead> cancelJob({
    @Path('job_id') required String jobId,
    @Path('org_id') required String orgId,
  });

  /// List Job Events.
  ///
  /// Every reported state change and connection attempt, oldest first.
  @GET('/api/v1/organizations/{org_id}/jobs/{job_id}/events')
  Future<List<JobEventRead>> listJobEvents({
    @Path('job_id') required String jobId,
    @Path('org_id') required String orgId,
  });

  /// Report Job Event.
  ///
  /// Report a state change from the client executing the job.
  ///
  /// Name the connection used on each attempt. When it differs from the.
  /// previous one the job is marked as having fallen back (FR-CON-010).
  @POST('/api/v1/organizations/{org_id}/jobs/{job_id}/events')
  Future<JobRead> reportJobEvent({
    @Path('job_id') required String jobId,
    @Path('org_id') required String orgId,
    @Body() required JobEventCreate body,
  });

  /// Retry Job.
  ///
  /// Create a new job with the same settings as a failed or cancelled one.
  ///
  /// [idempotencyKey] - Unique per logical request. Reuse it when retrying.
  @POST('/api/v1/organizations/{org_id}/jobs/{job_id}/retry')
  Future<JobRead> retryJob({
    @Path('job_id') required String jobId,
    @Path('org_id') required String orgId,
    @Header('Idempotency-Key') required String idempotencyKey,
  });
}
