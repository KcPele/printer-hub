import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/pictures/cubit/picture_cubit.dart';
import 'package:printerhub/pictures/picture_edits.dart';

/// Opens [picture] full screen, as a photo is opened in a gallery. With
/// [editable] it can be cropped, highlighted, and turned there. Answers
/// with the changed picture when the person saves one, and with null when
/// they only looked.
///
/// Any small picture in the app opens this way: a page of a scan, a page
/// of an open document, a photo chosen for a sheet.
Future<File?> openPicture(
  BuildContext context,
  File picture, {
  bool editable = true,
}) {
  return Navigator.of(context, rootNavigator: true).push<File>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PictureViewPage(picture: picture, editable: editable),
    ),
  );
}

/// A picture, full screen: pinched larger and moved about, and with
/// [editable], changed.
class PictureViewPage extends StatelessWidget {
  const new({required this.picture, this.editable = true, super.key});

  final File picture;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = PictureCubit(picture: picture);
        unawaited(cubit.load());
        return cubit;
      },
      child: PictureViewView(editable: editable),
    );
  }
}

/// A picture is looked at on black, with white signs over it, whatever
/// the theme: as a photo is in a gallery.
const Color _ground = Colors.black;
const Color _sign = Colors.white;

class PictureViewView extends StatelessWidget {
  const new({required this.editable, super.key});

  final bool editable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PictureCubit>();
    final state = context.watch<PictureCubit>().state;
    final looking = state.tool == PictureTool.none;

    return Scaffold(
      backgroundColor: _ground,
      appBar: AppBar(
        backgroundColor: _ground,
        foregroundColor: _sign,
        actions: [
          if (state.changed && looking) ...[
            IconButton(
              tooltip: l10n.pictureUndo,
              onPressed: state.working ? null : cubit.undo,
              icon: const Icon(Icons.undo),
            ),
            TextButton(
              onPressed: state.working
                  ? null
                  : () => Navigator.of(context).pop(state.file),
              style: TextButton.styleFrom(foregroundColor: _sign),
              child: Text(l10n.pictureSave),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.failed && !state.ready
                  ? Center(
                      child: Text(
                        l10n.pictureFailed,
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: _sign,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : !state.ready
                  ? const Center(child: CircularProgressIndicator(color: _sign))
                  : _Picture(state: state),
            ),
            if (state.failed && state.ready)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  l10n.pictureChangeFailed,
                  style: context.textTheme.bodyMedium?.copyWith(color: _sign),
                ),
              ),
            if (editable && state.ready) _Tools(state: state),
          ],
        ),
      ),
    );
  }
}

/// The picture itself, as large as the screen lets it be, with what the
/// tool in hand draws over it.
class _Picture extends StatelessWidget {
  const new({required this.state});

  final PictureState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PictureCubit>();
    final picture = AspectRatio(
      aspectRatio: state.width / state.height,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, box.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                state.file,
                key: ValueKey(state.file.path),
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
              if (state.tool == PictureTool.crop)
                _Crop(crop: state.crop, size: size, onChanged: cubit.cropTo),
              if (state.tool == PictureTool.highlight)
                _Held(
                  key: const ValueKey('picture-highlighter'),
                  onDown: (touch) => cubit.begin(
                    Point(
                      touch.localPosition.dx / size.width,
                      touch.localPosition.dy / size.height,
                    ),
                  ),
                  onMove: (touch) => cubit.drawTo(
                    Point(
                      touch.localPosition.dx / size.width,
                      touch.localPosition.dy / size.height,
                    ),
                  ),
                  child: CustomPaint(painter: _Ink(strokes: state.strokes)),
                ),
              if (state.working)
                const ColoredBox(
                  color: Colors.black45,
                  child: Center(child: CircularProgressIndicator(color: _sign)),
                ),
            ],
          );
        },
      ),
    );

    return Center(
      // Looked at, it is pinched larger and moved about. With a tool in
      // hand it keeps still, so a touch goes to the tool.
      child: state.tool == PictureTool.none
          ? InteractiveViewer(maxScale: 6, child: picture)
          : picture,
    );
  }
}

/// The box around the part of the picture that is kept: its corners are
/// dragged to size it, its middle to move it.
class _Crop extends StatelessWidget {
  const new({required this.crop, required this.size, required this.onChanged});

