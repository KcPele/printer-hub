# documents_repository

Documents kept in a workspace: a scan put there from the phone, listed, renamed, fetched back, and deleted.

A document's record is on the PrinterHub API. Its file is in object storage, and travels straight between the phone and the storage over a link the API signs: `FileTransfer` does that, and never sends the account's sign-in with it.

```dart
final kept = await documents.keep(
  organizationId: organizationId,
  file: file,
  name: 'Receipts.pdf',
  mimeType: 'application/pdf',
  pageCount: 3,
  printerId: printer.id,
);
```

`keep` throws `UploadInterrupted` when the record was made but the file did not arrive. Pass its document to `finish` to send the file again.

`flutter test --tags live` runs it against a local backend and its storage (`make dev`).
