class SaleItem {
  final String productId;
  final String productName;
  final String packSize;
  final double quantity; // In units or kg
  final double rate;
  final double totalAmount;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.packSize,
    required this.quantity,
    required this.rate,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'packSize': packSize,
      'quantity': quantity,
      'rate': rate,
      'totalAmount': totalAmount,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'],
      productName: map['productName'],
      packSize: map['packSize'],
      quantity: (map['quantity'] as num).toDouble(),
      rate: (map['rate'] as num).toDouble(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
    );
  }
}

class Sale {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String customerName;
  final String shopName;
  final String sellerId;
  final String sellerName;
  final List<SaleItem> items;
  final double totalAmount;
  final double discount;
  final double finalAmount;
  final String paymentStatus; // 'Paid', 'Unpaid', 'Prepaid'
  final double prepaidAmount;
  final String deliveryStatus; // 'Delivered', 'Not Delivered'
  final DateTime dateTime;
  final String phone;
  final String status; // 'Active', 'Cancelled'
  final String? cancelReason;
  final DateTime? updatedAt;
  final String? sellerRole;

  Sale({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    required this.shopName,
    required this.sellerId,
    required this.sellerName,
    this.sellerRole,
    required this.items,
    required this.totalAmount,
    required this.discount,
    required this.finalAmount,
    required this.paymentStatus,
    this.prepaidAmount = 0.0,
    this.deliveryStatus = 'Delivered',
    required this.dateTime,
    this.phone = '',
    this.status = 'Active',
    this.cancelReason,
    this.updatedAt,
  });

  Sale copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    String? customerName,
    String? shopName,
    String? sellerId,
    String? sellerName,
    String? sellerRole,
    List<SaleItem>? items,
    double? totalAmount,
    double? discount,
    double? finalAmount,
    String? paymentStatus,
    double? prepaidAmount,
    String? deliveryStatus,
    DateTime? dateTime,
    String? phone,
    String? status,
    String? cancelReason,
    DateTime? updatedAt,
  }) {
    return Sale(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      shopName: shopName ?? this.shopName,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerRole: sellerRole ?? this.sellerRole,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      finalAmount: finalAmount ?? this.finalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      prepaidAmount: prepaidAmount ?? this.prepaidAmount,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      dateTime: dateTime ?? this.dateTime,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'customerName': customerName,
      'shopName': shopName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerRole': sellerRole,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'discount': discount,
      'finalAmount': finalAmount,
      'paymentStatus': paymentStatus,
      'prepaidAmount': prepaidAmount,
      'deliveryStatus': deliveryStatus,
      'dateTime': dateTime.toIso8601String(),
      'phone': phone,
      'status': status,
      'cancelReason': cancelReason,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      invoiceNumber: map['invoiceNumber'],
      customerId: map['customerId'],
      customerName: map['customerName'],
      shopName: map['shopName'],
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? 'Unknown Seller',
      sellerRole: map['sellerRole'],
      items: (map['items'] as List).map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e))).toList(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      discount: (map['discount'] as num).toDouble(),
      finalAmount: (map['finalAmount'] as num).toDouble(),
      paymentStatus: map['paymentStatus'],
      prepaidAmount: map['prepaidAmount'] != null ? (map['prepaidAmount'] as num).toDouble() : 0.0,
      deliveryStatus: map['deliveryStatus'] ?? 'Delivered',
      dateTime: DateTime.parse(map['dateTime']),
      phone: map['phone'] ?? '',
      status: map['status'] ?? 'Active',
      cancelReason: map['cancelReason'],
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }
}
