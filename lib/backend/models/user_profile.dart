import 'package:cloud_firestore/cloud_firestore.dart';

class UserAddress {
  const UserAddress({
    required this.id,
    required this.label,
    required this.line1,
    required this.city,
    this.notes = '',
    this.lat,
    this.lng,
  });

  final String id;
  final String label;
  final String line1;
  final String city;
  final String notes;
  final double? lat;
  final double? lng;

  String get fullAddress => city.isNotEmpty ? '$line1, $city' : line1;
  String get addressLine => fullAddress;

  factory UserAddress.fromMap(Map<String, dynamic> map) {
    return UserAddress(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      line1: map['line1'] as String? ?? '',
      city: map['city'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'line1': line1,
      'city': city,
      'notes': notes,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
  }

  UserAddress copyWith({
    String? id,
    String? label,
    String? line1,
    String? city,
    String? notes,
    double? lat,
    double? lng,
  }) {
    return UserAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      line1: line1 ?? this.line1,
      city: city ?? this.city,
      notes: notes ?? this.notes,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAddress &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          line1 == other.line1 &&
          city == other.city &&
          notes == other.notes &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => Object.hash(id, label, line1, city, notes, lat, lng);
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'customer',
    this.favorites = const [],
    this.stamps = 0,
    this.addresses = const [],
    this.fcmToken,
    this.createdAt,
    this.isEmailVerified = true,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final List<String> favorites;
  final int stamps;
  final List<UserAddress> addresses;
  final String? fcmToken;
  final DateTime? createdAt;
  final bool isEmailVerified;

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff' || role == 'admin';
  bool get isCustomer => role == 'customer';

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserProfile.fromMap(data, uid: doc.id);
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, {required String uid}) {
    DateTime? parsedCreatedAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      parsedCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    } else if (rawCreatedAt is int) {
      parsedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
    }

    final rawAddresses = map['addresses'] as List<dynamic>? ?? [];
    final addresses = rawAddresses
        .map((a) => UserAddress.fromMap(Map<String, dynamic>.from(a as Map)))
        .toList();

    final rawFavorites = map['favorites'] as List<dynamic>? ?? [];
    final favorites = rawFavorites.map((f) => f.toString()).toList();

    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: map['role'] as String? ?? 'customer',
      favorites: favorites,
      stamps: (map['stamps'] as num?)?.toInt() ?? 0,
      addresses: addresses,
      fcmToken: map['fcmToken'] as String?,
      createdAt: parsedCreatedAt,
      isEmailVerified: map['isEmailVerified'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'favorites': favorites,
      'stamps': stamps,
      'addresses': addresses.map((a) => a.toMap()).toList(),
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'isEmailVerified': isEmailVerified,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? role,
    List<String>? favorites,
    int? stamps,
    List<UserAddress>? addresses,
    String? fcmToken,
    DateTime? createdAt,
    bool? isEmailVerified,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      favorites: favorites ?? this.favorites,
      stamps: stamps ?? this.stamps,
      addresses: addresses ?? this.addresses,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          name == other.name &&
          email == other.email &&
          phone == other.phone &&
          role == other.role &&
          listEquals(favorites, other.favorites) &&
          listEquals(addresses, other.addresses) &&
          stamps == other.stamps &&
          fcmToken == other.fcmToken &&
          isEmailVerified == other.isEmailVerified;

  static bool listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        uid,
        name,
        email,
        phone,
        role,
        Object.hashAll(favorites),
        Object.hashAll(addresses),
        stamps,
        fcmToken,
        isEmailVerified,
      );
}
