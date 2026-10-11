import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printerhub/theme/cubit/text_size_cubit.dart';

/// Makes every word under it as large as the person chose: the phone's
/// own text size, times the app's. Goes around the whole app, so no
/// screen has to know.
class TextSizeScope extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final factor = context.select<TextSizeCubit, double>(
      (cubit) => cubit.factor,
    );
    final media = MediaQuery.of(context);
    // What the phone asks for a line of ordinary text, as a multiple.
    final phone = media.textScaler.scale(14) / 14;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(phone * factor)),
      child: child,
    );
  }
}
