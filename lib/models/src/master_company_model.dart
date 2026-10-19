import 'dart:convert';
import '/models/models.dart';

/// A Master Company: company details plus its primary contact, kept in its
/// own collection (`masterCompanies`).
class MasterCompanyModel {
  final String? uid;
  final String companyName;
  final String? logoUrl;
  final String? gstVatNumber;
  final String contactName;
  final String mobileNumber;
  final String? email;
  final String? companyAddress;
  final UserDataModel createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MasterCompanyModel({
    this.uid,
    required this.companyName,
    this.logoUrl,
    this.gstVatNumber,
    required this.contactName,
    required this.mobileNumber,
    this.email,
    this.companyAddress,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  MasterCompanyModel copyWith({
    String? uid,
    String? companyName,
    String? logoUrl,
    bool clearLogo = false,
    String? gstVatNumber,
    String? contactName,
    String? mobileNumber,
    String? email,
    String? companyAddress,
    UserDataModel? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MasterCompanyModel(
      uid: uid ?? this.uid,
      companyName: companyName ?? this.companyName,
      logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
      gstVatNumber: gstVatNumber ?? this.gstVatNumber,
      contactName: contactName ?? this.contactName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      companyAddress: companyAddress ?? this.companyAddress,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'companyName': companyName,
    'logoUrl': logoUrl,
    'gstVatNumber': gstVatNumber,
    'contactName': contactName,
    'mobileNumber': mobileNumber,
    'email': email,
    'companyAddress': companyAddress,
    'createdBy': createdBy.toMap(),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory MasterCompanyModel.fromMap(String uid, Map<String, dynamic> map) {
    DateTime ts(dynamic v) => v is int
        ? DateTime.fromMillisecondsSinceEpoch(v)
        : DateTime.now();
    return MasterCompanyModel(
      uid: uid,
      companyName: (map['companyName'] ?? '') as String,
      logoUrl: map['logoUrl'] as String?,
      gstVatNumber: map['gstVatNumber'] as String?,
      contactName: (map['contactName'] ?? '') as String,
      mobileNumber: (map['mobileNumber'] ?? '') as String,
      email: map['email'] as String?,
      companyAddress: map['companyAddress'] as String?,
      createdBy: map['createdBy'] is Map<String, dynamic>
          ? UserDataModel.fromMap(map['createdBy'] as Map<String, dynamic>)
          : UserDataModel.fromEmptyMap(),
      createdAt: ts(map['createdAt']),
      updatedAt: ts(map['updatedAt']),
    );
  }

  String toJson() => json.encode(toMap());
}