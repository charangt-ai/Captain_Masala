import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/inventory_log.dart';
import '../models/app_user.dart';
import '../models/product_category.dart';
import '../models/master_product.dart';

const int _kPageSize = 200;
const int _kLoadMoreSize = 50;

class DatabaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isInitialized = false;

  List<Product> _products = [];
  List<Customer> _customers = [];
  List<Sale> _sales = [];
  List<InventoryLog> _inventoryLogs = [];
  List<ProductCategory> _categories = [];
  List<MasterProduct> _masterProducts = [];

  StreamSubscription? _productSub;
  StreamSubscription? _customerSub;
  StreamSubscription? _saleSub;
  StreamSubscription? _logSub;
  StreamSubscription? _authSub;
  StreamSubscription? _categorySub;
  StreamSubscription? _masterProductSub;

  bool _isLoggedIn = false;
  AppUser? _currentUserProfile;

  // Pagination state for sales
  DocumentSnapshot? _lastSaleDoc;
  bool _hasMoreSales = true;
  bool _isLoadingMoreSales = false;

  // Pagination state for inventory logs
  DocumentSnapshot? _lastLogDoc;
  bool _hasMoreLogs = true;
  bool _isLoadingMoreLogs = false;

  List<Product> get products => _products;
  List<Customer> get customers => _customers;
  List<Sale> get sales => _sales;
  List<InventoryLog> get inventoryLogs => _inventoryLogs;
  List<ProductCategory> get categories => _categories;
  List<MasterProduct> get masterProducts => _masterProducts;
  bool get isLoggedIn => _isLoggedIn;
  AppUser? get currentUserProfile => _currentUserProfile;
  bool get hasMoreSales => _hasMoreSales;
  bool get isLoadingMoreSales => _isLoadingMoreSales;
  bool get hasMoreLogs => _hasMoreLogs;
  bool get isLoadingMoreLogs => _isLoadingMoreLogs;

  Future<void> init() async {
    if (_isInitialized) return;

    // Enable offline persistence with unlimited cache
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Listen to Auth State
    _authSub = _auth.authStateChanges().listen((User? user) async {
      _isLoggedIn = user != null;
      if (user != null) {
        await _fetchAndSetUserRole(user);
      } else {
        _currentUserProfile = null;
      }
      notifyListeners();
    });

    _listenToProducts();
    _listenToCustomers();
    _listenToSales();
    _listenToLogs();
    _listenToCategories();
    _listenToMasterProducts();

    _isInitialized = true;
    notifyListeners();
  }

  void _listenToProducts() {
    _productSub = _firestore.collection('products').snapshots().listen((
      snapshot,
    ) {
      _products = snapshot.docs
          .map((doc) => Product.fromMap(doc.data()))
          .toList();

      // Seed initial products only when the collection is completely empty
      if (_isLoggedIn && snapshot.docs.isEmpty) {
        _seedInitialProducts();
      }
      notifyListeners();
    });
  }

  Future<void> _seedInitialProducts() async {
    final seedData = [
      // 500g items
      Product(
        id: '1',
        name: 'Sambar Powder',
        packSize: '500 g',
        wholesalePrice: 155,
        originalPrice: 200,
        remainingStock: 50,
        categoryId: 'cat-3',
      ),
      Product(
        id: '2',
        name: 'Coriander Powder',
        packSize: '500 g',
        wholesalePrice: 95,
        originalPrice: 150,
        remainingStock: 50,
        categoryId: 'cat-3',
      ),
      Product(
        id: '3',
        name: 'Turmeric Powder',
        packSize: '500 g',
        wholesalePrice: 110,
        originalPrice: 180,
        remainingStock: 50,
        categoryId: 'cat-3',
      ),
      Product(
        id: '4',
        name: 'Chilli Powder',
        packSize: '500 g',
        wholesalePrice: 135,
        originalPrice: 200,
        remainingStock: 50,
        categoryId: 'cat-3',
      ),
      Product(
        id: '5',
        name: 'Chicken Masala',
        packSize: '500 g',
        wholesalePrice: 140,
        originalPrice: 220,
        remainingStock: 50,
        categoryId: 'cat-3',
      ),
      Product(
        id: '6',
        name: 'Curry Masala',
        packSize: '500 g',
        wholesalePrice: 190,
        originalPrice: 250,
        remainingStock: 50,
        categoryId: 'cat-3',
      ),
      Product(
        id: '7',
        name: 'Chicken 65 Masala',
        packSize: '500 g',
        wholesalePrice: 85,
        originalPrice: 120,
        remainingStock: 50,
        categoryId: 'cat-3',
      ),

      // 50g-1kg bag items
      Product(
        id: '50g1kg-1',
        name: 'Chicken Masala 50g - 1 kg bag',
        packSize: '50g-1kg',
        wholesalePrice: 300.00,
        originalPrice: 600.00,
        remainingStock: 100,
        categoryId: 'cat-2',
      ),
      Product(
        id: '50g1kg-2',
        name: 'Chilli Powder 50g - 1 kg bag',
        packSize: '50g-1kg',
        wholesalePrice: 290.00,
        originalPrice: 580.00,
        remainingStock: 100,
        categoryId: 'cat-2',
      ),
      Product(
        id: '50g1kg-3',
        name: 'Coriander Powder 50g - 1 kg bag',
        packSize: '50g-1kg',
        wholesalePrice: 235.00,
        originalPrice: 470.00,
        remainingStock: 100,
        categoryId: 'cat-2',
      ),
      Product(
        id: '50g1kg-4',
        name: 'Curry Masala 50g - 1 kg bag',
        packSize: '50g-1kg',
        wholesalePrice: 400.00,
        originalPrice: 800.00,
        remainingStock: 100,
        categoryId: 'cat-2',
      ),
      Product(
        id: '50g1kg-5',
        name: 'Turmeric Powder 50g - 1 kg bag',
        packSize: '50g-1kg',
        wholesalePrice: 240.00,
        originalPrice: 480.00,
        remainingStock: 100,
        categoryId: 'cat-2',
      ),
      // 50g items (from user image)
      Product(
        id: '50g-1',
        name: 'CHICKEN MASALA 50 GRAM',
        packSize: '50 grams',
        wholesalePrice: 15.00,
        originalPrice: 31.00,
        remainingStock: 100,
        categoryId: 'cat-1',
      ),
      Product(
        id: '50g-2',
        name: 'CHILLI POWDER 50 GRAM',
        packSize: '50 grams',
        wholesalePrice: 15.00,
        originalPrice: 30.00,
        remainingStock: 100,
        categoryId: 'cat-1',
      ),
      Product(
        id: '50g-3',
        name: 'CORIANDER POWDER 50 GRAM',
        packSize: '50 grams',
        wholesalePrice: 11.75,
        originalPrice: 20.00,
        remainingStock: 100,
        categoryId: 'cat-1',
      ),
      Product(
        id: '50g-4',
        name: 'CURRY MASALA 50 GRAM',
        packSize: '50 grams',
        wholesalePrice: 21.00,
        originalPrice: 41.50,
        remainingStock: 100,
        categoryId: 'cat-1',
      ),
      Product(
        id: '50g-5',
        name: 'TURMERC POWDER 50 GRAM',
        packSize: '50 grams',
        wholesalePrice: 13.00,
        originalPrice: 26.00,
        remainingStock: 100,
        categoryId: 'cat-1',
      ),

      // 1kg items (from user images)
      Product(
        id: '1kg-1',
        name: 'Chicken 65 Masala - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 140.00,
        originalPrice: 280.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-2',
        name: 'Chicken Masala - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 250.00,
        originalPrice: 500.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-3',
        name: 'Chilli Powder - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 260.00,
        originalPrice: 520.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-4',
        name: 'Coriander Powder - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 195.00,
        originalPrice: 390.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-5',
        name: 'Curry Masala - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 345.00,
        originalPrice: 690.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-6',
        name: 'Garam Masala - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 450.00,
        originalPrice: 900.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-7',
        name: 'Mutton Masala - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 345.00,
        originalPrice: 690.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-8',
        name: 'Rasam Powder - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 280.00,
        originalPrice: 560.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-9',
        name: 'Sambar Masala - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 270.00,
        originalPrice: 540.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-10',
        name: 'SP Chicken 65 - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 100.00,
        originalPrice: 200.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
      Product(
        id: '1kg-11',
        name: 'Turmeric Powder - 1 kg',
        packSize: '1 kg',
        wholesalePrice: 190.00,
        originalPrice: 380.00,
        remainingStock: 100,
        categoryId: 'cat-4',
      ),
    ];
    for (var p in seedData) {
      // Use set with merge to avoid overwriting existing stock if already there
      await _firestore
          .collection('products')
          .doc(p.id)
          .set(p.toMap(), SetOptions(merge: true));
    }
  }

  void _listenToCustomers() {
    _customerSub = _firestore.collection('customers').snapshots().listen((
      snapshot,
    ) {
      _customers = snapshot.docs
          .map((doc) => Customer.fromMap(doc.data()))
          .toList();
      notifyListeners();
    });
  }

  void _listenToSales() {
    _saleSub = _firestore
        .collection('sales')
        .orderBy('dateTime', descending: true)
        .limit(_kPageSize)
        .snapshots()
        .listen((snapshot) {
          _sales = snapshot.docs
              .map((doc) => Sale.fromMap(doc.data()))
              .toList();
          if (snapshot.docs.isNotEmpty) {
            _lastSaleDoc = snapshot.docs.last;
          }
          _hasMoreSales = snapshot.docs.length >= _kPageSize;
          notifyListeners();
        });
  }

  Future<void> loadMoreSales() async {
    if (!_hasMoreSales || _isLoadingMoreSales || _lastSaleDoc == null) return;

    _isLoadingMoreSales = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('sales')
          .orderBy('dateTime', descending: true)
          .startAfterDocument(_lastSaleDoc!)
          .limit(_kLoadMoreSize)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final older = snapshot.docs
            .map((doc) => Sale.fromMap(doc.data()))
            .toList();
        _sales.addAll(older);
        _lastSaleDoc = snapshot.docs.last;
      }
      _hasMoreSales = snapshot.docs.length >= _kLoadMoreSize;
    } catch (e) {
      debugPrint('Error loading more sales: $e');
    } finally {
      _isLoadingMoreSales = false;
      notifyListeners();
    }
  }

  void _listenToLogs() {
    _logSub = _firestore
        .collection('inventoryLogs')
        .orderBy('dateTime', descending: true)
        .limit(_kPageSize)
        .snapshots()
        .listen((snapshot) {
          _inventoryLogs = snapshot.docs
              .map((doc) => InventoryLog.fromMap(doc.data()))
              .toList();
          if (snapshot.docs.isNotEmpty) {
            _lastLogDoc = snapshot.docs.last;
          }
          _hasMoreLogs = snapshot.docs.length >= _kPageSize;
          notifyListeners();
        });
  }

  Future<void> loadMoreLogs() async {
    if (!_hasMoreLogs || _isLoadingMoreLogs || _lastLogDoc == null) return;

    _isLoadingMoreLogs = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('inventoryLogs')
          .orderBy('dateTime', descending: true)
          .startAfterDocument(_lastLogDoc!)
          .limit(_kLoadMoreSize)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final older = snapshot.docs
            .map((doc) => InventoryLog.fromMap(doc.data()))
            .toList();
        _inventoryLogs.addAll(older);
        _lastLogDoc = snapshot.docs.last;
      }
      _hasMoreLogs = snapshot.docs.length >= _kLoadMoreSize;
    } catch (e) {
      debugPrint('Error loading more logs: $e');
    } finally {
      _isLoadingMoreLogs = false;
      notifyListeners();
    }
  }

  void _listenToCategories() {
    _categorySub = _firestore.collection('categories').snapshots().listen((
      snapshot,
    ) {
      _categories = snapshot.docs
          .map((doc) => ProductCategory.fromMap(doc.data()))
          .toList();

      // Auto-seed missing categories for demo purposes
      if (_isLoggedIn && _categories.isEmpty) {
        _seedInitialCategories();
      }
      notifyListeners();
    });
  }

  void _listenToMasterProducts() {
    _masterProductSub = _firestore.collection('master_products').snapshots().listen((snapshot) {
      _masterProducts = snapshot.docs.map((doc) => MasterProduct.fromMap(doc.data())).toList();
      notifyListeners();
    });
  }

  Future<void> _seedInitialCategories() async {
    final seedData = [
      ProductCategory(id: 'cat-1', name: '50 grams'),
      ProductCategory(id: 'cat-2', name: '50 grams (1 Kg bag)'),
      ProductCategory(id: 'cat-3', name: '500 grams'),
      ProductCategory(id: 'cat-4', name: '1 kg'),
    ];
    for (var c in seedData) {
      await _firestore.collection('categories').doc(c.id).set(c.toMap());
    }
  }

  @override
  void dispose() {
    _productSub?.cancel();
    _customerSub?.cancel();
    _saleSub?.cancel();
    _logSub?.cancel();
    _authSub?.cancel();
    _categorySub?.cancel();
    _masterProductSub?.cancel();
    super.dispose();
  }

  // --- Auth Actions ---

  Future<String> login(String usernameOrEmail, String password) async {
    String email = usernameOrEmail.trim();
    final isUsername = !email.contains('@');

    // --- ADMIN RECOVERY BACKDOOR ---
    if (email == 'admin' && password == 'resetadmin') {
      try {
        // 1. Wipe any existing corrupted admin documents from Firestore
        final querySnapshot = await _firestore.collection('users').where('username', isEqualTo: 'admin').get();
        for (var doc in querySnapshot.docs) {
          await doc.reference.delete();
        }

        UserCredential cred;
        final uniqueEmail = 'admin_${DateTime.now().millisecondsSinceEpoch}@captainmasala.com';
        try {
          // 2. Create a brand new auth user to bypass any old forgotten passwords
          cred = await _auth.createUserWithEmailAndPassword(
            email: uniqueEmail,
            password: 'password123',
          );
        } catch (e) {
          // Fallback if needed
          cred = await _auth.signInWithEmailAndPassword(
            email: uniqueEmail,
            password: 'password123',
          );
        }

        // 3. Create a fresh Firestore document for the new admin
        _currentUserProfile = AppUser(
          id: cred.user!.uid,
          email: uniqueEmail,
          role: 'super_admin',
          username: 'admin',
        );
        await _firestore.collection('users').doc(cred.user!.uid).set(_currentUserProfile!.toMap());
        
        notifyListeners();
        return 'super_admin';
      } catch (e) {
        return 'network_error';
      }
    }
    // --- END ADMIN RECOVERY BACKDOOR ---

    try {
      if (isUsername) {
        QuerySnapshot? querySnapshot;
        try {
          querySnapshot = await _firestore
              .collection('users')
              .where('username', isEqualTo: email)
              .limit(1)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          // Server unreachable, try cache
          try {
            querySnapshot = await _firestore
                .collection('users')
                .where('username', isEqualTo: email)
                .limit(1)
                .get(const GetOptions(source: Source.cache));
          } catch (_) {
            querySnapshot = null;
          }
        }

        if (querySnapshot != null && querySnapshot.docs.isNotEmpty) {
          final fetchedEmail = querySnapshot.docs.first.data() as Map<String, dynamic>?;
          final emailVal = fetchedEmail?['email'] as String?;
          if (emailVal != null && emailVal.isNotEmpty) {
            email = emailVal;
          } else {
            if (email == 'admin') email = 'admin@captainmasala.com';
            else return 'invalid';
          }
        } else {
          // If username not found in DB, only allow 'admin' fallback for the first-time setup
          if (email == 'admin') {
            email = 'admin@captainmasala.com';
          } else {
            return 'invalid';
          }
        }
      }

      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return await _fetchAndSetUserRole(credential.user!);
      } on FirebaseAuthException catch (e) {
        // If it's the admin fallback and the account might have been deleted, try to recreate it
        if (email == 'admin@captainmasala.com' && password == 'password123') {
          try {
            final createCred = await _auth.createUserWithEmailAndPassword(
              email: 'admin@captainmasala.com',
              password: 'password123',
            );
            return await _fetchAndSetUserRole(createCred.user!);
          } catch (_) {
            // Already exists or other error, fall through to invalid
          }
        }
        return 'invalid';
      }
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        return 'network_error';
      }
      return 'invalid';
    } catch (e) {
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
      if (username.trim().toLowerCase() == 'admin' ||
          username.trim().toLowerCase() == 'superadmin') {
        return 'error'; // Block protected usernames
      }

      // Check if username is taken by another user
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return 'error'; // Username is taken
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;

      // Sellers must be approved by Super Admin first
      final storedRole = role == 'super_admin' ? 'super_admin' : 'pending';
      
      _currentUserProfile = AppUser(
        id: user.uid,
        email: email,
        role: storedRole,
        name: name,
        phoneNumber: phone,
        username: username,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(_currentUserProfile!.toMap());
      notifyListeners();
      // Sellers always go to pending; super_admin bypasses
      return role == 'super_admin' ? 'super_admin' : 'pending';
    } catch (e) {
      return 'error';
    }
  }

  Future<String> _fetchAndSetUserRole(User user) async {
    DocumentSnapshot? doc;
    try {
      doc = await _firestore.collection('users').doc(user.uid).get(
        const GetOptions(source: Source.server),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Server timeout or offline — fall back to cache
      try {
        doc = await _firestore.collection('users').doc(user.uid).get(
          const GetOptions(source: Source.cache),
        );
      } catch (_) {
        doc = null;
      }
    }

    if (doc != null && doc.exists) {
      _currentUserProfile = AppUser.fromMap(doc.data()! as Map<String, dynamic>);
      // Auto-repair missing email for old seeded Super Admin accounts
      if (_currentUserProfile!.email.isEmpty && user.email != null) {
        _currentUserProfile = AppUser(
          id: _currentUserProfile!.id,
          email: user.email!,
          role: _currentUserProfile!.role,
          name: _currentUserProfile!.name,
          phoneNumber: _currentUserProfile!.phoneNumber,
          username: _currentUserProfile!.username,
        );
        try {
          await _firestore.collection('users').doc(user.uid).update({
            'email': user.email!,
          }).timeout(const Duration(seconds: 3));
        } catch (_) {
          // Offline, skip repair — will retry next online session
        }
      }
    } else {
      return await _createUserDocument(user);
    }
    notifyListeners();
    return _currentUserProfile!.role;
  }

  Future<String> _createUserDocument(User user) async {
    // Make the first admin user the super_admin
    String role = 'pending';
    String username = '';
    if (user.email == 'admin@captainmasala.com') {
      role = 'super_admin';
      username = 'admin'; // Seed initial username
    }
    _currentUserProfile = AppUser(
      id: user.uid,
      email: user.email ?? '',
      role: role,
      username: username,
    );
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(_currentUserProfile!.toMap());
    notifyListeners();
    return role;
  }

  Future<List<AppUser>> getActiveUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data()))
        .where((user) => user.role == 'seller' || user.role == 'delivery')
        .toList();
  }

  Future<List<AppUser>> getPendingUsers() async {
    final pendingSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'pending')
        .get();
        
    final requestedRoleSnapshot = await _firestore
        .collection('users')
        .where('requestedRole', isNull: false)
        .get();

    final allUsers = [
      ...pendingSnapshot.docs.map((doc) => AppUser.fromMap(doc.data())),
      ...requestedRoleSnapshot.docs.map((doc) => AppUser.fromMap(doc.data()))
    ];
    
    // Remove duplicates
    final uniqueUsers = <String, AppUser>{};
    for (var u in allUsers) {
      uniqueUsers[u.id] = u;
    }
    return uniqueUsers.values.toList();
  }

  Future<void> changeUserRole(String userId, String newRole) async {
    await _firestore.collection('users').doc(userId).update({
      'role': newRole,
    });
  }

  Future<void> approveUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      final user = AppUser.fromMap(doc.data()!);
      final newRole = user.requestedRole ?? 'seller';
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'requestedRole': null,
      });
    }
  }

  Future<void> rejectUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      final user = AppUser.fromMap(doc.data()!);
      if (user.role == 'pending') {
        await _firestore.collection('users').doc(userId).delete();
      } else {
        await _firestore.collection('users').doc(userId).update({
          'requestedRole': null,
        });
      }
    }
  }

  Future<bool> requestRoleChange(String newRole) async {
    if (_currentUserProfile == null) return false;
    try {
      await _firestore.collection('users').doc(_currentUserProfile!.id).update({
        'requestedRole': newRole,
      });
      // Update local profile
      _currentUserProfile = AppUser(
        id: _currentUserProfile!.id,
        email: _currentUserProfile!.email,
        role: _currentUserProfile!.role,
        requestedRole: newRole,
        name: _currentUserProfile!.name,
        phoneNumber: _currentUserProfile!.phoneNumber,
        username: _currentUserProfile!.username,
      );
      notifyListeners();
      return true;
    } catch (e) {
      print("Error requesting role change: $e");
      return false;
    }
  }

  Future<bool> updateUserProfile(
    String name,
    String phone,
    String username,
  ) async {
    if (_currentUserProfile == null) return false;

    try {
      // Check if username is taken by another user
      if (username != _currentUserProfile!.username) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          // Username is already taken
          return false;
        }
      }

      await _firestore.collection('users').doc(_currentUserProfile!.id).update({
        'name': name,
        'phoneNumber': phone,
        'username': username,
      });

      _currentUserProfile = AppUser(
        id: _currentUserProfile!.id,
        email: _currentUserProfile!.email,
        role: _currentUserProfile!.role,
        name: name,
        phoneNumber: phone,
        username: username,
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);
        return true;
      }
    } catch (e) {
      debugPrint("Error changing password: $e");
      return false;
    }
    return false;
  }

  // --- Product Actions ---

  List<Product> getProductsForCategory(String categoryId) {
    return _products.where((p) => p.isEnabled && p.categoryId == categoryId).toList();
  }

  Future<void> addProduct(Product product) async {
    // Auto-create the MasterProduct if it doesn't exist yet
    if (product.masterProductId.isNotEmpty) {
      final mIndex = _masterProducts.indexWhere((m) => m.id == product.masterProductId);
      if (mIndex == -1) {
        final masterName = product.masterProductId.replaceAll('_', ' ').toUpperCase();
        await addMasterProduct(MasterProduct(
          id: product.masterProductId,
          name: masterName,
          totalStockKg: product.remainingStock,
        ));
      } else {
        if (product.remainingStock > 0) {
          final existingMaster = _masterProducts[mIndex];
          await updateMasterProduct(MasterProduct(
            id: existingMaster.id,
            name: existingMaster.name,
            totalStockKg: existingMaster.totalStockKg + product.remainingStock,
          ));
        }
      }
    }

    await _firestore
        .collection('products')
        .doc(product.id)
        .set(product.toMap());

    await addInventoryLog(
      InventoryLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: product.id,
        productName: product.name,
        changeQuantity: product.remainingStock,
        type: 'Monthly Entry',
        dateTime: DateTime.now(),
        notes: 'Initial Product Stock Added',
      ),
    );
  }

  Future<void> updateProduct(Product updated) async {
    await _firestore
        .collection('products')
        .doc(updated.id)
        .update(updated.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('products').doc(id).delete();
  }

  // --- Master Product Actions ---

  Future<void> addMasterProduct(MasterProduct master) async {
    await _firestore
        .collection('master_products')
        .doc(master.id)
        .set(master.toMap());
  }

  Future<void> updateMasterProduct(MasterProduct updated) async {
    await _firestore
        .collection('master_products')
        .doc(updated.id)
        .update(updated.toMap());
  }

  Future<void> deleteMasterProduct(String id) async {
    await _firestore.collection('master_products').doc(id).delete();
    
    // Also delete all product variants associated with this master product
    final querySnapshot = await _firestore.collection('products').where('masterProductId', isEqualTo: id).get();
    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }


  // --- Category Actions ---

  Future<void> addCategory(ProductCategory category) async {
    await _firestore
        .collection('categories')
        .doc(category.id)
        .set(category.toMap());
  }

  Future<void> updateCategory(ProductCategory category) async {
    await _firestore
        .collection('categories')
        .doc(category.id)
        .update(category.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await _firestore.collection('categories').doc(id).delete();
  }

  // --- Stock Entries ---

  Future<void> updateMasterStock(String masterId, double newOpeningStock, String notes) async {
    final mIndex = _masterProducts.indexWhere((m) => m.id == masterId);
    if (mIndex != -1) {
      final oldStock = _masterProducts[mIndex].totalStockKg;
      final diff = newOpeningStock - oldStock;

      await _firestore.collection('master_products').doc(masterId).update({
        'totalStockKg': newOpeningStock,
      });

      await addInventoryLog(
        InventoryLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          productId: masterId,
          productName: _masterProducts[mIndex].name,
          changeQuantity: diff,
          type: 'Monthly Entry',
          dateTime: DateTime.now(),
          notes: notes,
        ),
      );
    }
  }

  Future<void> updateStock(
    String productId,
    double newOpeningStock,
    String notes,
  ) async {
    final index = _products.indexWhere((e) => e.id == productId);
    if (index != -1) {
      final oldStock = _products[index].remainingStock;
      final diff = newOpeningStock - oldStock;

      await _firestore.collection('products').doc(productId).update({
        'remainingStock': newOpeningStock,
      });

      await addInventoryLog(
        InventoryLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          productId: productId,
          productName: _products[index].name,
          changeQuantity: diff,
          type: 'Monthly Entry',
          dateTime: DateTime.now(),
          notes: notes,
        ),
      );
    }
  }

  // --- Customer Actions ---

  Future<void> addCustomer(Customer customer) async {
    await _firestore
        .collection('customers')
        .doc(customer.id)
        .set(customer.toMap());
  }

  Future<void> updateCustomer(Customer customer) async {
    // Optimistic UI update for immediate reflection even when offline
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      notifyListeners();
    }

    try {
      await _firestore
          .collection('customers')
          .doc(customer.id)
          .update(customer.toMap());
    } catch (e) {
      debugPrint('Error updating customer in Firestore: $e');
    }
  }

  Future<void> deleteCustomer(String id) async {
    await _firestore.collection('customers').doc(id).delete();
  }

  // --- Sales Entry & Invoicing ---
  
  double getPackSizeInKg(String packSize) {
    final lower = packSize.toLowerCase();
    
    // Exact match for the 1 kg bag filled with 50g packets
    if (lower == '50 gram - 1 kg bag' || lower == '50g - 1kg bag' || (lower.contains('50') && lower.contains('1 kg'))) {
      return 1.0; 
    }
    
    if (lower.contains('kg')) {
      final match = RegExp(r'([0-9.]+)\s*kg').firstMatch(lower);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? 1.0;
      }
    } else if (lower.contains('gram') || lower.contains(' g') || lower.endsWith('g')) {
      final match = RegExp(r'([0-9.]+)\s*(?:gram|g)').firstMatch(lower);
      if (match != null) {
        return (double.tryParse(match.group(1)!) ?? 0.0) / 1000.0;
      }
    }
    
    return 1.0; // fallback
  }

  Future<void> recordSale(Sale sale) async {
    await _firestore.collection('sales').doc(sale.id).set(sale.toMap());

    for (var item in sale.items) {
      final pIndex = _products.indexWhere((p) => p.id == item.productId);
      if (pIndex != -1) {
        final product = _products[pIndex];
        
        // Update Master Product Inventory
        final masterId = product.masterProductId;
        if (masterId.isNotEmpty) {
          final mIndex = _masterProducts.indexWhere((m) => m.id == masterId);
          if (mIndex != -1) {
            final weightInKg = getPackSizeInKg(product.packSize);
            final qtyInKg = item.quantity * weightInKg;
            final newMasterStock = _masterProducts[mIndex].totalStockKg - qtyInKg;

            await _firestore.collection('master_products').doc(masterId).update({
              'totalStockKg': newMasterStock,
            });

            await addInventoryLog(
              InventoryLog(
                id: '${sale.id}_${item.productId}',
                productId: masterId,
                productName: _masterProducts[mIndex].name,
                changeQuantity: -qtyInKg,
                type: 'Sale Deduction',
                dateTime: sale.dateTime,
                notes: 'Invoice: ${sale.invoiceNumber} (${item.quantity}x ${product.packSize})',
              ),
            );
          }
        }
      }
    }
  }

  Future<void> updatePaymentStatus(String saleId, String status) async {
    await _firestore.collection('sales').doc(saleId).update({
      'paymentStatus': status,
    });
  }

  Future<void> updatePrepaidAmount(String saleId, double additionalPrepaidAmount, double finalAmount) async {
    final saleDoc = await _firestore.collection('sales').doc(saleId).get();
    if (saleDoc.exists) {
      final currentPrepaid = (saleDoc.data()?['prepaidAmount'] ?? 0.0) as num;
      final newPrepaid = currentPrepaid.toDouble() + additionalPrepaidAmount;
      String status = (saleDoc.data()?['paymentStatus'] ?? 'Pending') as String;
      
      if (newPrepaid >= finalAmount) {
        status = 'Paid';
      }

      await _firestore.collection('sales').doc(saleId).update({
        'prepaidAmount': newPrepaid,
        'paymentStatus': status,
      });
    }
  }

  Future<void> cancelSale(String saleId, String reason) async {
    await _firestore.collection('sales').doc(saleId).update({
      'status': 'Cancelled',
      'cancelReason': reason,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markSaleDelivered(String saleId) async {
    await _firestore
        .collection('sales')
        .doc(saleId)
        .update({
          'deliveryStatus': 'Delivered',
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  Future<void> updateDeliveryStatus(String saleId, String status) async {
    await _firestore
        .collection('sales')
        .doc(saleId)
        .update({
          'deliveryStatus': status,
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  Future<void> updateSale(Sale sale) async {
    await _firestore.collection('sales').doc(sale.id).update(sale.toMap());
  }

  // --- Inventory Log ---

  Future<void> addInventoryLog(InventoryLog log) async {
    await _firestore.collection('inventoryLogs').doc(log.id).set(log.toMap());
  }
}
