import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/features/catat/data/riba_detector.dart';

void main() {
  group('looksLikeRiba', () {
    test('flags common riba/paylater keywords, case-insensitively', () {
      expect(looksLikeRiba('Bayar Cicilan motor'), isTrue);
      expect(looksLikeRiba('shopee PAYLATER'), isTrue);
      expect(looksLikeRiba('kredivo bulan ini'), isTrue);
      expect(looksLikeRiba('kena bunga kartu kredit'), isTrue);
    });

    test('leaves ordinary notes alone', () {
      expect(looksLikeRiba('Makan siang di kantin'), isFalse);
      expect(looksLikeRiba(''), isFalse);
      expect(looksLikeRiba('Beli token listrik'), isFalse);
    });
  });
}
