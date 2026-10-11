import 'package:flutter_test/flutter_test.dart';
import 'package:printerhub/app/app.dart';

void main() {
  test('keeps what a screen showed, by name and by kind', () {
    final remembered = Remembered()..keep('list', const [1, 2, 3]);

    expect(remembered.of<List<int>>('list'), [1, 2, 3]);
    // Asked for as something else, or under another name, it is nothing.
    expect(remembered.of<String>('list'), isNull);
    expect(remembered.of<List<int>>('other'), isNull);
  });

  test('forgets everything when asked', () {
    final remembered = Remembered()
      ..keep('list', const [1])
      ..clear();

    expect(remembered.of<List<int>>('list'), isNull);
  });
}
