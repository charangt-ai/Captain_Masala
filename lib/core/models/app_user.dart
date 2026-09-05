class AppUser {
  final String id;
  final String email;
  final String role; // 'super_admin', 'admin', 'pending', 'seller', 'salesperson', 'delivery_person'
  final String? requestedRole;
  final String name;
  final String phoneNumber;
  final String username;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.requestedRole,
    this.name = '',
    this.phoneNumber = '',
    this.username = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'requestedRole': requestedRole,
      'name': name,
      'phoneNumber': phoneNumber,
      'username': username,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'pending',
      requestedRole: map['requestedRole'],
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      username: map['username'] ?? '',
    );
  }
}
