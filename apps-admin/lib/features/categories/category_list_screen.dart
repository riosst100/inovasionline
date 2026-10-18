import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../models/category.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref, List<Category> all, [Category? category]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryForm(
        category: category,
        parents: all.where((c) => c.parentId == null && c.id != category?.id).toList(),
      ),
    );
    if (saved == true) ref.invalidate(categoriesProvider);
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Category category) async {
    try {
      await ref.read(catalogServiceProvider).toggleCategory(category.id);
      ref.invalidate(categoriesProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Category category) async {
    final ok = await confirm(
      context,
      title: 'Hapus kategori',
      message: 'Hapus kategori "${category.name}"?',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(catalogServiceProvider).deleteCategory(category.id);
      ref.invalidate(categoriesProvider);
      if (context.mounted) showMessage(context, 'Kategori dihapus.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref, categories.valueOrNull ?? []),
        icon: const Icon(Icons.add),
        label: const Text('Kategori'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(categoriesProvider.future),
        child: categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorView(message: errorMessage(e), onRetry: () => ref.invalidate(categoriesProvider)),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyView(icon: Icons.category_outlined, text: 'Belum ada kategori.'),
                ],
              );
            }
            final parents = items.where((c) => c.parentId == null).toList();
            final orphans = items.where((c) => c.parentId != null && !parents.any((p) => p.id == c.parentId));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final parent in [...parents, ...orphans]) ...[
                  _CategoryTile(
                    category: parent,
                    onTap: () => _openForm(context, ref, items, parent),
                    onToggle: () => _toggle(context, ref, parent),
                    onDelete: () => _delete(context, ref, parent),
                  ),
                  for (final child in items.where((c) => c.parentId == parent.id))
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: _CategoryTile(
                        category: child,
                        onTap: () => _openForm(context, ref, items, child),
                        onToggle: () => _toggle(context, ref, child),
                        onDelete: () => _delete(context, ref, child),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap, required this.onToggle, required this.onDelete});

  final Category category;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: NetImage(category.imageUrl, size: 44),
        title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          category.isActive ? 'Aktif' : 'Nonaktif',
          style: TextStyle(color: category.isActive ? AppColors.success : AppColors.mutedForeground, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: category.isActive, onChanged: (_) => onToggle()),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.category, required this.parents});

  final Category? category;
  final List<Category> parents;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late final _name = TextEditingController(text: widget.category?.name);
  late final _description = TextEditingController(text: widget.category?.description);
  late String? _parentId = widget.category?.parentId;
  late bool _isActive = widget.category?.isActive ?? true;
  String? _imagePath;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
    if (file != null) setState(() => _imagePath = file.path);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Nama wajib diisi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(catalogServiceProvider)
          .saveCategory(
            id: widget.category?.id,
            name: _name.text.trim(),
            description: _description.text.trim(),
            parentId: _parentId,
            isActive: _isActive,
            imagePath: _imagePath,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingImage = widget.category?.imageUrl;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.category == null ? 'Kategori Baru' : 'Edit Kategori',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _imagePath != null
                        ? Image.file(File(_imagePath!), width: 64, height: 64, fit: BoxFit.cover)
                        : existingImage != null
                        ? NetImage(existingImage, size: 64, radius: 10)
                        : Container(
                            width: 64,
                            height: 64,
                            color: AppColors.surface,
                            child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nama kategori *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: widget.parents.any((p) => p.id == _parentId) ? _parentId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Induk kategori'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Kategori utama —')),
                for (final p in widget.parents) DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _parentId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.destructive)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
