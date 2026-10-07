/// The numbers IPP puts on the wire (RFC 8010 and RFC 8011).
library;

/// What a request asks the printer to do.
abstract final class IppOperation {
  static const int printJob = 0x0002;
  static const int validateJob = 0x0004;
  static const int cancelJob = 0x0008;
  static const int getJobAttributes = 0x0009;
  static const int getJobs = 0x000A;
  static const int getPrinterAttributes = 0x000B;
}

/// Which part of a message a run of attributes belongs to.
abstract final class IppGroupTag {
  static const int operation = 0x01;
  static const int job = 0x02;
  static const int end = 0x03;
  static const int printer = 0x04;
  static const int unsupported = 0x05;
}

/// The type of an attribute value.
abstract final class IppValueTag {
  static const int unsupported = 0x10;
  static const int unknown = 0x12;
  static const int noValue = 0x13;
  static const int integer = 0x21;
  static const int boolean = 0x22;
  static const int enumeration = 0x23;
  static const int octetString = 0x30;
  static const int dateTime = 0x31;
  static const int resolution = 0x32;
  static const int rangeOfInteger = 0x33;
  static const int beginCollection = 0x34;
  static const int textWithLanguage = 0x35;
  static const int nameWithLanguage = 0x36;
  static const int endCollection = 0x37;
  static const int text = 0x41;
  static const int name = 0x42;
  static const int keyword = 0x44;
  static const int uri = 0x45;
  static const int uriScheme = 0x46;
  static const int charset = 0x47;
  static const int naturalLanguage = 0x48;
  static const int mimeMediaType = 0x49;
  static const int memberName = 0x4A;
}

/// How a printer answered.
abstract final class IppStatus {
  static const int ok = 0x0000;

  /// Codes up to here mean the operation succeeded, possibly with attributes
  /// that were ignored or substituted.
  static const int lastSuccess = 0x00FF;

  static const int clientErrorBadRequest = 0x0400;
  static const int clientErrorNotAuthenticated = 0x0402;
  static const int clientErrorNotAuthorized = 0x0403;
  static const int clientErrorNotPossible = 0x0404;
  static const int clientErrorNotFound = 0x0406;
  static const int clientErrorDocumentFormatNotSupported = 0x040A;
  static const int clientErrorAttributesOrValuesNotSupported = 0x040B;
  static const int serverErrorInternalError = 0x0500;
  static const int serverErrorOperationNotSupported = 0x0501;
  static const int serverErrorServiceUnavailable = 0x0502;
  static const int serverErrorVersionNotSupported = 0x0503;
  static const int serverErrorDeviceError = 0x0504;
  static const int serverErrorNotAcceptingJobs = 0x0506;
  static const int serverErrorBusy = 0x0507;

  static const Map<int, String> _names = {
    ok: 'successful-ok',
    clientErrorBadRequest: 'client-error-bad-request',
    clientErrorNotAuthenticated: 'client-error-not-authenticated',
    clientErrorNotAuthorized: 'client-error-not-authorized',
    clientErrorNotPossible: 'client-error-not-possible',
    clientErrorNotFound: 'client-error-not-found',
    clientErrorDocumentFormatNotSupported:
        'client-error-document-format-not-supported',
    clientErrorAttributesOrValuesNotSupported:
        'client-error-attributes-or-values-not-supported',
    serverErrorInternalError: 'server-error-internal-error',
    serverErrorOperationNotSupported: 'server-error-operation-not-supported',
    serverErrorServiceUnavailable: 'server-error-service-unavailable',
    serverErrorVersionNotSupported: 'server-error-version-not-supported',
    serverErrorDeviceError: 'server-error-device-error',
    serverErrorNotAcceptingJobs: 'server-error-not-accepting-jobs',
    serverErrorBusy: 'server-error-busy',
  };

  /// The keyword for [code], or its number in hex when it has no entry here.
  static String nameOf(int code) {
    return _names[code] ?? '0x${code.toRadixString(16).padLeft(4, '0')}';
  }
}