  final CropBox crop;
  final Size size;
  final ValueChanged<CropBox> onChanged;

  static const double _handle = 44;

  @override
  Widget build(BuildContext context) {
    final box = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    Widget corner(String name, Offset at, CropBox Function(Offset) moved) {
      return Positioned(
        left: at.dx - _handle / 2,
        top: at.dy - _handle / 2,
        width: _handle,
        height: _handle,
        child: GestureDetector(
          key: ValueKey('crop-$name'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (drag) => onChanged(
            moved(
              Offset(drag.delta.dx / size.width, drag.delta.dy / size.height),
            ),
          ),
          child: const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(color: _sign, shape: BoxShape.circle),
              child: SizedBox.square(dimension: 18),
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // What is cut away is dimmed.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _Dim(box: box)),
          ),
        ),
        Positioned.fromRect(
          rect: box,
          child: GestureDetector(
            key: const ValueKey('crop-box'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (drag) => onChanged(
              crop.carried(
                drag.delta.dx / size.width,
                drag.delta.dy / size.height,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: _sign, width: 2),
              ),
            ),
          ),
        ),
        corner(
          'top-left',
          box.topLeft,
          (by) => crop.moved(left: by.dx, top: by.dy),
        ),
        corner(
          'top-right',
          box.topRight,
          (by) => crop.moved(right: by.dx, top: by.dy),
        ),
        corner(
          'bottom-left',
          box.bottomLeft,
          (by) => crop.moved(left: by.dx, bottom: by.dy),
        ),
        corner(
          'bottom-right',
          box.bottomRight,
          (by) => crop.moved(right: by.dx, bottom: by.dy),
        ),
      ],
    );
  }
}

/// Dims everything outside [box].
class _Dim extends CustomPainter {
  const new({required this.box});

  final Rect box;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(box),
      ),
      Paint()..color = Colors.black54,
    );
  }

  @override
  bool shouldRepaint(_Dim old) => old.box != box;
}

/// Paints the highlighter's lines as they are drawn.
class _Ink extends CustomPainter {
  const new({required this.strokes});

  final List<PictureStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      // The yellow of a highlighter, in every theme.
      ..color = Colors.yellow.withValues(alpha: 0.45)
      ..strokeWidth = min(size.width, size.height) * highlighterWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      final path = Path()
        ..moveTo(stroke.first.x * size.width, stroke.first.y * size.height);
      for (final point in stroke) {
        path.lineTo(point.x * size.width, point.y * size.height);
      }
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(_Ink old) => old.strokes != strokes;
}

/// Something a finger takes hold of and keeps, so nothing under it moves
/// while it is drawn on.
class _Held extends StatelessWidget {
  const new({
    required this.onDown,
    required this.onMove,
    required this.child,
    super.key,
  });

  final void Function(PointerDownEvent touch) onDown;
  final void Function(PointerMoveEvent touch) onMove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (_) {},
            ),
      },
      child: Listener(
        onPointerDown: onDown,
        onPointerMove: onMove,
        child: child,
      ),
    );
  }
}

/// What can be done to the picture, along the foot of the screen: the
/// tools, or with one in hand, using it or putting it down.
class _Tools extends StatelessWidget {
  const new({required this.state});

  final PictureState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PictureCubit>();
    final style = TextButton.styleFrom(foregroundColor: _sign);
    Widget tool(IconData icon, String label, VoidCallback onPressed) {
      return Expanded(
        child: TextButton(
          onPressed: state.working ? null : onPressed,
          style: style,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(height: AppSpacing.xxs),
              Text(label),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: state.tool == PictureTool.none
            ? [
                tool(
                  Icons.crop,
                  l10n.pictureCrop,
                  () => cubit.choose(PictureTool.crop),
                ),
                tool(
                  Icons.border_color_outlined,
                  l10n.pictureHighlight,
                  () => cubit.choose(PictureTool.highlight),
                ),
                tool(Icons.rotate_right, l10n.pictureTurn, cubit.turn),
              ]
            : [
                tool(
                  Icons.close,
                  l10n.pictureCancel,
                  () => cubit.choose(PictureTool.none),
                ),
                tool(Icons.check, l10n.pictureApply, cubit.apply),
              ],
      ),
    );
  }
}
