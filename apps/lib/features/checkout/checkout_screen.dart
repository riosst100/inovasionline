import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/formatters.dart';
import '../../models/cart.dart';
import '../../models/delivery_schedule.dart';
import '../../models/payment_method.dart';
import '../../models/shipping_method.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/address_picker.dart';
import '../wallet/topup_screen.dart';
import '../wallet/wallet_providers.dart';
import 'checkout_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.selection});

  final CartSelection selection;

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
  SelectedDeliverySlot? _deliverySlot;

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

  double get _serviceFee {
    final cfg = ref.watch(checkoutServiceFeeConfigProvider).valueOrNull;
    if (cfg == null || cfg['is_active'] != true) return 0;
    final value = (cfg['value'] as num?)?.toDouble() ?? 0;
    if (value <= 0) return 0;
    var fee = cfg['type'] == 'percent' ? widget.selection.subtotal * value / 100 : value;
    final min = (cfg['min_fee'] as num?)?.toDouble();
    final max = (cfg['max_fee'] as num?)?.toDouble();
    if (min != null && fee < min) fee = min;
    if (max != null && fee > max) fee = max;
    return fee.roundToDouble();
  }

  String get _serviceFeeLabel =>
      ref.watch(checkoutServiceFeeConfigProvider).valueOrNull?['label'] as String? ?? 'Biaya Layanan';

  double get _total => widget.selection.subtotal + (_shippingMethod?.displayFee ?? 0) + _serviceFee;

  bool get _scheduleMissing => _shippingMethod?.requiresSchedule == true && _deliverySlot == null;

  bool get _canSubmit => _paymentMethod != null && _shippingMethod != null && !_scheduleMissing && _addressStepDone;

  Future<void> _editAddress() async {
    final result = await showModalBottomSheet<_AddressFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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
        _deliverySlot = null;
      }
    });
  }

  Future<void> _pickPaymentMethod() async {
    final methods = await ref.read(checkoutPaymentMethodsProvider.future);
    // Fresh balance: it may have changed (top-up, refund) since the screen opened.
    ref.invalidate(walletProvider);
    final walletBalance = await ref.read(walletProvider.future).then((w) => w?.balance, onError: (_) => null);
    if (!mounted) return;
    final selected = await showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentMethodPickerSheet(
        methods: methods,
        selected: _paymentMethod,
        total: _total,
        walletBalance: walletBalance,
      ),
    );
    if (selected != null) setState(() => _paymentMethod = selected);
  }

  Future<void> _pickShippingMethod() async {
    final district = _address.district;
    if (district == null) {
      _showSnack('Silakan lengkapi alamat pengiriman terlebih dahulu.');
      return;
    }

    final methods = await ref.read(checkoutShippingMethodsProvider((
      districtCode: district.code,
      villageCode: _address.village?.code,
    )).future);
    if (!mounted) return;
    final selected = await showModalBottomSheet<ShippingMethod>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShippingMethodPickerSheet(methods: methods, selected: _shippingMethod),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (selected.id != _shippingMethod?.id) _deliverySlot = null;
      _shippingMethod = selected;
    });
    if (selected.requiresSchedule && _deliverySlot == null) await _pickDeliverySlot();
  }

  Future<void> _pickDeliverySlot() async {
    final method = _shippingMethod;
    if (method == null) return;
    // Always refetch: windows close and fill up while the buyer is on this screen.
    ref.invalidate(checkoutDeliverySchedulesProvider(method.id));
    final List<DeliveryDay> days;
    try {
      days = await ref.read(checkoutDeliverySchedulesProvider(method.id).future);
    } catch (_) {
      if (mounted) _showSnack('Gagal memuat jadwal pengiriman.');
      return;
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<SelectedDeliverySlot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeliverySlotPickerSheet(days: days, selected: _deliverySlot),
    );
    if (selected != null) setState(() => _deliverySlot = selected);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _handleDisabledSubmitTap() {
    if (!_addressStepDone) {
      _showSnack('Lengkapi alamat pengiriman terlebih dahulu.');
      _editAddress();
    } else if (_shippingMethod == null) {
      _showSnack('Silakan pilih metode pengiriman terlebih dahulu.');
      _pickShippingMethod();
    } else if (_scheduleMissing) {
      _showSnack('Silakan pilih jadwal pengiriman terlebih dahulu.');
      _pickDeliverySlot();
    } else if (_paymentMethod == null) {
      _showSnack('Silakan pilih metode pembayaran terlebih dahulu.');
      _pickPaymentMethod();
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      _handleDisabledSubmitTap();
      return;
    }

    final success = await ref.read(checkoutProvider.notifier).submit(
          cartItemIds: widget.selection.items.map((item) => item.id).toList(),
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
          deliveryScheduleId: _shippingMethod!.requiresSchedule ? _deliverySlot?.slot.scheduleId : null,
          deliveryDate: _shippingMethod!.requiresSchedule ? _deliverySlot?.slot.date : null,
        );

    if (!mounted) return;

    if (success) {
      final order = ref.read(checkoutProvider).order;
      if (order != null) {
        context.go('/orders/${order.id}');
        _showSnack('Pesanan berhasil dibuat!');
        if (order.needsOnlinePayment && order.paymentRedirectUrl != null) {
          context.push('/orders/${order.id}/pay', extra: order.paymentRedirectUrl);
        }
      }
    } else {
      final error = ref.read(checkoutProvider).error;
      _showSnack(error ?? 'Gagal membuat pesanan.');
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Checkout Pesanan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 1),
            Text(
              'Periksa rincian & selesaikan pembayaran',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF16A34A)),
                SizedBox(width: 4),
                Text(
                  '100% Aman',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1. Purchased Products Card
          _ItemsCard(selection: widget.selection),
          const SizedBox(height: 14),

          // 2. Shipping Address Card
          _StepCard(
            step: 1,
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFF0D9488),
            title: 'Alamat Pengiriman',
            done: _addressStepDone,
            actionLabel: _addressStepDone ? 'Ubah Alamat' : 'Pilih Alamat',
            onTap: _editAddress,
            child: _addressStepDone
                ? _AddressSummary(
                    name: _recipientNameController.text.trim(),
                    phone: _recipientPhoneController.text.trim(),
                    regionLine: _fullAddressLine,
                    detail: _addressDetailController.text.trim(),
                  )
                : _EmptyStepPrompt(
                    icon: Icons.add_location_alt_outlined,
                    title: 'Tentukan Alamat Pengiriman',
                    subtitle: 'Klik untuk mengisi nama penerima dan detail lokasi antar kurir.',
                    onTap: _editAddress,
                  ),
          ),
          const SizedBox(height: 14),

          // 3. Shipping Method Card
          _StepCard(
            step: 2,
            icon: Icons.local_shipping_rounded,
            iconColor: const Color(0xFF2563EB),
            title: 'Metode Pengiriman',
            done: _shippingMethod != null && !_scheduleMissing,
            enabled: _addressStepDone,
            actionLabel: _shippingMethod != null ? 'Ganti' : 'Pilih',
            onTap: _pickShippingMethod,
            child: !_addressStepDone
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lengkapi alamat terlebih dahulu untuk memilih kurir & ongkir.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  )
                : _shippingMethod != null
                    ? _SelectedShippingTile(
                        method: _shippingMethod!,
                        deliverySlot: _deliverySlot,
                        onPickSlot: _pickDeliverySlot,
                      )
                    : _EmptyStepPrompt(
                        icon: Icons.delivery_dining_outlined,
                        title: 'Pilih Metode Kurir & Pengiriman',
                        subtitle: 'Pilih pengiriman instan atau pengiriman terjadwal.',
                        onTap: _pickShippingMethod,
                      ),
          ),
          const SizedBox(height: 14),

          // 4. Payment Method Card
          _StepCard(
            step: 3,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: 'Metode Pembayaran',
            done: _paymentMethod != null,
            actionLabel: _paymentMethod != null ? 'Ganti' : 'Pilih',
            onTap: _pickPaymentMethod,
            child: _paymentMethod != null
                ? _SelectedPaymentTile(method: _paymentMethod!)
                : _EmptyStepPrompt(
                    icon: Icons.payment_outlined,
                    title: 'Pilih Metode Pembayaran',
                    subtitle: 'Mendukung Transfer Bank, QRIS, & COD (Bayar di Tempat).',
                    onTap: _pickPaymentMethod,
                  ),
          ),
          const SizedBox(height: 14),

          // 5. Notes
          _CustomerNotesCard(
            controller: _notesController,
            onPresetSelected: (text) {
              final current = _notesController.text.trim();
              if (current.isEmpty) {
                _notesController.text = text;
              } else if (!current.contains(text)) {
                _notesController.text = '$current, $text';
              }
            },
          ),
          const SizedBox(height: 14),

          // 6. Payment Breakdown / Summary
          _OrderSummaryCard(
            subtotal: widget.selection.subtotal,
            shippingFee: _shippingMethod?.displayFee,
            serviceFee: _serviceFee,
            serviceFeeLabel: _serviceFeeLabel,
            total: _total,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatCurrency(_total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D9488),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _canSubmit ? null : _handleDisabledSubmitTap,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _canSubmit && !checkoutState.submitting ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withValues(alpha: 0.9),
                        elevation: _canSubmit ? 2 : 0,
                        shadowColor: const Color(0xFF0D9488).withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: checkoutState.submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Buat Pesanan',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PRODUCT LIST CARD
// ==========================================
class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.selection});

  final CartSelection selection;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.shopping_bag_outlined, size: 18, color: Color(0xFF0D9488)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Produk Dipesan',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${selection.items.length} Barang dipesan',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                for (int i = 0; i < selection.items.length; i++) ...[
                  _CheckoutItemRow(item: selection.items[i]),
                  if (i < selection.items.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ),
                ],
              ],
            ),
          ),

          // Card Subtotal Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${selection.items.length} Produk)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                Text(
                  formatCurrency(selection.subtotal),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Product Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 48,
            height: 48,
            color: const Color(0xFFF1F5F9),
            child: item.productImageUrl != null && item.productImageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.productImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)),
                      ),
                    ),
                    errorWidget: (_, _, _) => const Icon(Icons.image_outlined, color: Color(0xFF94A3B8), size: 24),
                  )
                : const Icon(Icons.shopping_basket_outlined, color: Color(0xFF94A3B8), size: 24),
          ),
        ),
        const SizedBox(width: 12),

        // Product Title & Variant
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (item.variantName != null && item.variantName!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.variantName!,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  Text(
                    '${item.quantity} x ${formatCurrency(item.unitPrice)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Line Total
        Text(
          formatCurrency(item.lineTotal),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }
}

// ==========================================
// UNIFIED STEP CARD
// ==========================================
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.done,
    required this.actionLabel,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final int step;
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool done;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done ? iconColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
          width: done ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: done ? iconColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(icon, size: 18, color: done ? iconColor : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      if (done) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
                if (enabled)
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: done ? iconColor : const Color(0xFF0D9488),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: done ? iconColor : const Color(0xFF0D9488),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Step Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

// Empty state inside a step card
class _EmptyStepPrompt extends StatelessWidget {
  const _EmptyStepPrompt({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF0D9488)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

// Completed Address summary view
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Penerima',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const Text(' · ', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
            Text(
              phone,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), height: 1.35),
        ),
        const SizedBox(height: 3),
        Text(
          regionLine,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
        ),
      ],
    );
  }
}

