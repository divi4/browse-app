class DeliveryItems {
  DeliveryItems({
    required this.name,
    required this.quantity,
    required this.type,
  });

  final String name;
  final int quantity;
  final String type;


  factory DeliveryItems.fromJson(Map<String, dynamic> requestJson) {
    final name = requestJson['name'] as String? ?? '';
    final quantity = requestJson['quantity'] as int? ?? 0;
    final type = requestJson['type'] as String? ?? 'branch/es';

    return DeliveryItems(
      name: name,
      quantity: quantity,
      type: type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'type': type,
    };
  }
}