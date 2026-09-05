import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_user.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/inventory_log.dart';
import '../models/product_category.dart';
import '../models/master_product.dart';
import 'api_config.dart';
import 'offline_auth_service.dart';

class DatabaseService extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  
  // State variables
  List<Product> _products = [];
  List<Customer> _customers = [];
  List<Sale> _sales = [];
  List<InventoryLog> _logs = [];
  List<ProductCategory> _categories = [];
  List<MasterProduct> _masterProducts = [];
  
  AppUser? _currentUserProfile;
  bool _isLoading = false;
  bool _isLoadingMoreSales = false;
  bool _hasMoreSales = true;
  bool _hasMoreLogs = true;
  bool _isOfflineMode = false;
  int _salesSkip = 0;
  int _logsSkip = 0;
  final int _pageSize = 200;

  // Getters
  List<Product> get products => _products;
  List<Customer> get customers => _customers;
  List<Sale> get sales => _sales;
  List<InventoryLog> get inventoryLogs => _logs;
  List<ProductCategory> get categories => _categories;
  List<MasterProduct> get masterProducts => _masterProducts;
  AppUser? get currentUserProfile => _currentUserProfile;
  bool get isLoggedIn => _currentUserProfile != null;
  bool get isLoading => _isLoading;
  bool get isLoadingMoreSales => _isLoadingMoreSales;
  bool get hasMoreSales => _hasMoreSales;
  bool get hasMoreLogs => _hasMoreLogs;
  bool get isOfflineMode => _isOfflineMode;

  // Helper for requests
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper to parse dates correctly
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // --- Auth & Init ---

  Future<bool> init() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null) {
      try {
        final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/users/me'),
          headers: await _getHeaders(),
        );
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          _currentUserProfile = AppUser(
            id: data['id'],
            name: data['name'] ?? '',
            email: data['email'],
            phoneNumber: data['phoneNumber'] ?? '',
            role: data['role'] ?? 'pending',
            username: data['username'] ?? '',
          );
          _isOfflineMode = false;
          await _loadAllData();
          return true;
        } else {
          await logout();
        }
      } catch (e) {
        debugPrint('Init error: $e');
        // Try offline fallback
        final cachedProfile = await OfflineAuthService.getCachedProfile();
        if (cachedProfile != null) {
          _currentUserProfile = cachedProfile;
          _isOfflineMode = true;
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _loadAllData() async {
    if (!isLoggedIn) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      await Future.wait([
        _fetchProducts(),
        _fetchCustomers(),
        _fetchCategories(),
        _fetchMasterProducts(),
        _fetchSales(reset: true),
        _fetchLogs(reset: true),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchProducts() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/products'), headers: await _getHeaders());
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      _products = data.map((json) => Product(
        id: json['id'],
        name: json['name'],
        packSize: json['packSize'],
        wholesalePrice: (json['wholesalePrice'] ?? 0).toDouble(),
        originalPrice: (json['originalPrice'] ?? 0).toDouble(),
        remainingStock: (json['remainingStock'] ?? 0).toDouble(),
        imageUrl: json['imageUrl'] ?? '',
        isEnabled: json['isEnabled'] ?? true,
        categoryId: json['categoryId'] ?? '',
        masterProductId: json['masterProductId'] ?? '',
      )).toList();
      notifyListeners();
    }
  }

  Future<void> _fetchCustomers() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/customers'), headers: await _getHeaders());
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      _customers = data.map((json) => Customer(
        id: json['id'],
        name: json['name'],
        shopName: json['shopName'],
        ownerName: json['ownerName'] ?? '',
        mobileNumber: json['mobileNumber'],
        address: json['address'],
        district: json['district'] ?? '',
        city: json['city'] ?? '',
        gstNumber: json['gstNumber'] ?? '',
        shopImageUrl: json['shopImageUrl'] ?? '',
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        lastPurchaseDate: _parseDate(json['lastPurchaseDate']),
        totalSpent: (json['totalSpent'] ?? 0).toDouble(),
        handledById: json['handledById'],
        handledByName: json['handledByName'],
      )).toList();
      notifyListeners();
    }
  }

  Future<void> _fetchCategories() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/categories'), headers: await _getHeaders());
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      _categories = data.map((json) => ProductCategory(
        id: json['id'],
        name: json['name'],
        image: json['image'] ?? '',
      )).toList();
      notifyListeners();
    }
  }

  Future<void> _fetchMasterProducts() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/master-products'), headers: await _getHeaders());
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      _masterProducts = data.map((json) => MasterProduct(
        id: json['id'],
        name: json['name'],
        totalStockKg: (json['totalStockKg'] ?? 0).toDouble(),
      )).toList();
      notifyListeners();
    }
  }

  Future<void> _fetchSales({bool reset = false}) async {
    if (reset) {
      _salesSkip = 0;
      _sales = [];
      _hasMoreSales = true;
    }
    if (!_hasMoreSales || _isLoadingMoreSales) return;

    _isLoadingMoreSales = true;
    notifyListeners();

    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/sales?skip=$_salesSkip&limit=$_pageSize'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      if (data.length < _pageSize) _hasMoreSales = false;
      
      final fetched = data.map((json) {
        return Sale(
          id: json['id'],
          invoiceNumber: json['invoiceNumber'],
          customerId: json['customerId'],
          customerName: json['customerName'],
          shopName: json['shopName'],
          sellerId: json['sellerId'],
          sellerName: json['sellerName'],
          sellerRole: json['sellerRole'] ?? 'seller',
          items: (json['items'] as List).map((i) => SaleItem(
            productId: i['productId'],
            productName: i['productName'],
            packSize: i['packSize'],
            quantity: (i['quantity'] as num).toDouble(),
            rate: (i['rate'] ?? 0).toDouble(),
            totalAmount: (i['totalAmount'] ?? 0).toDouble(),
          )).toList(),
          totalAmount: (json['totalAmount'] ?? 0).toDouble(),
          discount: (json['discount'] ?? 0).toDouble(),
          finalAmount: (json['finalAmount'] ?? 0).toDouble(),
          paymentStatus: json['paymentStatus'],
          prepaidAmount: (json['prepaidAmount'] ?? 0).toDouble(),
          deliveryStatus: json['deliveryStatus'] ?? 'Delivered',
          dateTime: _parseDate(json['dateTime']) ?? DateTime.now(),
          phone: json['phone'] ?? '',
          status: json['status'] ?? 'Active',
          cancelReason: json['cancelReason'],
          updatedAt: _parseDate(json['updatedAt']),
        );
      }).toList();

      _sales.addAll(fetched);
      _salesSkip += fetched.length;
    }
    _isLoadingMoreSales = false;
    notifyListeners();
  }

  Future<void> loadMoreSales() async {
    await _fetchSales();
  }

  Future<void> _fetchLogs({bool reset = false}) async {
    if (reset) {
      _logsSkip = 0;
      _logs = [];
      _hasMoreLogs = true;
    }
    if (!_hasMoreLogs) return;

    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/inventory-logs?skip=$_logsSkip&limit=$_pageSize'),
      headers: await _getHeaders(),
    );
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      if (data.length < _pageSize) _hasMoreLogs = false;
      
      final fetched = data.map((json) => InventoryLog(
        id: json['id'],
        productId: json['productId'],
        productName: json['productName'],
        changeQuantity: (json['changeQuantity'] ?? 0).toDouble(),
        type: json['type'],
        dateTime: _parseDate(json['dateTime']) ?? DateTime.now(),
        notes: json['notes'] ?? '',
      )).toList();

      _logs.addAll(fetched);
      _logsSkip += fetched.length;
      notifyListeners();
    }
  }

  Future<void> loadMoreLogs() async {
    await _fetchLogs();
  }

  void dispose() {
    super.dispose();
  }

  // --- User / Auth ---

  Future<String> login(String usernameOrEmail, String password) async {
    final trimmedUser = usernameOrEmail.trim();
    final trimmedPass = password.trim();
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'usernameOrEmail': trimmedUser, 'password': trimmedPass}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        await _storage.write(key: 'jwt_token', value: data['token']);
        _currentUserProfile = AppUser(
          id: data['id'],
          name: data['name'],
          email: data['email'],
          phoneNumber: data['phoneNumber'] ?? '',
          role: data['role'],
          username: data['username'],
        );
        _isOfflineMode = false;
        await OfflineAuthService.cacheCredentials(trimmedUser, trimmedPass, _currentUserProfile!);
        await _loadAllData();
        notifyListeners();
        return data['role'];
      } else {
        return 'Invalid credentials';
      }
    } catch (e) {
      // Offline fallback
      final cachedProfile = await OfflineAuthService.verifyOffline(trimmedUser, trimmedPass);
      if (cachedProfile != null) {
        _currentUserProfile = cachedProfile;
        _isOfflineMode = true;
        notifyListeners();
        return cachedProfile.role;
      }
      return 'network_error';
    }
  }

  Future<String> registerSeller(
    String name,
    String phone,
    String email,
    String username,
    String password, {
    String role = 'pending',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'phone': phone,
          'email': email,
          'username': username,
          'password': password,
          'role': role,
        }),
      );
      if (res.statusCode == 201) {
        final data = json.decode(res.body);
        await _storage.write(key: 'jwt_token', value: data['token']);
        return 'success';
      } else {
        final err = json.decode(res.body);
        return err['message'] ?? 'Registration failed';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<AppUser>> getActiveUsers() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/users/active'), headers: await _getHeaders());
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((json) => AppUser(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phoneNumber: json['phoneNumber'] ?? '',
        role: json['role'],
        username: json['username'] ?? '',
      )).toList();
    }
    return [];
  }

  Future<List<AppUser>> getPendingUsers() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/users/pending'), headers: await _getHeaders());
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((json) => AppUser(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phoneNumber: json['phoneNumber'] ?? '',
        role: json['role'],
        username: json['username'] ?? '',
        requestedRole: json['requestedRole'],
      )).toList();
    }
    return [];
  }

  Future<void> changeUserRole(String userId, String newRole) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/users/$userId/role'),
      headers: await _getHeaders(),
      body: json.encode({'role': newRole}),
    );
  }

  Future<void> approveUser(String userId) async {
    await http.put(Uri.parse('${ApiConfig.baseUrl}/users/$userId/approve'), headers: await _getHeaders());
  }

  Future<void> rejectUser(String userId) async {
    await http.put(Uri.parse('${ApiConfig.baseUrl}/users/$userId/reject'), headers: await _getHeaders());
  }

  Future<bool> requestRoleChange(String newRole) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/users/request-role'),
      headers: await _getHeaders(),
      body: json.encode({'role': newRole}),
    );
    return res.statusCode == 200;
  }

  Future<bool> updateUserProfile(String name, String phone, String username) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/users/me'),
      headers: await _getHeaders(),
      body: json.encode({'name': name, 'phoneNumber': phone, 'username': username}),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      _currentUserProfile = AppUser(
        id: data['id'],
        name: data['name'],
        email: data['email'],
        phoneNumber: data['phoneNumber'],
        role: data['role'],
        username: data['username'],
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/auth/change-password'),
      headers: await _getHeaders(),
      body: json.encode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    return res.statusCode == 200;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await OfflineAuthService.clearCache();
    _currentUserProfile = null;
    _isOfflineMode = false;
    _products = [];
    _customers = [];
    _sales = [];
    _logs = [];
    _categories = [];
    _masterProducts = [];
    notifyListeners();
  }

  // --- Products ---

  List<Product> getProductsForCategory(String categoryId) {
    return _products.where((p) => p.categoryId == categoryId).toList();
  }

  Future<bool> addProduct(Product product) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/products'),
      headers: await _getHeaders(),
      body: json.encode(product.toMap()),
    );
    if (res.statusCode == 201) {
      await _fetchProducts();
      return true;
    }
    return false;
  }

  Future<void> updateProduct(Product updated) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/products/${updated.id}'),
      headers: await _getHeaders(),
      body: json.encode(updated.toMap()),
    );
    await _fetchProducts();
  }

  Future<void> updateImageForSimilarProducts(String productName, String imageUrl) async {
    // A simplified implementation for the frontend, backend can do this more efficiently,
    // but we'll do it iteratively here to satisfy the existing frontend call.
    final similar = _products.where((p) => p.name == productName && p.imageUrl != imageUrl).toList();
    for (var p in similar) {
      final updated = p.copyWith(imageUrl: imageUrl);
      await updateProduct(updated);
    }
  }

  Future<void> deleteProduct(String id) async {
    await http.delete(Uri.parse('${ApiConfig.baseUrl}/products/$id'), headers: await _getHeaders());
    await _fetchProducts();
  }

  // --- Categories ---

  Future<void> addCategory(ProductCategory category) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/categories'),
      headers: await _getHeaders(),
      body: json.encode(category.toMap()),
    );
    await _fetchCategories();
  }

  Future<void> updateCategory(ProductCategory category) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/categories/${category.id}'),
      headers: await _getHeaders(),
      body: json.encode(category.toMap()),
    );
    await _fetchCategories();
  }

  Future<String> uploadCategoryImage(dynamic file, String categoryId) async {
    // In the new system, we just store base64 directly in MongoDB
    // Read file bytes and return as base64 string
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (_) {
      return '';
    }
  }

  Future<void> deleteCategory(String id) async {
    await http.delete(Uri.parse('${ApiConfig.baseUrl}/categories/$id'), headers: await _getHeaders());
    await _fetchCategories();
  }

  // --- Master Products ---
  
  Future<void> addMasterProduct(MasterProduct master) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/master-products'),
      headers: await _getHeaders(),
      body: json.encode(master.toMap()),
    );
    await _fetchMasterProducts();
  }

  Future<void> updateMasterProduct(MasterProduct updated) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/master-products/${updated.id}'),
      headers: await _getHeaders(),
      body: json.encode(updated.toMap()),
    );
    await _fetchMasterProducts();
  }

  Future<void> deleteMasterProduct(String id) async {
    await http.delete(Uri.parse('${ApiConfig.baseUrl}/master-products/$id'), headers: await _getHeaders());
    await _fetchMasterProducts();
    await _fetchProducts(); // cascade
  }

  Future<bool> updateMasterStock(String masterId, double newOpeningStock, String notes) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/inventory-logs/master-stock/$masterId'),
      headers: await _getHeaders(),
      body: json.encode({'newOpeningStock': newOpeningStock, 'notes': notes}),
    );
    if (res.statusCode == 200) {
      await _fetchMasterProducts();
      await _fetchLogs(reset: true);
      return true;
    }
    return false;
  }

  Future<bool> updateStock(String productId, double newOpeningStock, String notes) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/inventory-logs/stock/$productId'),
      headers: await _getHeaders(),
      body: json.encode({'newOpeningStock': newOpeningStock, 'notes': notes}),
    );
    if (res.statusCode == 200) {
      await _fetchProducts();
      await _fetchLogs(reset: true);
      return true;
    }
    return false;
  }

  // --- Customers ---

  Future<void> addCustomer(Customer customer) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/customers'),
      headers: await _getHeaders(),
      body: json.encode(customer.toMap()),
    );
    await _fetchCustomers();
  }

  Future<void> updateCustomer(Customer customer) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/customers/${customer.id}'),
      headers: await _getHeaders(),
      body: json.encode(customer.toMap()),
    );
    await _fetchCustomers();
  }

  Future<void> deleteCustomer(String id) async {
    await http.delete(Uri.parse('${ApiConfig.baseUrl}/customers/$id'), headers: await _getHeaders());
    await _fetchCustomers();
  }

  // --- Sales ---

  Future<bool> recordSale(Sale sale) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/sales'),
      headers: await _getHeaders(),
      body: json.encode(sale.toMap()),
    );
    if (res.statusCode == 201) {
      await _fetchSales(reset: true);
      await _fetchProducts();
      await _fetchMasterProducts();
      await _fetchCustomers();
      return true;
    }
    return false;
  }

  Future<void> updatePaymentStatus(String saleId, String status) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/payment'),
      headers: await _getHeaders(),
      body: json.encode({'status': status}),
    );
    await _fetchSales(reset: true);
  }

  Future<void> updatePrepaidAmount(String saleId, double additionalPrepaidAmount, double finalAmount) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/prepaid'),
      headers: await _getHeaders(),
      body: json.encode({'additionalPrepaidAmount': additionalPrepaidAmount}),
    );
    await _fetchSales(reset: true);
  }

  Future<void> updateSale(Sale sale) async {
    // Generic update for sale
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/sales/${sale.id}'),
      headers: await _getHeaders(),
      body: json.encode(sale.toMap()),
    );
    await _fetchSales(reset: true);
  }

  Future<void> cancelSale(String saleId, String reason) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/cancel'),
      headers: await _getHeaders(),
      body: json.encode({'reason': reason}),
    );
    await _fetchSales(reset: true);
  }

  Future<void> markSaleDelivered(String saleId) async {
    await updateDeliveryStatus(saleId, 'Delivered');
  }

  Future<void> updateDeliveryStatus(String saleId, String status) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}/sales/$saleId/delivery'),
      headers: await _getHeaders(),
      body: json.encode({'status': status}),
    );
    await _fetchSales(reset: true);
  }

  Future<void> addInventoryLog(InventoryLog log) async {
    // handled mostly via backend now
  }

  double getPackSizeInKg(String packSize) {
    final lower = packSize.toLowerCase();
    if (lower == '50 gram - 1 kg bag' || lower == '50g - 1kg bag' || (lower.contains('50') && lower.contains('1 kg'))) {
      return 1.0; 
    }
    if (lower.contains('kg')) {
      final match = RegExp(r'([0-9.]+)\s*kg').firstMatch(lower);
      if (match != null) return double.tryParse(match.group(1) ?? '') ?? 1.0;
    } else if (lower.contains('gram') || lower.contains(' g') || lower.endsWith('g')) {
      final match = RegExp(r'([0-9.]+)\s*(?:gram|g)').firstMatch(lower);
      if (match != null) return (double.tryParse(match.group(1) ?? '') ?? 0.0) / 1000.0;
    }
    return 1.0;
  }
}
