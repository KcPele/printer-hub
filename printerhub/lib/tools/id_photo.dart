import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printerhub/pictures/picture_edits.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/photo_sheet.dart';

/// An official photo size: what a passport or visa office asks for.
class IdPhotoSize extends Equatable {
  const new(this.key, this.widthMm, this.heightMm);

  /// Names it to the words for it, such as `35x45`.
  final String key;
  final double widthMm;
  final double heightMm;

  /// Width over height.
  double get aspect => widthMm / heightMm;

  @override
  List<Object?> get props => [key, widthMm, heightMm];
}

/// The sizes offered, the most asked for first.
const List<IdPhotoSize> idPhotoSizes = [
  // Most passports, and Schengen and UK visas.
  IdPhotoSize('35x45', 35, 45),
  // US passports and visas: 2 by 2 inches.
  IdPhotoSize('51x51', 51, 51),
  // Visas for China.
  IdPhotoSize('33x48', 33, 48),
  // Canadian passports.
  IdPhotoSize('50x70', 50, 70),
];

/// The part of a picture [width] by [height] that fills a frame of
/// [aspect] (width over height): as much of it as fits, from the middle.
CropBox coverBox({
  required int width,
  required int height,
  required double aspect,
}) {
  final picture = width / height;
  if (picture > aspect) {
    final part = aspect / picture;
    return CropBox(
      left: (1 - part) / 2,
      top: 0,
      right: (1 + part) / 2,
      bottom: 1,
    );
  }
  final part = picture / aspect;
  return CropBox(
    left: 0,
    top: (1 - part) / 2,
    right: 1,
    bottom: (1 + part) / 2,
  );
}

/// A sheet of [paper] filled with [photo], already framed to [size], set
/// at that size, and written as a PDF to [directory]. Printed at full
/// size, each photo comes out at the size asked for.
Future<File> idPhotoSheet({
  required Uint8List photo,
  required IdPhotoSize size,
  required ScanPaper paper,
  required String name,
  required Directory directory,
}) async {
  final document = pw.Document(title: name)
    ..addPage(
      copiesSheet(
        picture: pw.MemoryImage(photo),
        paper: paper,
        widthMm: size.widthMm,
        heightMm: size.heightMm,
      ),
    );
  final file = File('${directory.path}/${scanFileName(name)}.pdf');
  await file.writeAsBytes(await document.save(), flush: true);
  return file;
}
