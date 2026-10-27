import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/cart.dart';
import 'cart_providers.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cartProvider.notifier).load());
  }

  void _toggleItem(String itemId, bool selected) {
    ref.read(cartSelectionProvider.notifier).toggle(itemId, selected);
  }

  void _toggleAll(List<CartItem> items, bool selected) {
    ref
        .read(cartSelectionProvider.notifier)
        .toggleAll(items.where((item) => item.isAvailable).map((item) => item.id), selected);
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final selectedItemIds = ref.watch(cartSelectionProvider);
    final cart = cartState.cart;
    final itemCount = cart?.itemCount ?? 0;

    // Forget selections of items that were removed from the cart.
    ref.listen(cartProvider.select((s) => s.error), (_, error) {
      if (error != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error), behavior: SnackBarBehavior.floating));
      }
    });

    ref.listen(cartProvider.select((s) => s.cart), (_, next) {
      if (next != null) {
        ref.read(cartSelectionProvider.notifier).retainOnly(next.items.map((i) => i.id).toSet());
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(itemCount > 0 ? 'Keranjang ($itemCount)' : 'Keranjang'),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(cartProvider.notifier).load(),
        child: cartState.loading && cart == null
            ? const Center(child: CircularProgressIndicator())
            : cart == null && cartState.error != null
            ? _CartLoadError(message: cartState.error!, onRetry: () => ref.read(cartProvider.notifier).load())
            : cart == null || cart.isEmpty
            ? const _EmptyCart()
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  // Keeps rows readable on tablets instead of stretching edge to edge.
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      _CartItemsCard(
                        items: cart.items,
                        selectedItemIds: selectedItemIds,
                        busyItemIds: cartState.busyItemIds,
                        onToggleItem: _toggleItem,
                        onToggleAll: _toggleAll,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: cart == null || cart.isEmpty
          ? null
          : _CheckoutBar(
              selection: CartSelection(
                items: cart.items.where((i) => i.isAvailable && selectedItemIds.contains(i.id)).toList(),
              ),
            ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.selection});

  final CartSelection selection;

  @override
  Widget build(BuildContext context) {
    final total = selection.subtotal;
    final count = selection.items.length;
    final canCheckout = count > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 12, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count > 0 ? 'Subtotal ($count produk)' : 'Pilih produk untuk checkout',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCurrency(total),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.foreground),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: canCheckout ? () => context.push('/checkout', extra: selection) : null,
            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
            label: const Text('Checkout'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              minimumSize: const Size(0, 48),
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLoadError extends StatelessWidget {
  const _CartLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.mutedForeground),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.foreground),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Keranjang Anda kosong',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.foreground),
        ),
        const SizedBox(height: 6),
        const Text(
          'Yuk, temukan produk favorit Anda dan tambahkan ke keranjang.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
            child: const Text('Mulai Belanja'),
          ),
        ),
      ],
    );
  }
}

class _CartItemsCard extends ConsumerWidget {
  const _CartItemsCard({
    required this.items,
    required this.selectedItemIds,
    required this.busyItemIds,
    required this.onToggleItem,
    required this.onToggleAll,
  });

  final List<CartItem> items;
  final Set<String> selectedItemIds;
  final Set<String> busyItemIds;
  final void Function(String itemId, bool selected) onToggleItem;
  final void Function(List<CartItem> items, bool selected) onToggleAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = items.where((item) => item.isAvailable).toList();
    final selectedItems = available.where((item) => selectedItemIds.contains(item.id)).toList();
    final allSelected = available.isNotEmpty && selectedItems.length == available.length;
    final someSelected = selectedItems.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: available.isEmpty ? null : () => onToggleAll(items, !allSelected),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected ? true : (someSelected ? null : false),
                    tristate: true,
                    visualDensity: VisualDensity.compact,
                    onChanged: available.isEmpty ? null : (value) => onToggleAll(items, !allSelected),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Pilih Semua (${available.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  Text(
                    allSelected ? 'Batal pilih' : 'Pilih semua',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _CartItemTile(
              item: items[i],
              selected: items[i].isAvailable && selectedItemIds.contains(items[i].id),
              busy: busyItemIds.contains(items[i].id),
              onSelectedChanged: (selected) => onToggleItem(items[i].id, selected),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({
    required this.item,
    required this.selected,
    required this.busy,
    required this.onSelectedChanged,
  });

  final CartItem item;
  final bool selected;
  final bool busy;
  final ValueChanged<bool> onSelectedChanged;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('${item.productName} akan dihapus dari keranjang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await ref.read(cartProvider.notifier).removeItem(item.id);
    if (removed && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${item.productName} dihapus dari keranjang'), behavior: SnackBarBehavior.floating),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = item.isAvailable;
    return InkWell(
      onTap: available ? () => onSelectedChanged(!selected) : null,
      child: Opacity(
        opacity: busy ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: available ? (value) => onSelectedChanged(value ?? false) : null,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: item.listImageUrl != null
                      ? CachedNetworkImage(memCacheWidth: 240, imageUrl: item.listImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const Icon(Icons.image_outlined, color: AppColors.mutedForeground),
                        )
                      : const Icon(Icons.image_outlined, color: AppColors.mutedForeground),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                        IconButton(
                          onPressed: busy ? null : () => _confirmRemove(context, ref),
                          tooltip: 'Hapus ${item.productName}',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                    if (item.variantName != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          item.variantName!,
                          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (!available)
                      const Text(
                        'Stok habis, tidak bisa dipesan',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.destructive),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatCurrency(item.lineTotal),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                    fontSize: 14.5,
                                  ),
                                ),
                                if (item.quantity > 1)
                                  Text(
                                    '${formatCurrency(item.unitPrice)} / item',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                                  ),
                              ],
                            ),
                          ),
                          _QuantityStepper(item: item, busy: busy),
                        ],
                      ),
                      if (item.stock <= 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            item.quantity >= item.stock
                                ? 'Stok maksimal tercapai (${item.stock})'
                                : 'Sisa ${item.stock}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({required this.item, required this.busy});

  final CartItem item;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            label: 'Kurangi jumlah ${item.productName}',
            onTap: !busy && item.quantity > 1
                ? () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1)
                : null,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            label: 'Tambah jumlah ${item.productName}',
            onTap: !busy && item.quantity < item.stock
                ? () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: onTap == null ? AppColors.border : AppColors.foreground),
        ),
      ),
    );
  }
}
