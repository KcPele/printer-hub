import 'dart:typed_data';

import 'package:meta/meta.dart';

/// One value of an attribute, with the type the printer gave it.
///
/// [value] is an `int` for integers and enums, a `bool`, a `String` for
/// every textual type, an [IppRange], an [IppResolution], a `DateTime`, a
/// `Map<String, IppAttribute>` for a collection, a `Uint8List` for an octet
/// string, and null for the out-of-band tags (unsupported, unknown,
/// no-value).
@immutable
class IppValue {
  const new(this.tag, this.value);

  final int tag;
  final Object? value;

  @override
  String toString() => '$value';
}

@immutable
class IppRange {
  const new(this.lower, this.upper);

  final int lower;
  final int upper;

  @override
  bool operator ==(Object other) {
    return other is IppRange && other.lower == lower && other.upper == upper;
  }

  @override
  int get hashCode => Object.hash(lower, upper);

  @override
  String toString() => '$lower-$upper';
}

@immutable
class IppResolution {
  const new(this.x, this.y, {this.perInch = true});

  final int x;
  final int y;

  /// False when the printer reports dots per centimetre.
  final bool perInch;

  /// The horizontal resolution in dots per inch.
  int get dpi => perInch ? x : (x * 2.54).round();

  @override
  bool operator ==(Object other) {
    return other is IppResolution &&
        other.x == x &&
        other.y == y &&
        other.perInch == perInch;
  }

  @override
  int get hashCode => Object.hash(x, y, perInch);

  @override
  String toString() => '${x}x$y${perInch ? 'dpi' : 'dpcm'}';
}

/// A named attribute and its values. Most have one; `media-supported` has
/// many.
@immutable
class IppAttribute {
  const new(this.name, this.values);

  new single(this.name, int tag, Object? value)
    : values = [IppValue(tag, value)];

  /// One attribute holding every item of [items] with the same [tag].
  new all(this.name, int tag, Iterable<Object?> items)
    : values = [for (final item in items) IppValue(tag, item)];

  final String name;
  final List<IppValue> values;

  Object? get first => values.isEmpty ? null : values.first.value;

  /// The values that are strings, in order.
  List<String> get strings => [
    for (final item in values)
      if (item.value is String) item.value! as String,
  ];

  /// The values that are integers, in order.
  List<int> get integers => [
    for (final item in values)
      if (item.value is int) item.value! as int,
  ];
}

/// A run of attributes that belong together: about the operation, a job, or
/// the printer.
class IppGroup {
  new(this.tag, [List<IppAttribute>? attributes])
    : attributes = attributes ?? [];

  final int tag;
  final List<IppAttribute> attributes;

  IppAttribute? operator [](String name) {
    for (final attribute in attributes) {
      if (attribute.name == name) return attribute;
    }
    return null;
  }

  void add(IppAttribute attribute) => attributes.add(attribute);
}

/// An IPP request or response, without the document that may follow it.
class IppMessage {
  new({
    required this.code,
    required this.requestId,
    List<IppGroup>? groups,
    this.majorVersion = 2,
    this.minorVersion = 0,
  }) : groups = groups ?? [];

  /// The operation of a request, or the status of a response.
  final int code;
  final int requestId;
  final List<IppGroup> groups;
  final int majorVersion;
  final int minorVersion;

  /// The first group with [tag], or null.
  IppGroup? group(int tag) {
    for (final group in groups) {
      if (group.tag == tag) return group;
    }
    return null;
  }

  /// Every group with [tag]. Get-Jobs answers with one per job.
  List<IppGroup> groupsOf(int tag) {
    return [
      for (final group in groups)
        if (group.tag == tag) group,
    ];
  }
}

/// What followed the attributes in a decoded message.
class IppDecoded {
  const new(this.message, this.data);

  final IppMessage message;

  /// The bytes after the end-of-attributes tag. Empty for most responses.
  final Uint8List data;
}
