class Customer {
  final String id;
  final String name;
  final String shopName;
  final String ownerName;
  final String mobileNumber;
  final String address;
  final String district;
  final String city;
  final String gstNumber;
  final String shopImageUrl;
  final double? latitude;
  final double? longitude;
  final DateTime? lastPurchaseDate;
  final double totalSpent;
  final String? handledById;
  final String? handledByName;

  Customer({
    required this.id,
    required this.name,
    required this.shopName,
    required this.ownerName,
    required this.mobileNumber,
    required this.address,
    required this.district,
    required this.city,
    this.gstNumber = '',
    this.shopImageUrl = '',
    this.latitude,
    this.longitude,
    this.lastPurchaseDate,
    this.totalSpent = 0.0,
    this.handledById,
    this.handledByName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'shopName': shopName,
      'ownerName': ownerName,
      'mobileNumber': mobileNumber,
      'address': address,
      'district': district,
      'city': city,
      'gstNumber': gstNumber,
      'shopImageUrl': shopImageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'lastPurchaseDate': lastPurchaseDate?.toIso8601String(),
      'totalSpent': totalSpent,
      'handledById': handledById,
      'handledByName': handledByName,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      shopName: map['shopName'],
      ownerName: map['ownerName'],
      mobileNumber: map['mobileNumber'],
      address: map['address'],
      district: map['district'],
      city: map['city'],
      gstNumber: map['gstNumber'] ?? '',
      shopImageUrl: map['shopImageUrl'] ?? '',
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      lastPurchaseDate: map['lastPurchaseDate'] != null ? DateTime.tryParse(map['lastPurchaseDate']) : null,
      totalSpent: map['totalSpent'] != null ? (map['totalSpent'] as num).toDouble() : 0.0,
      handledById: map['handledById'],
      handledByName: map['handledByName'],
    );
  }
}
