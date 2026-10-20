import '../widgets/address_picker.dart';
import 'region.dart';

/// The labels a user can give an address; keep in sync with
/// UserAddress::LABELS on the backend.
const userAddressLabels = ['Rumah', 'Kantor', 'Kost', 'Kontrakan', 'Hotel'];

/// A delivery address the user saved, offered at checkout to pick from.
class UserAddress {
  UserAddress({
    required this.id,
    this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.province,
    required this.city,
    required this.district,
    required this.village,
    required this.detail,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) => UserAddress(
    id: json['id'] as String,
    label: json['label'] as String?,
    recipientName: json['recipient_name'] as String,
    recipientPhone: json['recipient_phone'] as String,
    province: Region.fromJson(json['province'] as Map<String, dynamic>),
    city: Region.fromJson(json['city'] as Map<String, dynamic>),
    district: Region.fromJson(json['district'] as Map<String, dynamic>),
    village: Region.fromJson(json['village'] as Map<String, dynamic>),
    detail: json['address_detail'] as String,
  );

  final String id;
  final String? label;
  final String recipientName;
  final String recipientPhone;
  final Region province;
  final Region city;
  final Region district;
  final Region village;
  final String detail;

  AddressSelection get region => AddressSelection(
    province: province,
    city: city,
    district: district,
    village: village,
  );

  String get regionLine =>
      [village.name, district.name, city.name, province.name].join(', ');
}

/// What the address form sends to create or update a [UserAddress].
class UserAddressInput {
  const UserAddressInput({
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.region,
    required this.detail,
  });

  final String label;
  final String recipientName;
  final String recipientPhone;
  final AddressSelection region;
  final String detail;

  Map<String, dynamic> toJson() => {
    'label': label,
    'recipient_name': recipientName,
    'recipient_phone': recipientPhone,
    'province_code': region.province!.code,
    'city_code': region.city!.code,
    'district_code': region.district!.code,
    'village_code': region.village!.code,
    'address_detail': detail,
  };
}
