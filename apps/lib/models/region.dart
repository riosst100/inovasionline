class Region {
  Region({required this.code, required this.name});

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        code: json['code'] as String,
        name: json['name'] as String,
      );

  final String code;
  final String name;
}
