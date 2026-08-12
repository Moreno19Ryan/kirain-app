import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/core/utils/ids.dart';

void main() {
  group('newId', () {
    final v4Pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    test('generates a valid UUID v4', () {
      expect(newId(), matches(v4Pattern));
    });

    test('generates a different id on every call', () {
      expect(newId(), isNot(newId()));
    });
  });
}
