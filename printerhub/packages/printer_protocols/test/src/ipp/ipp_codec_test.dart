import 'dart:convert';
import 'dart:typed_data';

import 'package:printer_protocols/printer_protocols.dart';
import 'package:test/test.dart';

/// Builds raw IPP bytes by hand, to decode what a real printer might send.
class _Raw {
  final BytesBuilder _out = BytesBuilder();

  void header({int status = 0, int requestId = 7}) {
    _out
      ..add([2, 0])
      ..add(_u16(status))
      ..add(_u32(requestId));
  }

  void group(int tag) => _out.addByte(tag);

  void value(int tag, String name, List<int> raw) {
    final nameBytes = utf8.encode(name);
    _out
      ..addByte(tag)
      ..add(_u16(nameBytes.length))
      ..add(nameBytes)
      ..add(_u16(raw.length))
      ..add(raw);
  }

  Uint8List end([List<int> data = const []]) {
    _out
      ..addByte(IppGroupTag.end)
      ..add(data);
    return _out.toBytes();
  }

  static List<int> _u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];
  static List<int> _u32(int v) => [
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ];
  static List<int> i32(int v) => _u32(v);
}

void main() {
  group('encodeIpp and decodeIpp', () {
    test('carry a request through unchanged', () {
      final message = IppMessage(
        code: IppOperation.printJob,
        requestId: 42,
        groups: [
          IppGroup(IppGroupTag.operation, [
            IppAttribute.single(
              'attributes-charset',
              IppValueTag.charset,
              'utf-8',
            ),
            IppAttribute.single(
              'printer-uri',
              IppValueTag.uri,
              'ipp://p/ipp/print',
            ),
            IppAttribute.all(
              'requested-attributes',
              IppValueTag.keyword,
              const ['printer-state', 'media-supported'],
            ),
          ]),
          IppGroup(IppGroupTag.job, [
            IppAttribute.single('copies', IppValueTag.integer, 3),
            IppAttribute.single('collate', IppValueTag.boolean, true),
            IppAttribute.single('draft', IppValueTag.boolean, false),
            IppAttribute.single('print-quality', IppValueTag.enumeration, 5),
            IppAttribute.all('page-ranges', IppValueTag.rangeOfInteger, const [
              IppRange(1, 3),
              IppRange(7, 9),
            ]),
            IppAttribute.single(
              'blob',
              IppValueTag.octetString,
              Uint8List.fromList([1, 2, 3]),
            ),
            IppAttribute.single('nothing', IppValueTag.noValue, null),
          ]),
        ],
      );

      final decoded = decodeIpp(encodeIpp(message));
      final operation = decoded.message.group(IppGroupTag.operation)!;
      final job = decoded.message.group(IppGroupTag.job)!;

      expect(decoded.message.code, IppOperation.printJob);
      expect(decoded.message.requestId, 42);
      expect(decoded.message.majorVersion, 2);
      expect(decoded.message.minorVersion, 0);
      expect(decoded.data, isEmpty);
      expect(operation['attributes-charset']!.first, 'utf-8');
      expect(operation['requested-attributes']!.strings, [
        'printer-state',
        'media-supported',
      ]);
      expect(job['copies']!.first, 3);
      expect(job['collate']!.first, isTrue);
      expect(job['draft']!.first, isFalse);
      expect(job['print-quality']!.integers, [5]);
      expect(job['page-ranges']!.values.map((v) => v.value), const [
        IppRange(1, 3),
        IppRange(7, 9),
      ]);
      expect(job['blob']!.first, [1, 2, 3]);
      expect(job['nothing']!.first, isNull);
      expect(job['missing'], isNull);
      expect(decoded.message.group(IppGroupTag.printer), isNull);
    });

    test('keep the bytes that follow the attributes', () {
      final bytes = (_Raw()..header()).end([9, 8, 7]);

      expect(decodeIpp(bytes).data, [9, 8, 7]);
    });

    test('resolutions survive, in either unit', () {
      final message = IppMessage(
        code: 0,
        requestId: 1,
        groups: [
          IppGroup(IppGroupTag.printer, [
            IppAttribute.all(
              'printer-resolution-supported',
              IppValueTag.resolution,
              const [
                IppResolution(300, 600),
                IppResolution(118, 118, perInch: false),
              ],
            ),
          ]),
        ],
      );

      final decoded = decodeIpp(encodeIpp(message)).message;

      expect(
        decoded
            .group(IppGroupTag.printer)!['printer-resolution-supported']!
            .values
            .map((value) => value.value),
        const [
          IppResolution(300, 600),
          IppResolution(118, 118, perInch: false),
        ],
      );
    });

    test('negative integers survive', () {
      final message = IppMessage(
        code: 0,
        requestId: 1,
        groups: [
          IppGroup(IppGroupTag.printer, [
            IppAttribute.all('marker-levels', IppValueTag.integer, const [
              -2,
              50,
            ]),
          ]),
        ],
      );

      expect(
        decodeIpp(encodeIpp(message))
            .message
            .groups
            .single['marker-levels']!
            .integers,
        [-2, 50],
      );
    });
  });

  group('decodeIpp', () {
    test('reads the value types printers send', () {
      final raw = _Raw()
        ..header()
        ..group(IppGroupTag.printer)
        ..value(IppValueTag.resolution, 'res', [
          ..._Raw.i32(600),
          ..._Raw.i32(600),
          3,
        ])
        ..value(IppValueTag.resolution, '', [
          ..._Raw.i32(118),
          ..._Raw.i32(118),
          4,
        ])
        ..value(IppValueTag.dateTime, 'when', [
          0x07, 0xEA, 10, 7, 12, 30, 15, 0, 0x2B, 0, 0, //
        ])
        ..value(IppValueTag.textWithLanguage, 'info', [
          0, 2, ...utf8.encode('en'), 0, 5, ...utf8.encode('Hello'), //
        ])
        ..value(IppValueTag.nameWithLanguage, 'short', [0, 0])
        ..value(IppValueTag.unsupported, 'gone', [])
        ..value(IppValueTag.unknown, 'who-knows', []);
      final group = decodeIpp(raw.end()).message.groups.single;

      final resolutions = group['res']!.values.map(
        (v) => v.value! as IppResolution,
      );
      expect(resolutions.first, const IppResolution(600, 600));
      expect(resolutions.first.dpi, 600);
      expect(resolutions.last.perInch, isFalse);
      expect(resolutions.last.dpi, 300);
      expect(group['when']!.first, DateTime.utc(2026, 10, 7, 12, 30, 15));
      expect(group['info']!.first, 'Hello');
      expect(group['short']!.first, '');
      expect(group['gone']!.first, isNull);
      expect(group['who-knows']!.first, isNull);
    });

    test('reads a collection, with one nested inside', () {
      final raw = _Raw()
        ..header()
        ..group(IppGroupTag.printer)
        ..value(IppValueTag.beginCollection, 'media-col-default', [])
        ..value(IppValueTag.memberName, '', utf8.encode('media-size'))
        ..value(IppValueTag.beginCollection, '', [])
        ..value(IppValueTag.memberName, '', utf8.encode('x-dimension'))
        ..value(IppValueTag.integer, '', _Raw.i32(21000))
        ..value(IppValueTag.memberName, '', utf8.encode('y-dimension'))
        ..value(IppValueTag.integer, '', _Raw.i32(29700))
        ..value(IppValueTag.endCollection, '', [])
        ..value(IppValueTag.memberName, '', utf8.encode('media-type'))
        ..value(IppValueTag.keyword, '', utf8.encode('stationery'))
        ..value(IppValueTag.keyword, '', utf8.encode('photographic'))
        ..value(IppValueTag.endCollection, '', [])
        ..value(IppValueTag.keyword, 'after', utf8.encode('still-read'));
      final group = decodeIpp(raw.end()).message.groups.single;

      final media =
          group['media-col-default']!.first! as Map<String, IppAttribute>;
      final size = media['media-size']!.first! as Map<String, IppAttribute>;
      expect(size['x-dimension']!.first, 21000);
      expect(size['y-dimension']!.first, 29700);
      expect(media['media-type']!.strings, ['stationery', 'photographic']);
      expect(group['after']!.first, 'still-read');
    });

    test('ignores a collection value that comes before any member name', () {
      final raw = _Raw()
        ..header()
        ..group(IppGroupTag.printer)
        ..value(IppValueTag.beginCollection, 'odd', [])
        ..value(IppValueTag.keyword, '', utf8.encode('stray'))
        ..value(IppValueTag.endCollection, '', []);

      final odd = decodeIpp(raw.end()).message.groups.single['odd']!.first;
      expect(odd, isEmpty);
    });

    test('treats a value of the wrong size as missing', () {
      final raw = _Raw()
        ..header()
        ..group(IppGroupTag.printer)
        ..value(IppValueTag.integer, 'int', [1, 2])
        ..value(IppValueTag.rangeOfInteger, 'range', [1])
        ..value(IppValueTag.resolution, 'res', [1])
        ..value(IppValueTag.dateTime, 'when', [1])
        ..value(IppValueTag.boolean, 'flag', [])
        ..value(IppValueTag.textWithLanguage, 'text', [0, 9, 1, 2]);
      final group = decodeIpp(raw.end()).message.groups.single;

      expect(group['int']!.first, isNull);
      expect(group['int']!.integers, isEmpty);
      expect(group['range']!.first, isNull);
      expect(group['res']!.first, isNull);
      expect(group['when']!.first, isNull);
      expect(group['flag']!.first, isFalse);
      expect(group['text']!.first, '');
    });

    test('separates the jobs of a Get-Jobs answer', () {
      final raw = _Raw()
        ..header()
        ..group(IppGroupTag.job)
        ..value(IppValueTag.integer, 'job-id', _Raw.i32(1))
        ..group(IppGroupTag.job)
        ..value(IppValueTag.integer, 'job-id', _Raw.i32(2));
      final message = decodeIpp(raw.end()).message;

      expect(message.groupsOf(IppGroupTag.job).map((g) => g['job-id']!.first), [
        1,
        2,
      ]);
    });

    test('rejects a message that ends early', () {
      final whole = encodeIpp(IppMessage(code: 0, requestId: 1));

      expect(
        () => decodeIpp(Uint8List.sublistView(whole, 0, whole.length - 1)),
        throwsA(isA<IppFormatException>()),
      );
      expect(() => decodeIpp(Uint8List(3)), throwsA(isA<IppFormatException>()));
    });

    test('rejects an attribute outside any group', () {
      final raw = _Raw()
        ..header()
        ..value(IppValueTag.keyword, 'loose', utf8.encode('x'));

      expect(() => decodeIpp(raw.end()), throwsA(isA<IppFormatException>()));
    });

    test('rejects a web page', () {
      final page = Uint8List.fromList(
        utf8.encode('<html><body>Printer</body></html>'),
      );

      expect(() => decodeIpp(page), throwsA(isA<IppFormatException>()));
    });
  });

  group('values', () {
    test('ranges and resolutions compare and print by value', () {
      expect(const IppRange(1, 5), const IppRange(1, 5));
      expect(const IppRange(1, 5).hashCode, const IppRange(1, 5).hashCode);
      expect(const IppRange(1, 5), isNot(const IppRange(1, 6)));
      expect('${const IppRange(1, 5)}', '1-5');

      expect(const IppResolution(600, 600), const IppResolution(600, 600));
      expect(
        const IppResolution(600, 600).hashCode,
        const IppResolution(600, 600).hashCode,
      );
      expect(
        const IppResolution(600, 600),
        isNot(const IppResolution(600, 600, perInch: false)),
      );
      expect('${const IppResolution(600, 300)}', '600x300dpi');
      expect('${const IppResolution(118, 118, perInch: false)}', '118x118dpcm');
      expect('${const IppValue(IppValueTag.keyword, 'auto')}', 'auto');
      expect(const IppAttribute('empty', []).first, isNull);
    });

    test('status codes have names', () {
      expect(IppStatus.nameOf(IppStatus.ok), 'successful-ok');
      expect(
        IppStatus.nameOf(IppStatus.serverErrorServiceUnavailable),
        'server-error-service-unavailable',
      );
      expect(IppStatus.nameOf(0x04FF), '0x04ff');
    });
  });
}
