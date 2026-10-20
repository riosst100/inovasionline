import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/order.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';

/// Splits a processing order into parcels: how many units of each product go in each parcel.
/// Every unit must sit in exactly one parcel and no parcel may be empty. Pops the saved [Order].
class PackingScreen extends ConsumerStatefulWidget {
  const PackingScreen({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends ConsumerState<PackingScreen> {
  static const _maxPackages = 20;

  /// One map per parcel: order item id -> quantity.
  late final List<Map<String, int>> _packs = widget.order.packages.isEmpty
      ? [
          {for (final item in widget.order.items) item.id: item.quantity},
        ]
      : [for (final p in widget.order.packages) Map.of(p.items)];
  bool _saving = false;

  List<OrderItem> get _items => widget.order.items;

  int get _totalUnits => _items.fold(0, (sum, item) => sum + item.quantity);

  int get _maxPacks => min(_maxPackages, _totalUnits);

  int _unpacked(OrderItem item) => item.quantity - _packs.fold(0, (sum, p) => sum + (p[item.id] ?? 0));

  int _units(Map<String, int> pack) => pack.values.fold(0, (sum, qty) => sum + qty);

  /// Puts one unit in parcel [p]: an unpacked one, else one taken from the parcel holding the most.
  void _add(int p, OrderItem item) {
    setState(() {
      if (_unpacked(item) <= 0) {
        final from = [
          for (var i = 0; i < _packs.length; i++)
            if (i != p && (_packs[i][item.id] ?? 0) > 0) i,
        ];
        if (from.isEmpty) return;
        from.sort((a, b) => _packs[b][item.id]!.compareTo(_packs[a][item.id]!));
        _take(from.first, item.id);
      }
      _packs[p][item.id] = (_packs[p][item.id] ?? 0) + 1;
    });
  }

  /// Takes one unit out of parcel [p]; it stays unpacked until placed elsewhere.
  void _remove(int p, OrderItem item) => setState(() => _take(p, item.id));

  void _take(int p, String itemId) {
    final left = (_packs[p][itemId] ?? 0) - 1;
    if (left > 0) {
      _packs[p][itemId] = left;
    } else {
      _packs[p].remove(itemId);
    }
  }

  void _setCount(int count) {
    setState(() {
      while (_packs.length < count) {
        _packs.add({});
      }
      // A dropped parcel's contents go back into parcel 1.
      while (_packs.length > count) {
        for (final MapEntry(:key, :value) in _packs.removeLast().entries) {
          _packs.first[key] = (_packs.first[key] ?? 0) + value;
        }
      }
    });
  }

  /// Why the split cannot be saved yet, or null when it can.
  String? get _problem {
    final unpacked = _items.fold(0, (sum, item) => sum + _unpacked(item));
    if (unpacked > 0) return '$unpacked produk belum masuk paket.';
    final empty = _packs.indexWhere((p) => _units(p) == 0);
    if (empty >= 0) return 'Paket ${empty + 1} masih kosong.';
    return null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final order = await ref.read(orderServiceProvider).updatePackages(widget.order.id, _packs);
      if (!mounted) return;
      showMessage(context, 'Paket disimpan.');
      Navigator.of(context).pop(order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;

    return Scaffold(
      appBar: AppBar(title: const Text('Atur Paket')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Jumlah paket', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  _Stepper(
                    value: _packs.length,
                    onMinus: _packs.length > 1 ? () => _setCount(_packs.length - 1) : null,
                    onPlus: _packs.length < _maxPacks ? () => _setCount(_packs.length + 1) : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tiap paket mendapat QR sendiri. Tekan + di paket tujuan untuk memindahkan produk.',
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final item in _items) ...[_itemCard(item), const SizedBox(height: 10)],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                problem ?? [for (final (i, p) in _packs.indexed) 'Paket ${i + 1}: ${_units(p)}'].join(' · '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: problem == null ? AppColors.mutedForeground : AppColors.destructive,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: problem != null || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan Paket'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemCard(OrderItem item) {
    final unpacked = _unpacked(item);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NetImage(item.imageUrl, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        [if (item.variantName != null) item.variantName!, 'Total ${item.quantity}'].join(' · '),
                        style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (unpacked > 0)
                  Text(
                    'Belum dipaket: $unpacked',
                    style: const TextStyle(color: AppColors.destructive, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var p = 0; p < _packs.length; p++)
                  Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Paket ${p + 1}', style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                        _Stepper(
                          value: _packs[p][item.id] ?? 0,
                          onMinus: (_packs[p][item.id] ?? 0) > 0 ? () => _remove(p, item) : null,
                          onPlus: (_packs[p][item.id] ?? 0) < item.quantity ? () => _add(p, item) : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, this.onMinus, this.onPlus});

  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, size: 18), onPressed: onMinus),
      SizedBox(
        width: 24,
        child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 18), onPressed: onPlus),
    ],
  );
}
