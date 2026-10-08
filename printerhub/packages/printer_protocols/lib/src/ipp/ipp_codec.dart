import 'dart:convert';
import 'dart:typed_data';

import 'package:printer_protocols/src/ipp/ipp_constants.dart';
import 'package:printer_protocols/src/ipp/ipp_message.dart';

/// The bytes are not an IPP message.
class IppFormatException extends FormatException {
  const new(super.message);
}

/// Turns [message] into the bytes that go before the document.
Uint8List encodeIpp(IppMessage message) {
  final out = BytesBuilder()
    ..addByte(message.majorVersion)
    ..addByte(message.minorVersion)
    ..add(_uint16(message.code))
    ..add(_uint32(message.requestId));

  for (final group in message.groups) {
    out.addByte(group.tag);
    for (final attribute in group.attributes) {
      var first = true;
      for (final value in attribute.values) {
        _writeValue(out, first ? attribute.name : '', value);
        first = false;
      }
    }
  }
  out.addByte(IppGroupTag.end);
  return out.toBytes();
}

/// Reads an IPP message. Throws [IppFormatException] when [bytes] is cut
/// short or is something else, such as a web page.
IppDecoded decodeIpp(Uint8List bytes) {
  final reader = _Reader(bytes);
  final major = reader.byte();
  final minor = reader.byte();
  final message = IppMessage(
    code: reader.uint16(),
    requestId: reader.uint32(),
    majorVersion: major,
    minorVersion: minor,
  );

  IppGroup? group;
  List<IppValue>? values;
  while (true) {
    final tag = reader.byte();
    if (tag == IppGroupTag.end) break;
    if (tag < 0x10) {
      group = IppGroup(tag);
      message.groups.add(group);
      values = null;
      continue;
    }
    if (group == null) {
      throw const IppFormatException('An attribute came before any group.');
    }

    final name = reader.text(reader.uint16());
    final raw = reader.bytes(reader.uint16());
    final value = tag == IppValueTag.beginCollection
        ? IppValue(tag, _readCollection(reader))
        : IppValue(tag, _decodeValue(tag, raw));

    // An empty name means one more value of the attribute before.
    if (name.isEmpty && values != null) {
      values.add(value);
    } else {
      values = [value];
      group.add(IppAttribute(name, values));
    }
  }
  return IppDecoded(message, reader.rest());
}

Map<String, IppAttribute> _readCollection(_Reader reader) {
  final members = <String, IppAttribute>{};
  List<IppValue>? values;
  while (true) {
    final tag = reader.byte();
    reader.bytes(reader.uint16()); // The name is always empty in here.
    final raw = reader.bytes(reader.uint16());

    if (tag == IppValueTag.endCollection) return members;
    if (tag == IppValueTag.memberName) {
      values = [];
      final name = utf8.decode(raw, allowMalformed: true);
      members[name] = IppAttribute(name, values);
    } else if (values != null) {
      values.add(
        tag == IppValueTag.beginCollection
            ? IppValue(tag, _readCollection(reader))
            : IppValue(tag, _decodeValue(tag, raw)),
      );
    }
  }
}

Object? _decodeValue(int tag, Uint8List raw) {
  final data = ByteData.sublistView(raw);
  switch (tag) {
    case IppValueTag.integer || IppValueTag.enumeration:
      return raw.length == 4 ? data.getInt32(0) : null;
    case IppValueTag.boolean:
      return raw.isNotEmpty && raw[0] != 0;
    case IppValueTag.rangeOfInteger:
      return raw.length == 8
          ? IppRange(data.getInt32(0), data.getInt32(4))
          : null;
    case IppValueTag.resolution:
      return raw.length == 9
          ? IppResolution(
              data.getInt32(0),
              data.getInt32(4),
              perInch: raw[8] == 3,
            )
          : null;
    case IppValueTag.dateTime:
      return raw.length == 11
          ? DateTime.utc(
              data.getUint16(0),
              raw[2],
              raw[3],
              raw[4],
              raw[5],
              raw[6],
            )
          : null;
    case IppValueTag.textWithLanguage || IppValueTag.nameWithLanguage:
      // language-length, language, text-length, text. The text is the part
      // worth keeping.
      if (raw.length < 4) return '';
      final languageLength = data.getUint16(0);
      final start = 2 + languageLength + 2;
      return start > raw.length
          ? ''
          : utf8.decode(raw.sublist(start), allowMalformed: true);
    case IppValueTag.octetString:
      return raw;
    case IppValueTag.unsupported || IppValueTag.unknown || IppValueTag.noValue:
      return null;
    default:
      return utf8.decode(raw, allowMalformed: true);
  }
}

void _writeValue(BytesBuilder out, String name, IppValue item) {
  final value = item.value;
  final Uint8List raw;
  switch (value) {
    case final Map<String, IppAttribute> members:
      _writeCollection(out, name, members);
      return;
    case final int number:
      raw = _uint32(number);
    case final bool flag:
      raw = Uint8List.fromList([if (flag) 1 else 0]);
    case final IppRange range:
      raw = Uint8List.fromList([
        ..._uint32(range.lower),
        ..._uint32(range.upper),
      ]);
    case final Uint8List bytes:
      raw = bytes;
    case null:
      raw = Uint8List(0);
    default:
      raw = utf8.encode('$value');
  }
  final nameBytes = utf8.encode(name);
  out
    ..addByte(item.tag)
    ..add(_uint16(nameBytes.length))
    ..add(nameBytes)
    ..add(_uint16(raw.length))
    ..add(raw);
}

/// A collection is its opening tag, then for each member a name and its
/// values, all with empty attribute names, then a closing tag.
void _writeCollection(
  BytesBuilder out,
  String name,
  Map<String, IppAttribute> members,
) {
  void entry(int tag, String name, List<int> raw) {
    final nameBytes = utf8.encode(name);
    out
      ..addByte(tag)
      ..add(_uint16(nameBytes.length))
      ..add(nameBytes)
      ..add(_uint16(raw.length))
      ..add(raw);
  }

  entry(IppValueTag.beginCollection, name, const []);
  for (final MapEntry(key: member, value: attribute) in members.entries) {
    entry(IppValueTag.memberName, '', utf8.encode(member));
    for (final value in attribute.values) {
      _writeValue(out, '', value);
    }
  }
  entry(IppValueTag.endCollection, '', const []);
}

Uint8List _uint16(int value) {
  return Uint8List(2)..buffer.asByteData().setUint16(0, value);
}

Uint8List _uint32(int value) {
  return Uint8List(4)..buffer.asByteData().setInt32(0, value);
}

class _Reader {
  new(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int _at = 0;

  void _need(int count) {
    if (_at + count > _bytes.length) {
      throw const IppFormatException('The message ends early.');
    }
  }

  int byte() {
    _need(1);
    return _bytes[_at++];
  }

  int uint16() {
    _need(2);
    final value = _data.getUint16(_at);
    _at += 2;
    return value;
  }

  int uint32() {
    _need(4);
    final value = _data.getUint32(_at);
    _at += 4;
    return value;
  }

  Uint8List bytes(int count) {
    _need(count);
    final value = Uint8List.sublistView(_bytes, _at, _at + count);
    _at += count;
    return value;
  }

  String text(int count) => utf8.decode(bytes(count), allowMalformed: true);

  Uint8List rest() => Uint8List.sublistView(_bytes, _at);
}
