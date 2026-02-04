import 'package:sqflow_core/sqflow_core.dart';

part 'user.sql.g.dart';

@Schema(
  tableName: 'users',
  paranoid: true,
  indexes: [
    Index(columns: ['email'], unique: true),
    Index(columns: ['first_name', 'last_name']),
  ],
)
class User extends Model {
  @ID(type: DataTypes.TEXT, autoIncrement: false, unique: true)
  final String id;

  @Column(type: DataTypes.TEXT)
  final String firstName;

  @Column(type: DataTypes.TEXT)
  final String lastName;

  @Column(type: DataTypes.TEXT, unique: true)
  final String email;

  @Column(type: DataTypes.TEXT)
  final String phone;

  @Column(type: DataTypes.TEXT, nullable: true)
  final String? birthDate;

  @Column(type: DataTypes.INTEGER, nullable: true)
  final int? age;

  @Column(
    type: DataTypes.TEXT,
    nullable: false,
    check: CHECK(['M', 'F', 'Other']),
  )
  final String gender;

  @Column(type: DataTypes.TEXT)
  final String city;

  @Column(type: DataTypes.TEXT)
  final String country;

  @Column(type: DataTypes.TEXT, nullable: true)
  final String? address;

  @Column(type: DataTypes.BOOLEAN, defaultValue: true)
  final bool isActive;

  @Column(type: DataTypes.BOOLEAN, defaultValue: false)
  final bool isVerified;

  @Column(type: DataTypes.DATETIME)
  final DateTime createdAt;

  @Column(type: DataTypes.DATETIME, nullable: true)
  final DateTime? updatedAt;

  @Column(type: DataTypes.DATETIME, nullable: true)
  final DateTime? deletedAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.birthDate,
    this.age,
    required this.gender,
    required this.city,
    required this.country,
    this.address,
    this.isActive = true,
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  Table<User> get table => _$usersTable;

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'birth_date': birthDate,
      'age': age,
      'gender': gender,
      'city': city,
      'country': country,
      'address': address,
      'is_active': isActive ? 1 : 0, // SQLite BOOLEAN as INTEGER
      'is_verified': isVerified ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      birthDate: json['birth_date'] as String?,
      age: json['age'] != null ? (json['age'] as num).toInt() : null,
      gender: json['gender'] as String? ?? 'Other', // Default value
      city: json['city'] as String? ?? '', // Default value
      country: json['country'] as String? ?? '', // Default value
      address: json['address'] as String?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      isVerified: json['is_verified'] == 1 || json['is_verified'] == true,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
    );
  }

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? birthDate,
    int? age,
    String? gender,
    String? city,
    String? country,
    String? address,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      country: country ?? this.country,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
