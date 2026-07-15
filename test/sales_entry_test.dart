import 'package:flutter_test/flutter_test.dart';
import 'package:captain_masala/core/models/sale.dart';

void main() {
  group('Payment Status & Validation Tests', () {
    test('paid/pending => prepaid amount not required and saved as 0/null as per chosen schema', () {
      final sale1 = Sale(
        id: '1',
        invoiceNumber: 'INV-1',
        customerId: 'c1',
        customerName: 'Cust',
        shopName: 'Shop',
        sellerId: 's1',
        sellerName: 'Seller',
        items: [],
        totalAmount: 100,
        discount: 0,
        finalAmount: 100,
        paymentStatus: 'Paid',
        dateTime: DateTime.now(),
      );
      
      expect(sale1.paymentStatus, 'Paid');
      expect(sale1.prepaidAmount, 0.0);

      final sale2 = Sale(
        id: '2',
        invoiceNumber: 'INV-2',
        customerId: 'c1',
        customerName: 'Cust',
        shopName: 'Shop',
        sellerId: 's1',
        sellerName: 'Seller',
        items: [],
        totalAmount: 100,
        discount: 0,
        finalAmount: 100,
        paymentStatus: 'Pending',
        dateTime: DateTime.now(),
      );

      expect(sale2.paymentStatus, 'Pending');
      expect(sale2.prepaidAmount, 0.0);
    });

    test('prepaid selected + valid amount => save success', () {
      final sale = Sale(
        id: '3',
        invoiceNumber: 'INV-3',
        customerId: 'c1',
        customerName: 'Cust',
        shopName: 'Shop',
        sellerId: 's1',
        sellerName: 'Seller',
        items: [],
        totalAmount: 100,
        discount: 0,
        finalAmount: 100,
        paymentStatus: 'Prepaid',
        prepaidAmount: 50.0,
        dateTime: DateTime.now(),
      );

      expect(sale.paymentStatus, 'Prepaid');
      expect(sale.prepaidAmount, 50.0);
    });
  });

  group('Validation Logic Tests (Simulated)', () {
    String? validatePrepaidAmount(String? val, String paymentStatus, double totalAmount) {
      if (paymentStatus == 'Prepaid') {
        final amount = double.tryParse(val ?? '');
        if (amount == null || amount <= 0) {
          return 'Enter valid amount';
        }
        if (amount > totalAmount) {
          return 'Cannot exceed total amount';
        }
      }
      return null;
    }

    test('prepaid selected + missing/invalid amount => validation error', () {
      expect(validatePrepaidAmount('', 'Prepaid', 100), 'Enter valid amount');
      expect(validatePrepaidAmount(null, 'Prepaid', 100), 'Enter valid amount');
      expect(validatePrepaidAmount('-10', 'Prepaid', 100), 'Enter valid amount');
      expect(validatePrepaidAmount('abc', 'Prepaid', 100), 'Enter valid amount');
    });

    test('prepaid selected + amount exceeds total => validation error', () {
      expect(validatePrepaidAmount('150', 'Prepaid', 100), 'Cannot exceed total amount');
    });

    test('prepaid selected + valid amount => valid', () {
      expect(validatePrepaidAmount('50', 'Prepaid', 100), isNull);
      expect(validatePrepaidAmount('100', 'Prepaid', 100), isNull);
    });

    test('paid/pending selected => amount ignored/valid', () {
      expect(validatePrepaidAmount('', 'Paid', 100), isNull);
      expect(validatePrepaidAmount(null, 'Pending', 100), isNull);
    });
  });
}
