class UserModel {

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? profilePhotoUrl;
  final String? identityDocumentUrl;
  final String? identityDocumentType;
  final bool isProfileComplete;
  final double rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? status;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.profilePhotoUrl,
    this.identityDocumentUrl,
    this.identityDocumentType,
    this.isProfileComplete = false,
    required this.rating,
    this.createdAt,
    this.updatedAt,
    this.status,
  });

  factory UserModel.fromJson(Map<String,dynamic> json){

    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      address: json['address'],
      profilePhotoUrl: json['profile_photo_url'],
      identityDocumentUrl: json['identity_document_url'],
      identityDocumentType: json['identity_document_type'],
      isProfileComplete: json['is_profile_complete'] ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      status: json['status'],
    );
  }

  Map<String,dynamic> toJson(){

    return {
      "id": id,
      "name": name,
      "phone": phone,
      if (email != null) "email": email,
      if (address != null) "address": address,
      if (profilePhotoUrl != null) "profile_photo_url": profilePhotoUrl,
      if (identityDocumentUrl != null) "identity_document_url": identityDocumentUrl,
      if (identityDocumentType != null) "identity_document_type": identityDocumentType,
      "is_profile_complete": isProfileComplete,
      "rating": rating,
      if (createdAt != null) "created_at": createdAt!.toIso8601String(),
      if (updatedAt != null) "updated_at": updatedAt!.toIso8601String(),
      "status": status ?? 'pending',
    };
  }
}