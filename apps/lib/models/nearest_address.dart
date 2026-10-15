/// A delivery address derived from the device location: the nearest served
/// village plus a readable label ("Village, District, City").
class NearestAddress {
  const NearestAddress({
    required this.provinceCode,
    required this.cityCode,
    required this.districtCode,
    required this.villageCode,
    required this.label,
  });

  factory NearestAddress.fromJson(Map<String, dynamic> json) => NearestAddress(
        provinceCode: json['province_code'] as String,
        cityCode: json['city_code'] as String,
        districtCode: json['district_code'] as String,
        villageCode: json['village_code'] as String,
        label: json['label'] as String,
      );

  final String provinceCode;
  final String cityCode;
  final String districtCode;
  final String villageCode;
  final String label;

  Map<String, dynamic> toJson() => {
        'province_code': provinceCode,
        'city_code': cityCode,
        'district_code': districtCode,
        'village_code': villageCode,
        'label': label,
      };
}
