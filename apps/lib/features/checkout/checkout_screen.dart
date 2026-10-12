import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/cart.dart';
import '../../models/payment_method.dart';
import '../../models/shipping_method.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/address_picker.dart';
import 'checkout_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.group});

  final CartStoreGroup group;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _addressDetailController = TextEditingController();
  final _notesController = TextEditingController();

  AddressSelection _address = const AddressSelection();
  PaymentMethod? _paymentMethod;
  ShippingMethod? _shippingMethod;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _recipientNameController.text = user.name;
      _recipientPhoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _addressDetailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _addressStepDone =>
      _address.isComplete &&
      _recipientNameController.text.trim().isNotEmpty &&
      _recipientPhoneController.text.trim().isNotEmpty &&
      _addressDetailController.text.trim().isNotEmpty;

  double get _total => widget.group.subtotal + (_shippingMethod?.displayFee ?? 0);

  bool get _canSubmit => _paymentMethod != null && _shippingMethod != null && _addressStepDone;

  Future<void> _editAddress() async {
    final result = await showModalBottomSheet<_AddressFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddressFormSheet(
        initialName: _recipientNameController.text,
        initialPhone: _recipientPhoneController.text,
        initialDetail: _addressDetailController.text,
        initialAddress: _address,
      ),
    );
    if (result == null) return;

    final districtChanged = result.address.district?.code != _address.district?.code;
    final villageChanged = result.address.village?.code != _address.village?.code;

    setState(() {
      _recipientNameController.text = result.name;
      _recipientPhoneController.text = result.phone;
      _addressDetailController.text = result.detail;
      _address = result.address;
      if (districtChanged || villageChanged) {
        _shippingMethod = null;
      }
    });
  }

  Future<void> _pickPaymentMethod() async {
    final methods = await ref.read(checkoutStorePaymentMethodsProvider(widget.group.store.slug).future);
    if (!mounted) return;
    final selected = await showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _PaymentMethodPickerSheet(methods: methods, selected: _paymentMethod),
    );
    if (selected != null) setState(() => _paymentMethod = selected);
  }

  Future<void> _pickShippingMethod() async {
    final district = _address.district;
    if (district == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi alamat pengiriman terlebih dahulu.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final methods = await ref.read(checkoutStoreShippingMethodsProvider((
      storeSlug: widget.group.store.slug,
      districtCode: district.code,
      villageCode: _address.village?.code,
    )).future);
    if (!mounted) return;
    final selected = await showModalBottomSheet<ShippingMethod>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ShippingMethodPickerSheet(methods: methods, selected: _shippingMethod),
    );
    if (selected != null) setState(() => _shippingMethod = selected);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final success = await ref.read(checkoutProvider.notifier).submit(
          storeId: widget.group.store.id,
          cartItemIds: widget.group.items.map((item) => item.id).toList(),
          paymentMethodId: _paymentMethod!.id,
          shippingMethodId: _shippingMethod!.id,
          recipientName: _recipientNameController.text.trim(),
          recipientPhone: _recipientPhoneController.text.trim(),
          provinceCode: _address.province!.code,
          cityCode: _address.city!.code,
          districtCode: _address.district!.code,
          villageCode: _address.village!.code,
          addressDetail: _addressDetailController.text.trim(),
          customerNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      final order = ref.read(checkoutProvider).order;
      if (order != null) {
        context.go('/orders/${order.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan berhasil dibuat.'), behavior: SnackBarBehavior.floating),
        );
      }
    } else {
      final error = ref.read(checkoutProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Gagal membuat pesanan.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  String get _fullAddressLine {
    final parts = [
      _address.village?.name,
      _address.district?.name,
      _address.city?.name,
      _address.province?.name,
    ].whereType<String>().toList();
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _StoreItemsCard(group: widget.group),
          const SizedBox(height: 12),
          _StepCard(
            step: 1,
            title: 'Alamat Pengiriman',
            done: _addressStepDone,
            onTap: _editAddress,
            child: _addressStepDone
                ? _AddressSummary(
                    name: _recipientNameController.text.trim(),
                    phone: _recipientPhoneController.text.trim(),
                    regionLine: _fullAddressLine,
                    detail: _addressDetailController.text.trim(),
                  )
                : Text(
                    'Tambahkan nama penerima, nomor telepon, dan alamat lengkap.',
                    style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                  ),
          ),
          const SizedBox(height: 12),
          _StepCard(
            step: 2,
            title: 'Metode Pengiriman',
            done: _shippingMethod != null,
            enabled: _addressStepDone,
            onTap: _pickShippingMethod,
            child: !_addressStepDone
                ? const Text('Lengkapi alamat terlebih dahulu', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground))
                : _shippingMethod != null
                    ? _SelectionRow(
                        icon: Icons.local_shipping_outlined,
                        title: _shippingMethod!.name,
                        subtitle: _shippingMethod!.estimatedDeliveryTime,
                        trailing: formatCurrency(_shippingMethod!.displayFee),
                      )
                    : const _PickPrompt(icon: Icons.local_shipping_outlined, label: 'Pilih metode pengiriman'),
          ),
          const SizedBox(height: 12),
          _StepCard(
            step: 3,
            title: 'Metode Pembayaran',
            done: _paymentMethod != null,
            onTap: _pickPaymentMethod,
            child: _paymentMethod != null
                ? _SelectionRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: _paymentMethod!.name,
                    subtitle: _paymentMethod!.type == 'bank_transfer' ? _paymentMethod!.bankName : _paymentMethod!.description,
                  )
                : const _PickPrompt(icon: Icons.account_balance_wallet_outlined, label: 'Pilih metode pembayaran'),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Catatan untuk Penjual (opsional)',
            child: TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Contoh: titip di satpam, jangan digabung, dll.'),
            ),
          ),
          const SizedBox(height: 12),
          _OrderSummaryCard(
            subtotal: widget.group.subtotal,
            shippingFee: _shippingMethod?.displayFee,
            total: _total,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Bayar', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                    Text(
                      formatCurrency(_total),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _canSubmit && !checkoutState.submitting ? _submit : null,
                  child: checkoutState.submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Buat Pesanan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressFormResult {
  const _AddressFormResult({
    required this.name,
    required this.phone,
    required this.detail,
    required this.address,
  });

  final String name;
  final String phone;
  final String detail;
  final AddressSelection address;
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet({
    required this.initialName,
    required this.initialPhone,
    required this.initialDetail,
    required this.initialAddress,
  });

  final String initialName;
  final String initialPhone;
  final String initialDetail;
  final AddressSelection initialAddress;

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  late final _nameController = TextEditingController(text: widget.initialName);
  late final _phoneController = TextEditingController(text: widget.initialPhone);
  late final _detailController = TextEditingController(text: widget.initialDetail);
  AddressSelection _address = const AddressSelection();

  bool get _valid =>
      _address.isComplete &&
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _detailController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _address = widget.initialAddress;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_valid) return;
    Navigator.of(context).pop(
      _AddressFormResult(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        detail: _detailController.text.trim(),
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Alamat Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nama Penerima'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Nomor Telepon'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    AddressPicker(
                      initial: _address,
                      onChanged: (selection) => setState(() => _address = selection),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _detailController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Detail Alamat (Jalan, RT/RW, dll)'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _valid ? _save : null,
                      child: const Text('Simpan Alamat'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoreItemsCard extends StatelessWidget {
  const _StoreItemsCard({required this.group});

  final CartStoreGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_bag_outlined, size: 18, color: AppColors.foreground),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Daftar Produk',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in group.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.productName}${item.variantName != null ? ' (${item.variantName})' : ''} x${item.quantity}',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(formatCurrency(item.lineTotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.done,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final int step;
  final String title;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : AppColors.surface,
        border: Border.all(color: done ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StepBadge(step: step, done: done),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  if (enabled)
                    Text(
                      done ? 'Ubah' : 'Pilih',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step, required this.done});

  final int step;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.primary : AppColors.surface,
        border: done ? null : Border.all(color: AppColors.border),
      ),
      child: done
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : Text('$step', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.mutedForeground)),
    );
  }
}

class _AddressSummary extends StatelessWidget {
  const _AddressSummary({
    required this.name,
    required this.phone,
    required this.regionLine,
    required this.detail,
  });

  final String name;
  final String phone;
  final String regionLine;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$name · $phone', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          '$detail, $regionLine',
          style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, height: 1.4),
        ),
      ],
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PickPrompt extends StatelessWidget {
  const _PickPrompt({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mutedForeground),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        ),
        const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.subtotal,
    required this.shippingFee,
    required this.total,
  });

  final double subtotal;
  final double? shippingFee;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          _SummaryLine(label: 'Subtotal Produk', value: formatCurrency(subtotal)),
          const SizedBox(height: 6),
          _SummaryLine(
            label: 'Ongkos Kirim',
            value: shippingFee != null ? formatCurrency(shippingFee!) : '—',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _SummaryLine(
            label: 'Total',
            value: formatCurrency(total),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasize ? 15 : 13,
      fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
      color: emphasize ? AppColors.primary : AppColors.foreground,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: emphasize ? style : const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        Text(value, style: style),
      ],
    );
  }
}

