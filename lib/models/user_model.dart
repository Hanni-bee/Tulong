class UserModel {
  final String id;
  final String name;
  final String username; // Replaced email with username
  final String? avatar;
  final bool isOnline;
  final String? lastSeen;
  final String status;
  final String? location;
  // Address fields - using snake_case for consistency
  final String street;
  final String region;
  final String barangay;
  final String city;
  final String province;
  final String? phoneNumber;
  // Getter for phone (alias for phoneNumber for compatibility)
  String? get phone => phoneNumber;
  // Setup completion
  final bool addressSetupCompleted;
  // Additional fields for consistency
  final String accountStatus;
  final int createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.username, // Replaced email with username
    this.avatar,
    this.isOnline = false,
    this.lastSeen,
    this.status = 'Offline',
    this.location,
    this.street = '',
    this.region = '',
    this.barangay = '',
    this.city = '',
    this.province = '',
    this.phoneNumber,
    this.addressSetupCompleted = false,
    this.accountStatus = 'active',
    this.createdAt = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Support both username and email (for migration)
    final username = map['username'] ?? map['email'] ?? '';
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      username: username,
      avatar: map['avatar'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'],
      status: map['status'] ?? 'Offline',
      location: map['location'],
      street: map['street'] ?? '',
      region: map['region'] ?? '',
      barangay: map['barangay'] ?? '',
      city: map['city'] ?? '',
      province: map['province'] ?? '',
      phoneNumber: map['phoneNumber'] ?? map['phone_number'] ?? map['phone'],
      addressSetupCompleted: map['addressSetupCompleted'] ?? false,
      accountStatus: map['accountStatus'] ?? 'active',
      createdAt: map['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username, // Replaced email with username
      'avatar': avatar,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'status': status,
      'location': location,
      'street': street,
      'region': region,
      'barangay': barangay,
      'city': city,
      'province': province,
      'phoneNumber': phoneNumber,
      'addressSetupCompleted': addressSetupCompleted,
      'accountStatus': accountStatus,
      'createdAt': createdAt,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? avatar,
    bool? isOnline,
    String? lastSeen,
    String? status,
    String? location,
    String? street,
    String? region,
    String? barangay,
    String? city,
    String? province,
    String? phoneNumber,
    bool? addressSetupCompleted,
    String? accountStatus,
    int? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
      location: location ?? this.location,
      street: street ?? this.street,
      region: region ?? this.region,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      addressSetupCompleted: addressSetupCompleted ?? this.addressSetupCompleted,
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
    return 'UserModel(id: $id, name: $name, username: $username, isOnline: $isOnline)';
  }
}
