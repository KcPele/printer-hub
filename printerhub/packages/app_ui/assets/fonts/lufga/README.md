# Lufga

Lufga is Volt's font. It is a commercial typeface, so its files are **not in
this repository** (the folder is ignored by git, and the repository is public).

To use it, put the licensed `.ttf` or `.otf` files in this folder, one per
weight: Regular (400), Medium (500), SemiBold (600), and Bold (700) are the
ones the app's type scale uses.

Nothing else is needed. The app bundles whatever is in this folder and
registers it at start-up (`AppFonts.loadLicensed`). On a checkout without the
files, Volt uses the system font and everything still builds and tests.

**Release builds must be made on a machine that has the files**, or Volt ships
with the system font.
