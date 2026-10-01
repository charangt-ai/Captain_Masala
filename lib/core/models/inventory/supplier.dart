import 'dart:convert';

class Supplier {
  final String id;
  final String name;
  final String contactDetails;
  final String address;
  final List<String> purchaseHistoryIds;
  final double rating; // 1 to 5

  Supplier({
    required this.id,
    required this.name,
    required this.contactDetails,
    required this.address,
    this.purchaseHistoryIds = const [],
    this.rating = 0.0,
  });

  Supplier copyWith({
    String? id,
    String? name,
    String? contactDetails,
    String? address,
    List<String>? purchaseHistoryIds,
    double? rating,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactDetails: contactDetails ?? this.contactDetails,
      address: address ?? this.address,
      purchaseHistoryIds: purchaseHistoryIds ?? this.purchaseHistoryIds,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contactDetails': contactDetails,
      'address': address,
      'purchaseHistoryIds': purchaseHistoryIds,
      'rating': rating,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      contactDetails: map['contactDetails'] ?? '',
      address: map['address'] ?? '',
      purchaseHistoryIds: List<String>.from(map['purchaseHistoryIds'] ?? []),
      rating: map['rating']?.toDouble() ?? 0.0,
    );
  }
  
  String toJson() => json.encode(toMap());
  factory Supplier.fromJson(String source) => Supplier.fromMap(json.decode(source));
}
