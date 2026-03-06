class TextParser {
  // A small list of known services to scan for
  static final List<String> _knownServices = [
    'Netflix',
    'Spotify',
    'YouTube',
    'Amazon Prime',
    'Disney+',
    'Hulu',
    'HBO',
    'Apple',
    'Google',
    'Gymshark',
    'SATS',
    'Fitness24Seven',
  ];

  static Map<String, dynamic> parse(String text) {
    String name = '';
    double price = 0.0;
    String currency = 'SEK';

    for (var service in _knownServices) {
      if (text.toLowerCase().contains(service.toLowerCase())) {
        name = service;
        break;
      }
    }

    final priceRegex = RegExp(
      r'(\d+[.,]?\d*)\s*(kr|SEK|USD|EUR|INR|₹|€|\$)',
      caseSensitive: false,
    );
    final match = priceRegex.firstMatch(text);

    if (match != null) {
      String amountStr = match.group(1)!.replaceAll(',', '.');
      price = double.tryParse(amountStr) ?? 0.0;

      String currStr = match.group(2)!.toUpperCase();
      if (currStr == 'KR') {
        currency = 'SEK';
      } else if (currStr == '\$') {
        currency = 'USD';
      } else if (currStr == '€') {
        currency = 'EUR';
      } else {
        currency = currStr;
      }
    }

    return {
      'name': name,
      'price': price,
      'currency': currency,
      // Default renewal to 1 month from today
      'renewalDate': DateTime.now().add(const Duration(days: 30)),
    };
  }
}
