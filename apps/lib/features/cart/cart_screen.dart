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
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cartProvider.notifier).load());
  }

  void _toggleItem(String itemId, bool selected) {
    setState(() {
      if (selected) {
        _selectedItemIds.add(itemId);
      } else {
        _selectedItemIds.remove(itemId);
      }
    });
  }

  void _toggleGroup(CartStoreGroup group, bool selected) {
    setState(() {
      final ids = group.items.map((item) => item.id);
      if (selected) {
        _selectedItemIds.addAll(ids);
      } else {
        _selectedItemIds.removeAll(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cart = cartState.cart;
    final itemCount = cart?.itemCount ?? 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(itemCount > 0 ? 'Keranjang ($itemCount)' : 'Keranjang'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(cartProvider.notifier).load(),
        child: cartState.loading && cart == null
            ? const Center(child: CircularProgressIndicator())
            : cart == null || cart.isEmpty
                ? const _EmptyCart()
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + MediaQuery.paddingOf(context).bottom),
                    itemCount: cart.stores.length,
                    itemBuilder: (context, index) => _StoreGroupCard(
                      group: cart.stores[index],
                      selectedItemIds: _selectedItemIds,
                      onToggleItem: _toggleItem,
                      onToggleGroup: _toggleGroup,
                    ),
                  ),
      ),
      bottomNavigationBar: cart == null || cart.isEmpty
          ? null
          : _CheckoutBar(
              groups: [
                for (final g in cart.stores)
                  if (g.items.any((i) => _selectedItemIds.contains(i.id)))
                    CartStoreGroup(
                      store: g.store,
                      items: g.items.where((i) => _selectedItemIds.contains(i.id)).toList(),
                      subtotal: g.items
                          .where((i) => _selectedItemIds.contains(i.id))
                          .fold<double>(0, (sum, i) => sum + i.lineTotal),
                    ),
              ],
            ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.groups});

  /// Selected items, grouped by store.
  final List<CartStoreGroup> groups;

  @override
  Widget build(BuildContext context) {
    final total = groups.fold<double>(0, (sum, g) => sum + g.subtotal);
    final count = groups.fold<int>(0, (sum, g) => sum + g.items.length);
    final canCheckout = groups.length == 1;

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
                  count > 0 ? 'Subtotal ($count produk)' : 'Subtotal',
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
            onPressed: canCheckout ? () => context.push('/checkout', extra: groups.first) : null,
            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
            label: const Text('Checkout'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              minimumSize: Size.zero,
              disabledBackgroundColor: AppColors.surface,
              disabledForegroundColor: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
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
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
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

class _StoreGroupCard extends ConsumerWidget {
  const _StoreGroupCard({
    required this.group,
    required this.selectedItemIds,
    required this.onToggleItem,
    required this.onToggleGroup,
  });

  final CartStoreGroup group;
  final Set<String> selectedItemIds;
  final void Function(String itemId, bool selected) onToggleItem;
  final void Function(CartStoreGroup group, bool selected) onToggleGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedItems = group.items.where((item) => selectedItemIds.contains(item.id)).toList();
    final allSelected = selectedItems.length == group.items.length;
    final someSelected = selectedItems.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => onToggleGroup(group, !allSelected),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected ? true : (someSelected ? null : false),
                    tristate: true,
                    visualDensity: VisualDensity.compact,
                    onChanged: (value) => onToggleGroup(group, !allSelected),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Pilih Semua (${group.items.length})',
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
          for (var i = 0; i < group.items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _CartItemTile(
              item: group.items[i],
              selected: selectedItemIds.contains(group.items[i].id),
              onSelectedChanged: (selected) => onToggleItem(group.items[i].id, selected),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item, required this.selected, required this.onSelectedChanged});

  final CartItem item;
  final bool selected;
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
    if (ok == true) {
      ref.read(cartProvider.notifier).removeItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => onSelectedChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              visualDensity: VisualDensity.compact,
              onChanged: (value) => onSelectedChanged(value ?? false),
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
                child: item.productImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.productImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.image_outlined, color: AppColors.mutedForeground),
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
                      InkWell(
                        onTap: () => _confirmRemove(context, ref),
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline, size: 20, color: AppColors.mutedForeground),
                        ),
                      ),
                    ],
                  ),
                  if (item.variantName != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.variantName!,
                        style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatCurrency(item.unitPrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
                        ),
                      ),
                      _QuantityStepper(item: item),
                    ],
                  ),
                  if (item.stock > 0 && item.stock <= 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Sisa ${item.stock}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: item.quantity > 1
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
            onTap: item.quantity < item.stock
                ? () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: onTap == null ? AppColors.border : AppColors.foreground),
      ),
    );
  }
}