// Selected Shipping Method view
class _SelectedShippingTile extends StatelessWidget {
  const _SelectedShippingTile({required this.method, this.deliverySlot, this.onPickSlot});

  final ShippingMethod method;
  final SelectedDeliverySlot? deliverySlot;
  final VoidCallback? onPickSlot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        children: [
          _buildMethodRow(),
          if (method.requiresSchedule) ...[
            const SizedBox(height: 10),
            _buildScheduleRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleRow() {
    final slot = deliverySlot;
    return InkWell(
      onTap: onPickSlot,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: slot == null ? const Color(0xFFFCA5A5) : const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 16,
              color: slot == null ? const Color(0xFFDC2626) : const Color(0xFF15803D),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                slot?.summary ?? 'Pilih jadwal pengiriman',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: slot == null ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                ),
              ),
            ),
            Text(
              slot == null ? 'Pilih' : 'Ubah',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0D9488)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodRow() {
    return Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              method.requiresSchedule ? Icons.event_available_rounded : Icons.bolt_rounded,
              size: 20,
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        method.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        method.requiresSchedule ? 'Terjadwal' : 'Cepat',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (method.estimatedDeliveryTime != null && method.estimatedDeliveryTime!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF15803D)),
                      const SizedBox(width: 4),
                      Text(
                        method.estimatedDeliveryTime!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Text(
            method.displayFee == 0 ? 'GRATIS' : formatCurrency(method.displayFee),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
          ),
        ],
      );
  }
}

