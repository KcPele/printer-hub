import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:printerhub/l10n/l10n.dart';
import 'package:printerhub/pictures/view/picture_view_page.dart';

/// A small picture that opens full screen when it is touched.
///
/// With [onChanged] it can be cropped, highlighted, and turned there, and
/// [onChanged] is handed the picture that was saved. Without it the
/// picture is only looked at.
class OpenablePicture extends StatelessWidget {
  const new({
    required this.picture,
    required this.child,
    this.onChanged,
    super.key,
  });

  final File picture;

  /// The small picture itself.
  final Widget child;
  final ValueChanged<File>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.pictureOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final changed = await openPicture(
            context,
            picture,
            editable: onChanged != null,
          );
          if (changed != null) onChanged?.call(changed);
        },
        child: child,
      ),
    );
  }
}
