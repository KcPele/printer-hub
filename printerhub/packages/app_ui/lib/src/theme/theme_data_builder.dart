import 'package:app_ui/src/theme/app_spacing.dart';
import 'package:app_ui/src/theme/app_theme_tokens.dart';
import 'package:app_ui/src/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Turns a set of tokens into a Material theme.
///
/// Material draws many controls in `colorScheme.primary` on a light surface
/// (text buttons, focus rings, cursors, progress). A brand colour is not
/// always readable there, so the scheme's `primary` is the theme's
/// `emphasis`, and the controls that are brand *fills* are themed one by one
/// below.
ThemeData buildThemeData(AppThemeTokens tokens) {
  final colors = tokens.colors;
  final semantic = tokens.semantic;
  final shapes = tokens.shapes;
  final depth = tokens.depth;

  final textTheme = AppTypography.textTheme(
    fontFamily: tokens.fontFamily,
    color: colors.text,
  );

  final colorScheme = ColorScheme(
    brightness: tokens.brightness,
    primary: colors.emphasis,
    onPrimary: colors.onEmphasis,
    primaryContainer: colors.primary,
    onPrimaryContainer: colors.onPrimary,
    secondary: colors.accent,
    onSecondary: colors.onAccent,
    secondaryContainer: colors.surfaceMuted,
    onSecondaryContainer: colors.text,
    tertiary: colors.accent,
    onTertiary: colors.onAccent,
    error: semantic.error.foreground,
    onError: colors.surface,
    errorContainer: semantic.error.container,
    onErrorContainer: semantic.error.foreground,
    surface: colors.surface,
    onSurface: colors.text,
    onSurfaceVariant: colors.textMuted,
    surfaceContainerLowest: colors.surface,
    surfaceContainerLow: colors.surface,
    surfaceContainer: colors.surfaceMuted,
    surfaceContainerHigh: colors.surfaceMuted,
    surfaceContainerHighest: colors.surfaceMuted,
    inverseSurface: colors.inverseSurface,
    onInverseSurface: colors.onInverseSurface,
    inversePrimary: colors.primary,
    outline: colors.outline,
    outlineVariant: colors.outline,
    surfaceTint: Colors.transparent,
  );

  final buttonShape = RoundedRectangleBorder(borderRadius: shapes.buttonRadius);
  const buttonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
    vertical: AppSpacing.lg,
  );
  const buttonMinimumSize = Size(64, 52);

  OutlineInputBorder fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: shapes.fieldRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    useMaterial3: true,
    brightness: tokens.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.background,
    fontFamily: tokens.fontFamily,
    textTheme: textTheme,
    extensions: [colors, semantic, shapes, depth],
    iconTheme: IconThemeData(color: colors.text),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: buttonShape,
        padding: buttonPadding,
        minimumSize: buttonMinimumSize,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.outline, width: 1.5),
        shape: buttonShape,
        padding: buttonPadding,
        minimumSize: buttonMinimumSize,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.emphasis,
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      elevation: 0,
      highlightElevation: 0,
      shape: buttonShape,
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: shapes.cardRadius,
        side: depth.cardBorder,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      hintStyle: textTheme.bodyLarge?.copyWith(color: colors.textMuted),
      labelStyle: textTheme.bodyLarge?.copyWith(color: colors.textMuted),
      border: fieldBorder(colors.outline),
      enabledBorder: fieldBorder(colors.outline),
      focusedBorder: fieldBorder(colors.emphasis, width: 1.5),
      errorBorder: fieldBorder(semantic.error.foreground),
      focusedErrorBorder: fieldBorder(semantic.error.foreground, width: 1.5),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.emphasis,
      selectionColor: colors.primary.withValues(alpha: 0.4),
      selectionHandleColor: colors.emphasis,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceMuted,
      selectedColor: colors.primary,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: shapes.chipRadius),
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(
        color: colors.onPrimary,
      ),
      checkmarkColor: colors.onPrimary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primary,
      elevation: 0,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected)
              ? colors.text
              : colors.textMuted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.onPrimary
            : colors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.surfaceMuted,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.outline,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.emphasis,
      linearTrackColor: colors.surfaceMuted,
      circularTrackColor: colors.surfaceMuted,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      modalBackgroundColor: colors.surface,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: colors.outline,
      shape: RoundedRectangleBorder(borderRadius: shapes.sheetRadius),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: shapes.cardRadius),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colors.onInverseSurface,
      ),
      actionTextColor: colors.primary,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: shapes.fieldRadius),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outline,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.text,
      textColor: colors.text,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: colors.textMuted,
      ),
    ),
  );
}
