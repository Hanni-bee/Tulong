class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final bool isOnline;
  final String? lastSeen;
  final String status;
  final String? phone;
  final String? location;
  // Address fields - using snake_case for consistency
  final String street;
  final String region;
  final String barangay;
  final String city;
  final String province;
  // Setup completion
  final bool addressSetupCompleted;
  final bool isGoogleAuth;
  // Additional fields for consistency
  final String accountStatus;
  final int createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.isOnline = false,
    this.lastSeen,
    this.status = 'Offline',
    this.phone,
    this.location,
    this.street = '',
    this.region = '',
    this.barangay = '',
    this.city = '',
    this.province = '',
    this.addressSetupCompleted = false,
    this.isGoogleAuth = false,
    this.accountStatus = 'active',
    this.createdAt = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      avatar: map['avatar'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'],
      status: map['status'] ?? 'Offline',
      phone: map['phone'],
      location: map['location'],
      street: map['street'] ?? '',
      region: map['region'] ?? '',
      barangay: map['barangay'] ?? '',
      city: map['city'] ?? '',
      province: map['province'] ?? '',
      addressSetupCompleted: map['addressSetupCompleted'] ?? false,
      isGoogleAuth: map['isGoogleAuth'] ?? false,
      accountStatus: map['accountStatus'] ?? 'active',
      createdAt: map['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'status': status,
      'phone': phone,
      'location': location,
      'street': street,
      'region': region,
      'barangay': barangay,
      'city': city,
      'province': province,
      'addressSetupCompleted': addressSetupCompleted,
      'isGoogleAuth': isGoogleAuth,
      'accountStatus': accountStatus,
      'createdAt': createdAt,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatar,
    bool? isOnline,
    String? lastSeen,
    String? status,
    String? phone,
    String? location,
    String? street,
    String? region,
    String? barangay,
    String? city,
    String? province,
    bool? addressSetupCompleted,
    bool? isGoogleAuth,
    String? accountStatus,
    int? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      street: street ?? this.street,
      region: region ?? this.region,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      addressSetupCompleted: addressSetupCompleted ?? this.addressSetupCompleted,
      isGoogleAuth: isGoogleAuth ?? this.isGoogleAuth,
      accountStatus: accountStatus ?? this.accountStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, isOnline: $isOnline)';
  }
}
