import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../core/api/paginated.dart';
import 'common.dart';

/// Infinite-scrolling, pull-to-refresh list over a paginated endpoint.
/// Give it a new [Key] when its filters change to restart from page 1; use a
/// [GlobalKey<PagedListState>] to [PagedListState.refresh] it from outside.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyText = 'Belum ada data.',
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96),
  });

  final Future<PaginatedResult<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final IconData emptyIcon;
  final String emptyText;
  final EdgeInsets padding;

  @override
  State<PagedList<T>> createState() => PagedListState<T>();
}

class PagedListState<T> extends State<PagedList<T>> {
  final _items = <T>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> refresh() async {
    _generation++;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    await _loadMore();
  }

  /// Swaps one item in place (e.g. after editing it on a detail screen).
  void replaceWhere(bool Function(T item) test, T replacement) {
    final index = _items.indexWhere(test);
    if (index != -1) setState(() => _items[index] = replacement);
  }

  void removeWhere(bool Function(T item) test) => setState(() => _items.removeWhere(test));

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.fetch(_page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(result.data);
        _page = result.meta.currentPage;
        _hasMore = result.meta.hasMore;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            _error != null
                ? ErrorView(message: errorMessage(_error!), onRetry: refresh)
                : EmptyView(icon: widget.emptyIcon, text: widget.emptyText),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _loadMore();
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding,
          itemCount: _items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index < _items.length) return widget.itemBuilder(context, _items[index]);
            if (_error != null) {
              return TextButton(onPressed: _loadMore, child: const Text('Gagal memuat. Coba lagi'));
            }
            return _hasMore
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
