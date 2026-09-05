class Permissions {
  static bool isSuperAdmin(String? role) => role == 'super_admin';
  static bool isAdmin(String? role) => role == 'super_admin' || role == 'admin';
  
  static bool canManageInventory(String? role) => role == 'super_admin';
  static bool canViewAllSales(String? role) => role == 'super_admin' || role == 'admin';
  static bool canViewReports(String? role) => role == 'super_admin' || role == 'admin';
  
  static bool isDeliveryOnly(String? role) => role == 'delivery';
  static bool isSellerOrSales(String? role) => role == 'seller' || role == 'salesperson';
  static bool isSeller(String? role) => role == 'seller';
  
  static bool canUpdateDeliveryStatus(String? role) => 
      role == 'super_admin' || role == 'admin' || role == 'seller' || role == 'delivery';
      
  static bool canEditOrder(String? role) => role == 'super_admin';
  static bool canManageUsers(String? role) => role == 'super_admin';
}
