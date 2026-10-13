import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/banner.dart';

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.banners});

  final List<AppBanner> banners;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _controller;
  Timer? _timer;
  int _virtualPage = 0;
  static const int _infiniteMultiplier = 10000;

  int get _itemCount => widget.banners.length;

  int _calculateInitialPage() {
    if (_itemCount <= 1) return 0;
    return (_infiniteMultiplier ~/ 2) * _itemCount;
  }

  @override
  void initState() {
    super.initState();
    _virtualPage = _calculateInitialPage();
    _controller = PageController(initialPage: _virtualPage);
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _timer?.cancel();
      _virtualPage = _calculateInitialPage();
      _controller.dispose();
      _controller = PageController(initialPage: _virtualPage);
      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _handleTap(int index) {
    if (index >= widget.banners.length) return;
    final banner = widget.banners[index];
    final link = banner.linkUrl?.trim();
    if (link != null && link.isNotEmpty) {
      if (link.startsWith('/')) {
        context.push(link);
        return;
      }
      if (link.startsWith('http://') || link.startsWith('https://')) {
        showDialog(
          context: context,
          barrierColor: Colors.black,
          builder: (context) => _BannerPreviewDialog(banners: widget.banners, initialIndex: index),
        );
        return;
      }
    }
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => _BannerPreviewDialog(banners: widget.banners, initialIndex: index),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    final count = banners.length;
    if (count == 0) return const SizedBox.shrink();
    final hasMultiple = count > 1;
    final activeIndex = count > 0 ? _virtualPage % count : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 156,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFF8FAFC),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  _timer?.cancel();
                } else if (notification is ScrollEndNotification) {
                  _startAutoSlide();
                }
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: hasMultiple ? null : 1,
                onPageChanged: (index) {
                  setState(() => _virtualPage = index);
                },
                itemBuilder: (context, index) {
                  final bannerIndex = ((index % count) + count) % count;
                  final banner = banners[bannerIndex];
                  return GestureDetector(
                    onTap: () => _handleTap(bannerIndex),
                    child: CachedNetworkImage(
                      imageUrl: banner.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (_, _) => Container(color: const Color(0xFFF1F5F9)),
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 36),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (hasMultiple)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(count, (index) {
                    final active = index == activeIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: active ? 16 : 6,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BannerPreviewDialog extends StatefulWidget {
  const _BannerPreviewDialog({required this.banners, required this.initialIndex});

  final List<AppBanner> banners;
  final int initialIndex;

  @override
  State<_BannerPreviewDialog> createState() => _BannerPreviewDialogState();
}

class _BannerPreviewDialogState extends State<_BannerPreviewDialog> {
  WebViewController? _webController;
  bool _webLoading = true;
  String _currentUrl = '';
  late final PageController _pageController;
  late int _page;

  AppBanner get _initialBanner => widget.banners[widget.initialIndex];

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    final linkUrl = _initialBanner.linkUrl;
    if (linkUrl != null && linkUrl.isNotEmpty && Uri.tryParse(linkUrl) != null) {
      _currentUrl = linkUrl;
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) => setState(() {
              _webLoading = true;
              _currentUrl = url;
            }),
            onPageFinished: (url) => setState(() {
              _webLoading = false;
              _currentUrl = url;
            }),
          ),
        )
        ..loadRequest(Uri.parse(linkUrl));
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(_currentUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _refresh() async {
    await _webController?.reload();
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(uri: Uri.parse(_currentUrl)));
  }

  String get _hostLabel {
    final uri = Uri.tryParse(_currentUrl);
    return uri?.host.isNotEmpty == true ? uri!.host : _currentUrl;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final webController = _webController;

    if (webController == null) {
      final banners = widget.banners;
      final hasMultiple = banners.length > 1;
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: banners.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: banners[index].imageUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            if (hasMultiple)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(banners.length, (index) {
                      final active = index == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 6,
                        width: active ? 16 : 6,
                        decoration: BoxDecoration(
                          color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Dialog.fullscreen(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock, size: 13, color: Colors.black54),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _hostLabel,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Inovasi Online',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Muat ulang',
                    onPressed: _refresh,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'refresh':
                          _refresh();
                          break;
                        case 'browser':
                          _openInBrowser();
                          break;
                        case 'share':
                          _share();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'refresh', child: Text('Muat ulang')),
                      PopupMenuItem(value: 'browser', child: Text('Buka di browser')),
                      PopupMenuItem(value: 'share', child: Text('Bagikan')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_webLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: WebViewWidget(controller: webController)),
        ],
      ),
    );
  }
}
