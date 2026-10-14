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
      icon: Icons.draw_outlined,
      title: l10n.toolsSign,
      body: l10n.toolsSignBody,
      onTap: () => context.push(AppRoutes.signPdf),
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

/// The tools that are planned and not built yet, shown greyed so people
/// know what is on the way. None can be opened. With [ai], those that will
/// need an AI service; without, those that will work on the phone.
///
/// A tool leaves this list, and joins [toolTiles], the day it works.
List<Widget> comingTools(BuildContext context, {required bool ai}) {
  final l10n = context.l10n;
  return ai
      ? [
          ToolTile.planned(
            icon: Icons.translate_outlined,
            title: l10n.toolsSoonTranslate,
            body: l10n.toolsSoonTranslateBody,
          ),
          ToolTile.planned(
            icon: Icons.auto_awesome_outlined,
            title: l10n.toolsSoonChat,
            body: l10n.toolsSoonChatBody,
          ),
          ToolTile.planned(
            icon: Icons.lightbulb_outline,
            title: l10n.toolsSoonSolver,
            body: l10n.toolsSoonSolverBody,
          ),
          ToolTile.planned(
            icon: Icons.article_outlined,
            title: l10n.toolsSoonWord,
            body: l10n.toolsSoonWordBody,
          ),
          ToolTile.planned(
            icon: Icons.table_chart_outlined,
            title: l10n.toolsSoonExcel,
            body: l10n.toolsSoonExcelBody,
          ),
          ToolTile.planned(
            icon: Icons.slideshow_outlined,
            title: l10n.toolsSoonSlides,
            body: l10n.toolsSoonSlidesBody,
          ),
          ToolTile.planned(
            icon: Icons.functions_outlined,
            title: l10n.toolsSoonFormula,
            body: l10n.toolsSoonFormulaBody,
          ),
          ToolTile.planned(
            icon: Icons.auto_fix_high_outlined,
            title: l10n.toolsSoonErase,
            body: l10n.toolsSoonEraseBody,
          ),
          ToolTile.planned(
            icon: Icons.cleaning_services_outlined,
            title: l10n.toolsSoonMarks,
            body: l10n.toolsSoonMarksBody,
          ),
          ToolTile.planned(
            icon: Icons.photo_filter_outlined,
            title: l10n.toolsSoonRestore,
            body: l10n.toolsSoonRestoreBody,
          ),
          ToolTile.planned(
            icon: Icons.pin_outlined,
            title: l10n.toolsSoonCount,
            body: l10n.toolsSoonCountBody,
          ),
        ]
      : [
          ToolTile.planned(
            icon: Icons.badge_outlined,
            title: l10n.toolsSoonIdPhoto,
            body: l10n.toolsSoonIdPhotoBody,
          ),
          ToolTile.planned(
            icon: Icons.menu_book_outlined,
            title: l10n.toolsSoonBook,
            body: l10n.toolsSoonBookBody,
          ),
          ToolTile.planned(
            icon: Icons.manage_search_outlined,
            title: l10n.toolsSoonSearchable,
            body: l10n.toolsSoonSearchableBody,
          ),
          ToolTile.planned(
            icon: Icons.lock_outline,
            title: l10n.toolsSoonLock,
            body: l10n.toolsSoonLockBody,
          ),
        ];
}
