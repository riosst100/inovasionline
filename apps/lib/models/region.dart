class Region {
  Region({required this.code, required this.name});

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        code: json['code'] as String,
        name: json['name'] as String,
      );

  final String code;
  final String name;

  Map<String, dynamic> toJson() => {'code': code, 'name': name};

  // By code, so a region loaded elsewhere (e.g. a saved address) matches the
  // same entry in a freshly fetched dropdown list.
  @override
  bool operator ==(Object other) => other is Region && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
