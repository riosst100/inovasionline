class PaginatedMeta {
  PaginatedMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory PaginatedMeta.fromJson(Map<String, dynamic> json) => PaginatedMeta(
        currentPage: json['current_page'] as int? ?? 1,
        lastPage: json['last_page'] as int? ?? 1,
        perPage: json['per_page'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
      );

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

class PaginatedResult<T> {
  PaginatedResult({required this.data, required this.meta});

  final List<T> data;
  final PaginatedMeta meta;
}
