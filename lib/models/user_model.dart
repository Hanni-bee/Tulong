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
