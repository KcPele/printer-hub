import 'package:printer_protocols/printer_protocols.dart';
import 'package:test/test.dart';

IppPrinterAttributes _printer({
  List<String> formats = const [],
  bool color = true,
  List<String> pwgTypes = const [],
  List<int> pwgDpi = const [],
  String? sheetBack,
  List<String>? urf,
}) {
  return IppPrinterAttributes(
    IppGroup(IppGroupTag.printer, [
      IppAttribute.all(
        'document-format-supported',
        IppValueTag.mimeMediaType,
        formats,
      ),
      IppAttribute.single('color-supported', IppValueTag.boolean, color),
      IppAttribute.all(
        'pwg-raster-document-type-supported',
        IppValueTag.keyword,
        pwgTypes,
      ),
      IppAttribute.all(
        'pwg-raster-document-resolution-supported',
        IppValueTag.resolution,
        [for (final dpi in pwgDpi) IppResolution(dpi, dpi)],
      ),
      if (sheetBack != null)
        IppAttribute.single(
          'pwg-raster-document-sheet-back',
          IppValueTag.keyword,
          sheetBack,
        ),
      if (urf != null)
        IppAttribute.all('urf-supported', IppValueTag.keyword, urf),
    ]),
  );
}

void main() {
  const pdf = 'application/pdf';
  const jpeg = 'image/jpeg';
  const pwg = 'image/pwg-raster';
  const urf = 'image/urf';

  group('PwgMedia', () {
    test('reads the measurements in a paper name', () {
      final a4 = PwgMedia.parse('iso_a4_210x297mm')!;
      final letter = PwgMedia.parse('na_letter_8.5x11in')!;

      expect([a4.widthHundredthsMm, a4.heightHundredthsMm], [21000, 29700]);
      expect(
        [letter.widthHundredthsMm, letter.heightHundredthsMm],
        [21590, 27940],
      );
      expect([a4.widthPx(300), a4.heightPx(300)], [2480, 3508]);
      expect([letter.widthPx(600), letter.heightPx(600)], [5100, 6600]);
      expect('$a4', 'iso_a4_210x297mm');
    });

    test('has nothing for a name without measurements', () {
      expect(PwgMedia.parse('letterhead'), isNull);
      expect(PwgMedia.parse('custom_0x0mm'), isNull);
      expect(PwgMedia.parse('iso_a4_210x297cm'), isNull);
    });

    test('is equal by value', () {
      final a = PwgMedia.parse('iso_a4_210x297mm');
      final b = PwgMedia.parse('iso_a4_210x297mm');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(PwgMedia.parse('iso_a5_148x210mm')));
    });
  });

  group('choosePrintFormat', () {
    test('sends a PDF as it is to a printer that reads PDF', () {
      final choice = choosePrintFormat(
        _printer(formats: [pdf, pwg, urf], pwgTypes: ['srgb_8'], pwgDpi: [300]),
        sourceType: pdf,
      );

      expect(choice, const DirectFormat(pdf));
      expect(choice!.mimeType, pdf);
      expect(choice.hashCode, const DirectFormat(pdf).hashCode);
      expect('$choice', 'DirectFormat(application/pdf)');
    });

    test('sends a photo as it is to a printer that reads JPEG', () {
      expect(
        choosePrintFormat(_printer(formats: [jpeg, pwg]), sourceType: jpeg),
        const DirectFormat(jpeg),
      );
    });

    test('draws the pages for a printer that does not read PDF', () {
      final choice = choosePrintFormat(
        _printer(
          formats: [jpeg, pwg, urf],
          pwgTypes: ['black_1', 'sgray_8', 'srgb_8'],
          pwgDpi: [600, 300],
          sheetBack: 'rotated',
        ),
        sourceType: pdf,
      );

      expect(
        choice,
        const RasterTarget(
          format: RasterFormat.pwg,
          color: RasterColor.srgb8,
          resolutionDpi: 300,
          sheetBack: SheetBack.rotated,
        ),
      );
      expect(choice!.mimeType, pwg);
      expect('$choice', 'RasterTarget(pwg, srgb8, 300 dpi, rotated)');
    });

    test('draws in grey when asked, or when that is all there is', () {
      final colorPrinter = _printer(
        formats: [pwg],
        pwgTypes: ['sgray_8', 'srgb_8'],
        pwgDpi: [300],
      );
      final monoPrinter = _printer(
        formats: [pwg],
        color: false,
        pwgTypes: ['sgray_8', 'srgb_8'],
        pwgDpi: [300],
      );
      RasterColor colorOf(PrintFormat? choice) =>
          (choice! as RasterTarget).color;

      expect(
        colorOf(choosePrintFormat(colorPrinter, sourceType: pdf, color: false)),
        RasterColor.sgray8,
      );
      expect(
        colorOf(choosePrintFormat(monoPrinter, sourceType: pdf)),
        RasterColor.sgray8,
      );
      // A printer that only lists colour is sent colour, even for grey.
      expect(
        colorOf(
          choosePrintFormat(
            _printer(formats: [pwg], pwgTypes: ['srgb_8'], pwgDpi: [300]),
            sourceType: pdf,
            color: false,
          ),
        ),
        RasterColor.srgb8,
      );
    });

    test('prefers 300 dpi, then the next above, then the best there is', () {
      int dpiFor(List<int> offered) {
        final choice = choosePrintFormat(
          _printer(formats: [pwg], pwgTypes: ['sgray_8'], pwgDpi: offered),
          sourceType: pdf,
        );
        return (choice! as RasterTarget).resolutionDpi;
      }

      expect(dpiFor([150, 300, 600]), 300);
      expect(dpiFor([1200, 600]), 600);
      expect(dpiFor([203]), 203);
    });

    test('uses Apple Raster for a printer that only has AirPrint', () {
      final choice = choosePrintFormat(
        _printer(
          formats: [urf],
          urf: ['V1.4', 'W8', 'SRGB24', 'RS600-300', 'DM3', 'CP255'],
        ),
        sourceType: pdf,
      );

      expect(
        choice,
        const RasterTarget(
          format: RasterFormat.urf,
          color: RasterColor.srgb8,
          resolutionDpi: 300,
          sheetBack: SheetBack.rotated,
        ),
      );
    });

    test('uses Apple Raster when the PWG Raster on offer is no use', () {
      // Only one bit per pixel, which the app does not draw.
      final choice = choosePrintFormat(
        _printer(
          formats: [pwg, urf],
          pwgTypes: ['black_1'],
          pwgDpi: [600],
          urf: ['W8', 'RS600'],
        ),
        sourceType: pdf,
      );

      expect(
        choice,
        const RasterTarget(
          format: RasterFormat.urf,
          color: RasterColor.sgray8,
          resolutionDpi: 600,
        ),
      );
    });

    test('assumes grey at 300 dpi for AirPrint that says nothing more', () {
      expect(
        choosePrintFormat(_printer(formats: [urf]), sourceType: pdf),
        const RasterTarget(
          format: RasterFormat.urf,
          color: RasterColor.sgray8,
          resolutionDpi: 300,
        ),
      );
    });

    test('has no answer for a printer that takes nothing the app makes', () {
      expect(
        choosePrintFormat(
          _printer(
            formats: ['application/vnd.hp-PCL', 'application/postscript'],
          ),
          sourceType: pdf,
        ),
        isNull,
      );
      // PWG Raster without a resolution cannot be drawn for.
      expect(
        choosePrintFormat(
          _printer(formats: [pwg], pwgTypes: ['sgray_8']),
          sourceType: pdf,
        ),
        isNull,
      );
      // A PDF printer cannot be sent a Word file as it is.
      expect(
        choosePrintFormat(_printer(formats: [pdf]), sourceType: 'text/plain'),
        isNull,
      );
    });

    test('a target describes the document it will be drawn as', () {
      const target = RasterTarget(
        format: RasterFormat.pwg,
        color: RasterColor.sgray8,
        resolutionDpi: 300,
        sheetBack: SheetBack.flipped,
      );

      final document = target.document(
        media: PwgMedia.parse('iso_a4_210x297mm')!,
        pageCount: 4,
        sides: RasterSides.twoSidedLongEdge,
        quality: 4,
      );

      expect([document.widthPx, document.heightPx], [2480, 3508]);
      expect(document.pageCount, 4);
      expect(document.mediaName, 'iso_a4_210x297mm');
      expect(document.sheetBack, SheetBack.flipped);
      expect(document.quality, 4);
      expect(document.backUpsideDown, isTrue);
      expect(target.hashCode, isNot(const DirectFormat('a').hashCode));
      expect(
        target,
        isNot(
          const RasterTarget(
            format: RasterFormat.pwg,
            color: RasterColor.sgray8,
            resolutionDpi: 600,
          ),
        ),
      );
    });
  });

  group('what a printer says about raster', () {
    test('reads the Apple Raster codes', () {
      final all = UrfSupport.parse(const [
        'w8',
        'SRGB24',
        'RS300-600-1200',
        'DM2',
      ]);
      expect(all.color, isTrue);
      expect(all.resolutionsDpi, [300, 600, 1200]);
      expect(all.sheetBack, SheetBack.flipped);

      expect(UrfSupport.parse(const ['DM4']).sheetBack, SheetBack.manualTumble);
      expect(UrfSupport.parse(const ['DM1']).sheetBack, SheetBack.normal);
      // Resolutions that cannot be read leave the usual one.
      expect(UrfSupport.parse(const ['RSx']).resolutionsDpi, [300]);
      expect(UrfSupport.parse(const []).color, isFalse);
    });

    test('reads the PWG Raster attributes', () {
      final printer = IppPrinterAttributes(
        IppGroup(IppGroupTag.printer, [
          IppAttribute.all(
            'pwg-raster-document-resolution-supported',
            IppValueTag.resolution,
            const [
              IppResolution(600, 600),
              IppResolution(300, 300),
              // Not square: the app draws square pixels.
              IppResolution(600, 1200),
            ],
          ),
          IppAttribute.all(
            'uri-authentication-supported',
            IppValueTag.keyword,
            const ['none', 'digest'],
          ),
          IppAttribute.all('media-col-supported', IppValueTag.keyword, const [
            'media-size',
            'media-source',
          ]),
          IppAttribute.all(
            'job-creation-attributes-supported',
            IppValueTag.keyword,
            const ['copies', 'sides'],
          ),
        ]),
      );

      expect(printer.pwgRasterResolutionsDpi, [300, 600]);
      expect(printer.pwgRasterSheetBack, SheetBack.normal);
      expect(printer.pwgRasterTypes, isEmpty);
      expect(printer.authenticationSchemes, ['none', 'digest']);
      expect(printer.requiresAuthentication, isTrue);
      expect(printer.mediaColMembers, ['media-size', 'media-source']);
      expect(printer.jobCreationAttributes, ['copies', 'sides']);
      expect(printer.urf.resolutionsDpi, [300]);
      expect(
        IppPrinterAttributes(IppGroup(IppGroupTag.printer))
            .requiresAuthentication,
        isFalse,
      );
    });
  });
}
