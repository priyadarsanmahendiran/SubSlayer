import 'package:flutter_test/flutter_test.dart';
import 'package:sub_slayer/helpers/text_parser.dart';

void main() {
  group('TextParser', () {
    test('parses name and price in SEK correctly', () {
      final result = TextParser.parse('You paid 129 SEK to Netflix today.');

      expect(result['name'], 'Netflix');
      expect(result['price'], 129.0);
      expect(result['currency'], 'SEK');
    });

    test('parses name and price in USD correctly', () {
      final result = TextParser.parse('Spotify 9.99USD');

      expect(result['name'], 'Spotify');
      expect(result['price'], 9.99);
      expect(result['currency'], 'USD');
    });

    test('parses comma decimals correctly', () {
      final result = TextParser.parse('Disney+ 89,00kr/mån');

      expect(result['name'], 'Disney+');
      expect(result['price'], 89.0);
      expect(result['currency'], 'SEK');
    });

    test('returns empty name if service is not in known list', () {
      final result = TextParser.parse('149 kr paid to UnknownService');

      expect(result['name'], '');
      expect(result['price'], 149.0);
      expect(result['currency'], 'SEK');
    });
  });
}
