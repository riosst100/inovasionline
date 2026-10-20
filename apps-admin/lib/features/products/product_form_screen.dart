import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/core_providers.dart';
import '../../services/catalog_service.dart';
import '../../widgets/common.dart';

/// Create ([productId] null) or edit a product. Pops `true` when anything was saved.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _regularPrice = TextEditingController();
  final _salePrice = TextEditingController();
  final _shortDescription = TextEditingController();
  final _description = TextEditingController();
  final _stockControllers = <String, TextEditingController>{};

  Product? _product;
  String? _categoryId;
  ProductStatus _status = ProductStatus.active;
  bool _loading = false;
  bool _saving = false;
  bool _uploading = false;
  bool _dirty = false;
  Object? _loadError;
  ApiException? _validation;

  bool get _isNew => widget.productId == null && _product == null;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _regularPrice,
      _salePrice,
      _shortDescription,
      _description,
      ..._stockControllers.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final product = await ref.read(catalogServiceProvider).product(widget.productId!);
      if (!mounted) return;
      _fill(product);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(Product product) {
    setState(() {
      _product = product;
      _name.text = product.name;
      _sku.text = product.sku ?? '';
      _regularPrice.text = product.regularPrice.toStringAsFixed(0);
      _salePrice.text = product.salePrice?.toStringAsFixed(0) ?? '';
      _shortDescription.text = product.shortDescription ?? '';
      _description.text = product.description ?? '';
      _categoryId = product.categoryId;
      _status = product.status;
      for (final e in product.stocks.entries) {
        _stockFor(e.key).text = e.value.toString();
      }
    });
  }

  TextEditingController _stockFor(String warehouseId) =>
      _stockControllers.putIfAbsent(warehouseId, () => TextEditingController(text: '0'));

  Future<void> _save() async {
    setState(() => _validation = null);
    if (!_formKey.currentState!.validate()) return;

    final warehouses = ref.read(warehousesProvider).valueOrNull;
    final sale = _salePrice.text.trim();
    final input = ProductInput(
      name: _name.text.trim(),
      sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      regularPrice: double.parse(_regularPrice.text),
      salePrice: sale.isEmpty ? null : double.parse(sale),
      categoryId: _categoryId,
      status: _status,
      shortDescription: _shortDescription.text.trim(),
      description: _description.text.trim(),
      // Without the warehouse list the stock fields aren't shown, so leave stock as is.
      stocks: warehouses == null ? null : {for (final w in warehouses) w.id: int.tryParse(_stockFor(w.id).text) ?? 0},
    );

    setState(() => _saving = true);
    try {
      final service = ref.read(catalogServiceProvider);
      final saved = _isNew ? await service.createProduct(input) : await service.updateProduct(_product!.id, input);
      if (!mounted) return;
      _dirty = true;
      if (_isNew) {
        // Stay on the form so images can be added right away.
        _fill(saved);
        showMessage(context, 'Produk dibuat. Tambahkan foto produk.');
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      // Field errors are shown under the matching inputs.
      setState(() => _validation = e is DioException && e.error is ApiException ? e.error as ApiException : null);
      showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImages() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 1600, limit: 10);
    if (files.isEmpty || _product == null) return;
    setState(() => _uploading = true);
    try {
      final updated = await ref
          .read(catalogServiceProvider)
          .uploadProductImages(_product!.id, files.map((f) => f.path).toList());
      if (!mounted) return;
      _dirty = true;
      setState(() => _product = updated);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _imageAction(ProductImage image) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!image.isPrimary)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Jadikan foto utama'),
                onTap: () => Navigator.pop(context, 'primary'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.destructive),
              title: const Text('Hapus foto', style: TextStyle(color: AppColors.destructive)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final service = ref.read(catalogServiceProvider);
      final updated = action == 'primary'
          ? await service.setPrimaryImage(_product!.id, image.id)
          : await service.deleteImage(_product!.id, image.id);
      if (!mounted) return;
      _dirty = true;
      setState(() => _product = updated);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Hapus produk',
      message: 'Hapus "${_product!.name}"? Produk tidak akan tampil lagi di aplikasi.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(catalogServiceProvider).deleteProduct(_product!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String? _serverError(String field) => _validation?.firstErrorFor(field);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_dirty);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Produk Baru' : 'Edit Produk'),
          actions: [
            if (_product != null)
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
                onPressed: _delete,
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: ErrorView(message: errorMessage(_loadError!), onRetry: _load),
              )
            : _form(),
        bottomNavigationBar: _loading || _loadError != null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isNew ? 'Simpan Produk' : 'Simpan Perubahan'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _form() {
    final categories = ref.watch(categoriesProvider);
    final warehouses = ref.watch(warehousesProvider);
    final digitsOnly = [FilteringTextInputFormatter.digitsOnly];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _images(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Nama produk *', errorText: _serverError('name')),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi.' : null,
          ),
          const SizedBox(height: 12),
          categories.when(
            data: (items) => DropdownButtonFormField<String?>(
              initialValue: items.any((c) => c.id == _categoryId) ? _categoryId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tanpa kategori')),
                for (final c in _sortedCategories(items))
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.parentId == null ? c.name : '   ${c.name}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Gagal memuat kategori: ${errorMessage(e)}'),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _regularPrice,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  decoration: InputDecoration(
                    labelText: 'Harga normal *',
                    prefixText: 'Rp ',
                    errorText: _serverError('regular_price'),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi.' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _salePrice,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  decoration: InputDecoration(
                    labelText: 'Harga promo',
                    prefixText: 'Rp ',
                    errorText: _serverError('sale_price'),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final regular = double.tryParse(_regularPrice.text) ?? 0;
                    return double.parse(v) > regular ? 'Melebihi harga normal.' : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _sku,
                  decoration: InputDecoration(labelText: 'SKU', errorText: _serverError('sku')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ProductStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [for (final s in ProductStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _shortDescription,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Deskripsi singkat'),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _description,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Deskripsi', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          const Text('Stok per gudang', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          warehouses.when(
            data: (items) => items.isEmpty
                ? const Text(
                    'Belum ada gudang. Tambahkan gudang dari admin web.',
                    style: TextStyle(color: AppColors.mutedForeground),
                  )
                : Column(
                    children: [
                      for (final w in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(w.code == null ? w.name : '${w.name} (${w.code})')),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  controller: _stockFor(w.id),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: digitsOnly,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(isDense: true, suffixText: ' pcs'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Gagal memuat gudang: ${errorMessage(e)}'),
          ),
        ],
      ),
    );
  }

  /// Parents first, each followed by its children.
  List<Category> _sortedCategories(List<Category> items) {
    final parents = items.where((c) => c.parentId == null);
    return [
      for (final p in parents) ...[p, ...items.where((c) => c.parentId == p.id)],
      // Children whose parent isn't in the list.
      ...items.where((c) => c.parentId != null && !items.any((p) => p.id == c.parentId)),
    ];
  }

  Widget _images() {
    final product = _product;
    if (product == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.mutedForeground),
            SizedBox(width: 10),
            Expanded(child: Text('Simpan produk terlebih dahulu untuk menambahkan foto.')),
          ],
        ),
      );
    }

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final image in product.images)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _uploading ? null : () => _imageAction(image),
                child: Stack(
                  children: [
                    NetImage(image.url, size: 96, radius: 10),
                    if (image.isPrimary)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: StatusBadge(label: 'Utama', color: AppColors.primary),
                      ),
                  ],
                ),
              ),
            ),
          InkWell(
            onTap: _uploading ? null : _pickImages,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 96,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _uploading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                        SizedBox(height: 4),
                        Text('Tambah foto', style: TextStyle(fontSize: 11)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