class _PaymentMethodPickerSheet extends StatelessWidget {
  const _PaymentMethodPickerSheet({required this.methods, this.selected});

  final List<PaymentMethod> methods;
  final PaymentMethod? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (methods.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Belum ada metode pembayaran.')),
            for (final method in methods)
              _PickerOptionTile(
                icon: Icons.account_balance_wallet_outlined,
                title: method.name,
                subtitle: method.type == 'bank_transfer' && method.bankName != null
                    ? method.bankName
                    : method.description,
                selected: selected?.id == method.id,
                onTap: () => Navigator.of(context).pop(method),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShippingMethodPickerSheet extends StatelessWidget {
  const _ShippingMethodPickerSheet({required this.methods, this.selected});

  final List<ShippingMethod> methods;
  final ShippingMethod? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Metode Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (methods.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Tidak ada metode pengiriman yang tersedia untuk alamat ini.'),
              ),
            for (final method in methods)
              _PickerOptionTile(
                icon: Icons.local_shipping_outlined,
                title: method.name,
                subtitle: method.estimatedDeliveryTime,
                badge: method.isTableRate ? 'Lokal' : null,
                trailing: formatCurrency(method.displayFee),
                selected: selected?.id == method.id,
                onTap: () => Navigator.of(context).pop(method),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickerOptionTile extends StatelessWidget {
  const _PickerOptionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(10),
            color: selected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(badge!, style: const TextStyle(fontSize: 10, color: AppColors.accent)),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(trailing!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(width: 6),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? AppColors.primary : AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
