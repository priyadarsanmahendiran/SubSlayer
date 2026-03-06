class Subscription {
  final int? id;
  final String name;
  final double price;
  final String currency;
  final DateTime renewalDate;

  Subscription({
    this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.renewalDate,
  });

  // Convert to Map (for SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'currency': currency,
      'renewalDate': renewalDate.toIso8601String(),
    };
  }

  // Create from Map (from SQLite)
  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      currency: map['currency'],
      renewalDate: DateTime.parse(map['renewalDate']),
    );
  }
}
