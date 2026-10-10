import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/scan/cubit/sign_cubit.dart';
import 'package:printerhub/scan/scan_output.dart';
import 'package:printerhub/scan/signature.dart';

/// Signs a page of a scan. Draw a signature, or use the one kept on this
/// phone, then drag it to where it belongs. Closes with the signature
/// where it was put, or with nothing.
class SignPage extends StatelessWidget {
  const new({required this.pages, required this.paper, this.placed, super.key});

  /// The scan's pages, a sheet each.
  final List<File> pages;

  /// The paper the scan is saved on.
  final ScanPaper paper;

  /// Where the signature is now, when it is being moved.
  final PlacedSignature? placed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = SignCubit(
          store: context.read<SignatureStore>(),
          pages: pages.length,
          sheetAspect: paper.widthMm / paper.heightMm,
          placed: placed,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: SignView(pages: pages, paper: paper),
    );
  }
}

class SignView extends StatelessWidget {
  const new({required this.pages, required this.paper, super.key});

  final List<File> pages;
  final ScanPaper paper;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SignCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.signTitle)),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  AppSpacing.xxl,
                ),
                child: state.signature == null
                    ? const _Pad()
                    : _Place(pages: pages, paper: paper),
              ),
      ),
    );
  }
}

/// Something a finger takes hold of and keeps: the page under it does not
/// scroll while it is being drawn on or dragged.
class _Held extends StatelessWidget {
  const new({
    required this.onMove,
    required this.child,
    this.onDown,
    super.key,
  });

  final void Function(PointerDownEvent touch)? onDown;
  final void Function(PointerMoveEvent touch) onMove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        // Wins the touch at once, before the page can take it as a scroll.
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

/// How tall the pad is to its width.
const double _padAspect = 2;

/// The pad a signature is drawn on with a finger.
class _Pad extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<SignCubit>();
    final state = context.watch<SignCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.signDrawLead,
          style: context.textTheme.bodyLarge?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            final height = width / _padAspect;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: context.shapes.cardRadius,
                  child: _Held(
                    key: const ValueKey('signature-pad'),
                    onDown: (touch) => cubit.begin(
                      Point(touch.localPosition.dx, touch.localPosition.dy),
                    ),
                    onMove: (touch) => cubit.drawTo(
                      Point(touch.localPosition.dx, touch.localPosition.dy),
                    ),
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: _Ink(
                        strokes: state.strokes,
                        paper: colors.surfaceMuted,
                        ink: colors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSubmitButton(
                  label: l10n.signUse,
                  onPressed: state.drawn
                      ? () => cubit.use(width: width, height: height)
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: state.drawn ? cubit.wipe : null,
                  child: Text(l10n.signClear),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Paints the lines drawn on the pad.
class _Ink extends CustomPainter {
  const new({required this.strokes, required this.paper, required this.ink});

  final List<SignatureStroke> strokes;
  final Color paper;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final pen = Paint()
      ..color = ink
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length; i++) {
        final from = stroke[max(0, i - 1)];
        canvas.drawLine(
          Offset(from.x, from.y),
          Offset(stroke[i].x, stroke[i].y),
          pen,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Ink old) => old.strokes != strokes;
}

/// The sheet with the signature on it, to be dragged into place.
class _Place extends StatelessWidget {
  const new({required this.pages, required this.paper});

  final List<File> pages;
  final ScanPaper paper;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<SignCubit>();
    final state = context.watch<SignCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.signPlaceLead,
          style: context.textTheme.bodyLarge?.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        // The sheet as it will be saved: the paper, the page fitted on it.
        AspectRatio(
          aspectRatio: paper.widthMm / paper.heightMm,
          child: LayoutBuilder(
            builder: (context, box) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: colors.outline),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(
                        pages[state.page],
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_outlined),
                      ),
                    ),
                    Positioned(
                      left: state.x * box.maxWidth,
                      top: state.y * box.maxHeight,
                      width: state.width * box.maxWidth,
                      child: _Held(
                        key: const ValueKey('placed-signature'),
                        onMove: (drag) => cubit.move(
                          drag.localDelta.dx / box.maxWidth,
                          drag.localDelta.dy / box.maxHeight,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.emphasis),
                          ),
                          // Its shape is known before its picture is
                          // drawn, so it can be taken hold of at once.
                          child: AspectRatio(
                            aspectRatio: state.aspect,
                            // Read as a picture before it got here, so
                            // there is nothing to show in its place.
                            child: Image.memory(
                              state.signature!,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.signSize, style: context.textTheme.bodyLarge),
        Slider(
          value: state.width,
          min: SignCubit.minWidth,
          max: SignCubit.maxWidth,
          onChanged: cubit.resize,
        ),
        if (pages.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<int>(
            key: ValueKey(state.page),
            initialValue: state.page,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.signPage),
            items: [
              for (var page = 0; page < pages.length; page++)
                DropdownMenuItem(
                  value: page,
                  child: Text(l10n.scanPageNumber(page + 1)),
                ),
            ],
            onChanged: (page) => cubit.onPage(page!),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppSubmitButton(
          label: l10n.signPlace,
          onPressed: () => Navigator.of(context).pop(cubit.placed),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: cubit.redraw, child: Text(l10n.signRedraw)),
      ],
    );
  }
}
