/// User role in the system.
enum UserRole { customer, admin }

/// Delivery address associated with a user.
class Address {
  const Address({
    required this.label,
    required this.street,
    required this.city,
  });

  final String label;
  final String street;
  final String city;

  /// Mirrors Firestore document shape.
  Map<String, dynamic> toMap() => {
        'label': label,
        'street': street,
        'city': city,
      };

  factory Address.fromMap(Map<String, dynamic> map) => Address(
        label: map['label'] as String,
        street: map['street'] as String,
        city: map['city'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.label == label &&
      other.street == street &&
      other.city == city;

  @override
  int get hashCode => Object.hash(label, street, city);
}

/// Application user model — mirrors Firestore `users/{uid}` document.
class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.favorites = const [],
    this.stamps = 0,
    this.addresses = const [],
    this.fcmToken,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final List<String> favorites; // item IDs
  final int stamps;
  final List<Address> addresses;
  final String? fcmToken;

  bool get isAdmin => role == UserRole.admin;

  /// Creates a copy with optional field overrides.
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    List<String>? favorites,
    int? stamps,
    List<Address>? addresses,
    String? fcmToken,
  }) =>
      UserModel(
        uid: uid ?? this.uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        favorites: favorites ?? this.favorites,
        stamps: stamps ?? this.stamps,
        addresses: addresses ?? this.addresses,
        fcmToken: fcmToken ?? this.fcmToken,
      );

  /// Mirrors Firestore document shape.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'favorites': favorites,
        'stamps': stamps,
        'addresses': addresses.map((a) => a.toMap()).toList(),
        'fcmToken': fcmToken,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        phone: map['phone'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => UserRole.customer,
        ),
        favorites: List<String>.from(map['favorites'] as List? ?? []),
        stamps: (map['stamps'] as num?)?.toInt() ?? 0,
        addresses: (map['addresses'] as List? ?? [])
            .map((a) => Address.fromMap(a as Map<String, dynamic>))
            .toList(),
        fcmToken: map['fcmToken'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is UserModel && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);
}
