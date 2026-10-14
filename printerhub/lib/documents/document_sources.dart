/// Where a document came from, as the API names it: the scanner, the
/// camera, or the tool that made it. A list is narrowed to what one
/// screen makes by these.
abstract final class DocumentSources {
  static const String upload = 'upload';
  static const String printerScan = 'printer_scan';
  static const String cameraScan = 'camera_scan';

  /// Files from the phone, put together on the scan screen.
  static const String joinedFiles = 'joined_files';
  static const String pdfPictures = 'pdf_pictures';
  static const String longPicture = 'long_picture';
  static const String photoSheet = 'photo_sheet';
  static const String pagesPerSheet = 'pages_per_sheet';
  static const String codeSheet = 'code_sheet';
  static const String note = 'note';
  static const String printable = 'printable';
  static const String editedPicture = 'edited_picture';
  static const String signedPdf = 'signed_pdf';
  static const String idPhoto = 'id_photo';
  static const String bookPages = 'book_pages';
  static const String lockedPdf = 'locked_pdf';
  static const String searchablePdf = 'searchable_pdf';

  /// What the scan screen makes.
  static const Set<String> scans = {printerScan, cameraScan, joinedFiles};

  /// Every source, in the order a person is offered them.
  static const List<String> all = [
    printerScan,
    cameraScan,
    joinedFiles,
    pdfPictures,
    longPicture,
    photoSheet,
    pagesPerSheet,
    codeSheet,
    note,
    printable,
    editedPicture,
    signedPdf,
    idPhoto,
    bookPages,
    lockedPdf,
    searchablePdf,
    upload,
  ];
}
