# app_ui

PrinterHub's design tokens, its three themes, and the widgets every feature shares.

## Themes

`AppTheme.volt`, `AppTheme.indigo`, and `AppTheme.mint` each hold a set of tokens per brightness. `AppTheme.of(id).data()` turns one into a Material theme.

A widget reads tokens from the context and nothing else:

```dart
final colors = context.colors;          // brand and surface colours
final status = context.semanticColors;  // status and toner colours
final shapes = context.shapes;          // corner radii
final depth = context.depth;            // shadow or border
final text = context.textTheme;         // type scale
```

`colors.primary` is a fill. Volt's is yellow, which cannot be read as text on a light surface, so brand-coloured text and icons use `colors.emphasis`.

Status and toner colours are the same in every theme.

### Adding a dark variant

Write a second `AppThemeTokens` for the theme and pass it as `dark:` in `app_theme.dart`. No widget changes: nothing outside this package asks which brightness it is in.

## Widgets

| Widget | Use |
|---|---|
| `AppCard` | A container in the theme's shape and depth. `tone` picks the fill; children get colours that read on it |
| `StatusPill` | A labelled status: online, low toner, paper jam |
| `SupplyLevelBar` | A toner level |
| `AppIllustration` | An SVG drawn in the current theme's colours |
| `AppThemePreview` | A miniature of a theme, for the picker |

Buttons, fields, switches, sheets, and the rest are Material widgets, styled by the theme.

## Illustrations

SVG files in `assets/illustrations/`, listed in `AppIllustrations`. A file is drawn in the placeholder colours of `IllustrationPalette`; each is swapped for a theme token when it renders. Any other colour is kept as drawn, which is how a status light stays green in every theme.

## Fonts

Plus Jakarta Sans (Indigo) and Manrope (Mint) are bundled, under the SIL Open Font Licence; each folder carries its licence text. Lufga (Volt) is commercial and is not in the repository: see `assets/fonts/lufga/README.md`.

## Tests

```sh
flutter test                                   # everything
flutter test --update-goldens --tags golden    # after an intended visual change
```

`test/src/theme/contrast_test.dart` holds every theme to WCAG AA. A new colour pair that carries text belongs there.