// Selected Payment Method view
class _SelectedPaymentTile extends StatelessWidget {
  const _SelectedPaymentTile({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    IconData iconData = Icons.account_balance_wallet_rounded;
    Color iconColor = const Color(0xFF7C3AED);
    Color bgIcon = const Color(0xFFEDE9FE);

    if (method.type == 'cod') {
      iconData = Icons.payments_rounded;
      iconColor = const Color(0xFFEA580C);
      bgIcon = const Color(0xFFFFEDD5);
    } else if (method.type == 'payment_gateway') {
      iconData = _PaymentMethodPickerSheet._iconFor(method);
    } else if (method.type == 'bank_transfer') {
      iconData = Icons.account_balance_rounded;
      iconColor = const Color(0xFF2563EB);
      bgIcon = const Color(0xFFDBEAFE);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgIcon,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  method.type == 'bank_transfer' && method.bankName != null
                      ? 'Bank: ${method.bankName}'
                      : (method.description ?? 'Metode pembayaran terverifikasi'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Terpilih',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CUSTOMER NOTES CARD WITH QUICK CHIPS
// ==========================================
class _CustomerNotesCard extends StatelessWidget {
  const _CustomerNotesCard({
    required this.controller,
    required this.onPresetSelected,
  });

  final TextEditingController controller;
  final ValueChanged<String> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF0D9488)),
              SizedBox(width: 8),
              Text(
                'Catatan untuk Kurir (opsional)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Contoh: Titip di satpam, pagar warna hitam, dll...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Preset Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              'Titip di satpam',
              'Hubungi sebelum sampai',
              'Taruh depan pintu',
              'Jangan tekan bel',
            ].map((text) {
              return InkWell(
                onTap: () => onPresetSelected(text),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '+ $text',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ORDER SUMMARY RECEIPT CARD
// ==========================================
class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.subtotal,
    required this.shippingFee,
    required this.serviceFee,
    required this.serviceFeeLabel,
    required this.total,
  });

  final double subtotal;
  final double? shippingFee;
  final double serviceFee;
  final String serviceFeeLabel;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF0D9488)),
              SizedBox(width: 8),
              Text(
                'Rincian Pembayaran',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryLine(label: 'Total Harga Produk', value: formatCurrency(subtotal)),
          const SizedBox(height: 8),
          _SummaryLine(
            label: 'Biaya Pengiriman',
            value: shippingFee != null ? (shippingFee == 0 ? 'GRATIS' : formatCurrency(shippingFee!)) : 'Pilih kurir',
            valueColor: shippingFee != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 8),
          _SummaryLine(
            label: serviceFeeLabel,
            value: serviceFee > 0 ? formatCurrency(serviceFee) : 'GRATIS',
            valueColor: serviceFee > 0 ? const Color(0xFF0F172A) : const Color(0xFF16A34A),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Tagihan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Text(
                formatCurrency(total),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0D9488)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF0F172A),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}

// ==========================================
// MODAL BOTTOM SHEETS
// ==========================================
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Alamat Pengiriman',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Penerima',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Telepon Penerima',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    AddressPicker(
                      initial: _address,
                      onChanged: (selection) => setState(() => _address = selection),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _detailController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Detail Alamat (Nama Jalan, No. Rumah, RT/RW, Patokan)',
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _valid ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Simpan Alamat Pengiriman', style: TextStyle(fontWeight: FontWeight.bold)),
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

// ==========================================
// PAYMENT METHOD PICKER SHEET
// ==========================================
class _PaymentMethodPickerSheet extends StatelessWidget {
  const _PaymentMethodPickerSheet({
    required this.methods,
    required this.total,
    this.selected,
    this.walletBalance,
  });

  final List<PaymentMethod> methods;
  final PaymentMethod? selected;

  /// Order total the balance has to cover; null balance = not loaded yet.
  final double total;
  final double? walletBalance;

  /// The balance option: selectable only when it covers [total]; otherwise it leads to top-up.
  Widget _walletTile(BuildContext context, PaymentMethod method) {
    final balance = walletBalance;
    final enough = balance != null && balance >= total;

    return _PickerOptionTile(
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF0D9488),
      title: method.name,
      subtitle: balance == null
          ? 'Memuat saldo…'
          : enough
              ? 'Saldo ${formatCurrency(balance)}'
              : 'Saldo ${formatCurrency(balance)} · kurang ${formatCurrency(total - balance)}, ketuk untuk top up',
      badge: enough ? 'Instan' : 'Top Up',
      selected: selected?.id == method.id,
      onTap: () {
        if (enough) {
          Navigator.of(context).pop(method);
        } else if (balance != null) {
          Navigator.of(context).pop();
          context.push('/wallet/topup', extra: topupFromCheckout);
        }
      },
    );
  }

  /// Methods by [PaymentMethod.group], in the order groups first appear (methods come sorted).
  Map<String, List<PaymentMethod>> get _groups {
    final groups = <String, List<PaymentMethod>>{};
    for (final method in methods) {
      groups.putIfAbsent(method.group, () => []).add(method);
    }
    return groups;
  }

  static IconData _iconFor(PaymentMethod method) {
    if (method.type == 'cod') return Icons.payments_rounded;
    if (method.type == 'bank_transfer') return Icons.account_balance_rounded;
    return switch (method.group) {
      'E-Wallet & QRIS' => method.gatewayChannel == 'other_qris' ? Icons.qr_code_2_rounded : Icons.account_balance_wallet_rounded,
      'Virtual Account' => Icons.account_balance_rounded,
      'Kartu' => Icons.credit_card_rounded,
      _ => Icons.account_balance_wallet_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih Metode Pembayaran',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (methods.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Belum ada metode pembayaran yang tersedia.'),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final group in _groups.entries) ...[
                      if (_groups.length > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                          child: Text(
                            group.key,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                          ),
                        ),
                      for (final method in group.value)
                        if (method.isWallet)
                          _walletTile(context, method)
                        else
                          _PickerOptionTile(
                            icon: _iconFor(method),
                            iconColor: method.type == 'cod'
                                ? const Color(0xFFEA580C)
                                : method.type == 'bank_transfer'
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF7C3AED),
                            title: method.name,
                            subtitle: method.type == 'bank_transfer' && method.bankName != null
                                ? method.bankName
                                : method.description,
                            badge: method.type == 'cod'
                                ? 'COD'
                                : (method.type == 'bank_transfer' ? 'Transfer' : null),
                            selected: selected?.id == method.id,
                            onTap: () => Navigator.of(context).pop(method),
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

// ==========================================
// SHIPPING METHOD PICKER SHEET
// ==========================================
class _ShippingMethodPickerSheet extends StatelessWidget {
  const _ShippingMethodPickerSheet({required this.methods, this.selected});

  final List<ShippingMethod> methods;
  final ShippingMethod? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih Opsi Pengiriman',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (methods.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Tidak ada metode pengiriman yang menjangkau alamat ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              for (final method in methods)
                _PickerOptionTile(
                  icon: method.requiresSchedule ? Icons.event_available_rounded : Icons.bolt_rounded,
                  iconColor: method.requiresSchedule ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                  title: method.name,
                  subtitle: method.estimatedDeliveryTime,
                  badge: method.requiresSchedule
                      ? 'Terjadwal'
                      : (method.type == 'io_express' || method.isTableRate ? 'Instan' : 'Reguler'),
                  trailing: method.displayFee == 0 ? 'GRATIS' : formatCurrency(method.displayFee),
                  selected: selected?.id == method.id,
                  onTap: () => Navigator.of(context).pop(method),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// DELIVERY SLOT PICKER SHEET (IO Same Day)
// ==========================================
class _DeliverySlotPickerSheet extends StatefulWidget {
  const _DeliverySlotPickerSheet({required this.days, this.selected});

  final List<DeliveryDay> days;
  final SelectedDeliverySlot? selected;

  @override
  State<_DeliverySlotPickerSheet> createState() => _DeliverySlotPickerSheetState();
}

class _DeliverySlotPickerSheetState extends State<_DeliverySlotPickerSheet> {
  late int _dayIndex;

  @override
  void initState() {
    super.initState();
    final selectedIndex = widget.days.indexWhere((d) => d.date == widget.selected?.slot.date);
    final firstOpen = widget.days.indexWhere((d) => d.hasAvailable);
    _dayIndex = selectedIndex >= 0 ? selectedIndex : (firstOpen >= 0 ? firstOpen : 0);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.days.isEmpty ? null : widget.days[_dayIndex];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih Jadwal Pengiriman',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              if (day == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Belum ada jadwal pengiriman yang tersedia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.days.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final d = widget.days[i];
                      final active = i == _dayIndex;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _dayIndex = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFFF0FDF4) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
                              width: active ? 1.6 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                d.dayLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: d.hasAvailable ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                d.holiday != null ? 'Libur' : d.dateLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: d.holiday != null ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (day.holiday != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Libur: ${day.holiday} — tidak ada pengiriman di hari ini.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                    ),
                  ),
                if (day.slots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Tidak ada jadwal pengiriman di hari ini.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                for (final slot in day.slots)
                  Opacity(
                    opacity: slot.available ? 1 : 0.5,
                    child: _PickerOptionTile(
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFF2563EB),
                      title: slot.label,
                      subtitle: slot.available
                          ? (slot.remaining != null ? '${slot.timeRange} · sisa ${slot.remaining} slot' : slot.timeRange)
                          : '${slot.timeRange} · ${slot.reason ?? 'tidak tersedia'}',
                      selected: slot.isSameAs(widget.selected?.slot),
                      onTap: slot.available
                          ? () => Navigator.of(context).pop(SelectedDeliverySlot(slot: slot, day: day))
                          : () {},
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Option Tile for Pickers
class _PickerOptionTile extends StatelessWidget {
  const _PickerOptionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.iconColor = const Color(0xFF0D9488),
    this.subtitle,
    this.trailing,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? trailing;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
            color: selected ? const Color(0xFFF0FDF4) : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: trailing == 'GRATIS' ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
