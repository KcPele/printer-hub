# notifications_repository

What the signed-in account has been told: a job finished or failed, a scan is ready, a workspace sent an invitation.

A notification belongs to the account, not to one workspace. Each carries the identifiers the app needs to open the right screen (`jobId`, `organizationId`, `invitationId`).

```dart
final unread = await notifications.unreadCount();
final page = await notifications.list();
await notifications.markRead(page.notifications.first.id);
```

`changes` fires when something was read, so a badge elsewhere can count again.

`flutter test --tags live` runs it against a local backend (`make dev`).
