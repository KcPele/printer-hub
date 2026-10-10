import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/app/router/app_router.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/tools/widgets/tool_tiles.dart';
import 'package:printerhub/workspace/cubit/features_cubit.dart';

/// Every tool that works right now, in the order they are offered, as
/// tiles. Home shows the first few; the Tools screen shows them all.
///
/// A tool is left out when it cannot work: the camera on a phone without
/// one or in a workspace with it switched off, reading words in a
/// workspace with that switched off. A new tool is added here, and
/// nowhere else, once it works.
///
/// Home leaves out scanning with the phone, with [withScan] false: it
/// offers that among its own actions.
List<Widget> toolTiles(BuildContext context, {bool withScan = true}) {
  final l10n = context.l10n;
  final camera =
      context.read<PageCamera>().available &&
      context.select<FeaturesCubit, bool>(
        (features) => features.enabled('camera_scan'),
      );
  final reads = context.select<FeaturesCubit, bool>(
    (features) => features.enabled('local_ocr'),
  );

  return [
    if (camera && withScan)
      ToolTile(
        icon: Icons.photo_camera_outlined,
        title: l10n.homeActionScan,
        body: l10n.homeActionScanBody,
        onTap: () => context.push(AppRoutes.scan),
      ),
    ToolTile(
      icon: Icons.photo_library_outlined,
      title: l10n.toolsPicturesToPdf,
      body: l10n.toolsPicturesToPdfBody,
      onTap: () => context.push(AppRoutes.picturesToPdf),
    ),
    if (reads)
      ToolTile(
        icon: Icons.text_snippet_outlined,
        title: l10n.toolsText,
        body: l10n.toolsTextBody,
        onTap: () => context.push(AppRoutes.extractText),
      ),
    ToolTile(
      icon: Icons.photo_size_select_large_outlined,
      title: l10n.toolsPhotos,
      body: l10n.toolsPhotosBody,
      onTap: () => context.push(AppRoutes.photoSheet),
    ),
    ToolTile(
      icon: Icons.image_outlined,
      title: l10n.toolsPictures,
      body: l10n.toolsPicturesBody,
      onTap: () => context.push(AppRoutes.pdfToPictures),
    ),
    ToolTile(
      icon: Icons.view_day_outlined,
      title: l10n.toolsLongPicture,
      body: l10n.toolsLongPictureBody,
      onTap: () => context.push(AppRoutes.pdfToLongPicture),
    ),
    ToolTile(
      icon: Icons.merge_outlined,
      title: l10n.toolsMerge,
      body: l10n.toolsMergeBody,
      onTap: () => context.push(AppRoutes.filesToPdf),
    ),
    ToolTile(
      icon: Icons.content_cut_outlined,
      title: l10n.toolsExtract,
      body: l10n.toolsExtractBody,
      onTap: () => context.push(AppRoutes.filesToPdf),
    ),
    ToolTile(
      icon: Icons.grid_view_outlined,
      title: l10n.toolsPerSheet,
      body: l10n.toolsPerSheetBody,
      onTap: () => context.push(AppRoutes.pagesPerSheet),
    ),
    ToolTile(
      icon: Icons.qr_code_scanner_outlined,
      title: l10n.toolsCode,
      body: l10n.toolsCodeBody,
      onTap: () => context.push(AppRoutes.scanCode),
    ),
    ToolTile(
      icon: Icons.qr_code_2_outlined,
      title: l10n.toolsCodeSheet,
      body: l10n.toolsCodeSheetBody,
      onTap: () => context.push(AppRoutes.codeSheet),
    ),
    ToolTile(
      icon: Icons.edit_note_outlined,
      title: l10n.toolsNote,
      body: l10n.toolsNoteBody,
      onTap: () => context.push(AppRoutes.note),
    ),
    ToolTile(
      icon: Icons.calendar_month_outlined,
      title: l10n.toolsPrintable,
      body: l10n.toolsPrintableBody,
      onTap: () => context.push(AppRoutes.printable),
    ),
  ];
}
