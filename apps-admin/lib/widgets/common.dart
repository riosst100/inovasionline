import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../core/api/api_exception.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.size = 56, this.radius = 8});

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppColors.surface,
      child: Icon(Icons.image_outlined, color: AppColors.mutedForeground, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url!.isEmpty
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Icon(icon, size: 48, color: AppColors.border),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedForeground),
        ),
      ],
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.mutedForeground),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

/// Search field that reports its text after the user pauses typing.
class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();
  Future<void>? _pending;

  void _changed(String value) {
    final pending = _pending = Future.delayed(const Duration(milliseconds: 400));
    pending.then((_) {
      if (mounted && identical(pending, _pending)) widget.onChanged(value.trim());
    });
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: _changed,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.search),
      isDense: true,
      suffixIcon: _controller.text.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _changed('');
              },
            ),
    ),
  );
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppColors.destructive : null));
}

void showError(BuildContext context, Object error) => showMessage(context, errorMessage(error), error: true);

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.destructive) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
