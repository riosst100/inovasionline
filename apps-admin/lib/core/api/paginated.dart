class PaginatedMeta {
  PaginatedMeta({required this.currentPage, required this.lastPage, required this.total});

  factory PaginatedMeta.fromJson(Map<String, dynamic>? json) => PaginatedMeta(
    currentPage: json?['current_page'] as int? ?? 1,
    lastPage: json?['last_page'] as int? ?? 1,
    total: json?['total'] as int? ?? 0,
  );

  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

class PaginatedResult<T> {
  PaginatedResult({required this.data, required this.meta});

  /// Parses the backend envelope `{data: [...], meta: {...}}`.
  factory PaginatedResult.fromEnvelope(Map<String, dynamic> body, T Function(Map<String, dynamic>) fromJson) =>
      PaginatedResult(
        data: (body['data'] as List? ?? []).map((e) => fromJson(e as Map<String, dynamic>)).toList(),
        meta: PaginatedMeta.fromJson(body['meta'] as Map<String, dynamic>?),
      );

  final List<T> data;
  final PaginatedMeta meta;
}
