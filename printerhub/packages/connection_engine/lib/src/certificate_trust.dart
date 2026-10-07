/// Remembers the certificate each device showed the first time, and refuses
/// a different one later.
///
/// Printers sign their own certificates, so there is no authority to ask.
/// Trusting the first one seen and noticing a change is what remains.
class CertificateTrust {
  /// [known] is what was remembered on earlier launches, by `host:port`.
  /// [_onTrusted] is called when a new device is remembered, to save it.
  new({Map<String, String>? known, this._onTrusted}) : _known = {...?known};

  final Map<String, String> _known;
  final void Function(String device, String fingerprint)? _onTrusted;
  final Set<String> _changed = {};

  /// The devices whose certificate was not the one remembered, by
  /// `host:port`. Something to warn the user about.
  Set<String> get changed => Set.unmodifiable(_changed);

  /// Whether to talk to the device at [host] and [port], which presented a
  /// certificate with [fingerprint]. Pass this to `IoPrinterHttp`.
  bool check(String host, int port, String fingerprint) {
    final device = '$host:$port';
    final remembered = _known[device];
    if (remembered == null) {
      _known[device] = fingerprint;
      _onTrusted?.call(device, fingerprint);
      return true;
    }
    if (remembered == fingerprint) return true;
    _changed.add(device);
    return false;
  }

  /// Accepts the new certificate of a device the user has confirmed, for
  /// example after its firmware was updated.
  void forget(String host, int port) {
    final device = '$host:$port';
    _known.remove(device);
    _changed.remove(device);
  }
}
