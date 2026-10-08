# jobs_repository

Print, scan, and copy jobs.

The phone runs a job itself, against the printer on the local network, and this package keeps the record: it tells the backend when a job starts and how it goes, and keeps what it could not send for the next time the API is in reach. A job started offline is not lost, and sending it twice changes nothing.

```dart
final job = await jobs.startPrint(
  organizationId: organizationId,
  printerId: printer.id,
  title: 'Report.pdf',
  choices: const PrintChoices(copies: 2),
);
await jobs.report(organizationId, job.id, const JobUpdate(status: 'printing'));
await jobs.sync(organizationId); // later, when back online
```
