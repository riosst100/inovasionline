import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/delivery_schedule.dart';
import '../../providers/core_providers.dart';
import '../../services/delivery_schedule_service.dart';
import '../../widgets/common.dart';

/// ISO weekday → short label (1 = Senin).
const _days = {1: 'Sen', 2: 'Sel', 3: 'Rab', 4: 'Kam', 5: 'Jum', 6: 'Sab', 7: 'Min'};

String _daysText(List<int>? days) => days == null || days.isEmpty || days.length == 7
    ? 'Setiap hari'
    : days.map((d) => _days[d]).join(', ');

String _cutoffText(int minutes) {
  if (minutes <= 0) return 'Sampai jam mulai';
  if (minutes % 1440 == 0) return '${minutes ~/ 1440} hari sebelum';
  if (minutes % 60 == 0) return '${minutes ~/ 60} jam sebelum';
  return '$minutes menit sebelum';
}

final _scheduledMethodsProvider = FutureProvider.autoDispose<List<ScheduledShippingMethod>>(
  (ref) => ref.watch(deliveryScheduleServiceProvider).scheduledMethods(),
);

final _schedulesProvider = FutureProvider.autoDispose.family<List<DeliverySchedule>, String>(
  (ref, methodId) => ref.watch(deliveryScheduleServiceProvider).schedules(methodId),
);

final _holidaysProvider = FutureProvider.autoDispose.family<List<DeliveryHoliday>, String>(
  (ref, methodId) => ref.watch(deliveryScheduleServiceProvider).holidays(methodId),
);

/// Jadwal Pengiriman: delivery days, time slots and holidays per scheduled shipping method (WIB).
class DeliveryScheduleScreen extends ConsumerStatefulWidget {
  const DeliveryScheduleScreen({super.key});

  @override
  ConsumerState<DeliveryScheduleScreen> createState() => _DeliveryScheduleScreenState();
}

class _DeliveryScheduleScreenState extends ConsumerState<DeliveryScheduleScreen> {
  String? _methodId;

  Future<void> _refresh(String methodId) async {
    ref.invalidate(_schedulesProvider(methodId));
    ref.invalidate(_holidaysProvider(methodId));
    await ref.read(_schedulesProvider(methodId).future);
  }

  Future<void> _openForm(ScheduledShippingMethod method, [DeliverySchedule? schedule]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ScheduleForm(method: method, schedule: schedule),
    );
    if (saved == true) {
      ref.invalidate(_schedulesProvider(method.id));
      if (mounted) showMessage(context, schedule == null ? 'Jadwal ditambahkan.' : 'Jadwal diperbarui.');
    }
  }

  Future<void> _toggle(ScheduledShippingMethod method, DeliverySchedule s) async {
    try {
      await ref.read(deliveryScheduleServiceProvider).setScheduleActive(s, !s.isActive);
      ref.invalidate(_schedulesProvider(method.id));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(ScheduledShippingMethod method, DeliverySchedule s) async {
    final ok = await confirm(
      context,
      title: 'Hapus jadwal',
      message: 'Hapus jadwal "${s.label} (${s.startTime} - ${s.endTime})"?',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(deliveryScheduleServiceProvider).deleteSchedule(s.id);
      ref.invalidate(_schedulesProvider(method.id));
      if (mounted) showMessage(context, 'Jadwal dihapus.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _addHoliday(ScheduledShippingMethod method) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HolidayForm(method: method),
    );
    if (saved == true) {
      ref.invalidate(_holidaysProvider(method.id));
      if (mounted) showMessage(context, 'Hari libur ditambahkan.');
    }
  }

  Future<void> _deleteHoliday(ScheduledShippingMethod method, DeliveryHoliday h) async {
    final scope = h.shippingMethodId != null ? method.name : 'semua metode pengiriman';
    final ok = await confirm(
      context,
      title: 'Hapus hari libur',
      message: 'Hapus hari libur "${h.name}" (${formatDate(h.date)}) untuk $scope?',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(deliveryScheduleServiceProvider).deleteHoliday(h.id);
      ref.invalidate(_holidaysProvider(method.id));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = ref.watch(_scheduledMethodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Pengiriman')),
      body: methods.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorView(message: errorMessage(e), onRetry: () => ref.invalidate(_scheduledMethodsProvider)),
        ),
        data: (all) {
          if (all.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyView(
                  icon: Icons.event_busy_outlined,
                  text:
                      'Belum ada metode pengiriman terjadwal. Aktifkan "Pembeli memilih jadwal pengiriman" '
                      'di Metode Pengiriman (versi web).',
                ),
              ],
            );
          }
          final method = all.firstWhere((m) => m.id == _methodId, orElse: () => all.first);
          return RefreshIndicator(
            onRefresh: () => _refresh(method.id),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (all.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: method.id,
                    decoration: const InputDecoration(labelText: 'Metode pengiriman', isDense: true),
                    items: [
                      for (final m in all)
                        DropdownMenuItem(value: m.id, child: Text(m.isEnabled ? m.name : '${m.name} (nonaktif)')),
                    ],
                    onChanged: (id) => setState(() => _methodId = id),
                  )
                else
                  Text(method.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Pembeli bisa memesan untuk hari ini hingga ${method.scheduleDaysAhead - 1} hari ke depan. '
                  'Jam dalam WIB.',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: 'Hari & Jam Pengiriman',
                  actionLabel: 'Jadwal',
                  onAction: () => _openForm(method),
                ),
                _SchedulesList(
                  key: ValueKey('s-${method.id}'),
                  method: method,
                  onEdit: (s) => _openForm(method, s),
                  onToggle: (s) => _toggle(method, s),
                  onDelete: (s) => _delete(method, s),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Hari Libur', actionLabel: 'Libur', onAction: () => _addHoliday(method)),
                Text(
                  'Pada tanggal libur, semua jadwal ${method.name} ditutup.',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 8),
                _HolidaysList(
                  key: ValueKey('h-${method.id}'),
                  method: method,
                  onDelete: (h) => _deleteHoliday(method, h),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel, required this.onAction});

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      TextButton.icon(onPressed: onAction, icon: const Icon(Icons.add, size: 18), label: Text(actionLabel)),
    ],
  );
}

class _SchedulesList extends ConsumerWidget {
  const _SchedulesList({
    super.key,
    required this.method,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final ScheduledShippingMethod method;
  final ValueChanged<DeliverySchedule> onEdit;
  final ValueChanged<DeliverySchedule> onToggle;
  final ValueChanged<DeliverySchedule> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_schedulesProvider(method.id))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              ErrorView(message: errorMessage(e), onRetry: () => ref.invalidate(_schedulesProvider(method.id))),
          data: (items) {
            if (items.isEmpty) {
              return EmptyView(
                icon: Icons.schedule_outlined,
                text: 'Belum ada jadwal. Pembeli tidak dapat memilih ${method.name} sampai ada jadwal aktif.',
              );
            }
            return Column(
              children: [
                for (final s in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        onTap: () => onEdit(s),
                        contentPadding: const EdgeInsets.only(left: 16, right: 4),
                        title: Text(
                          '${s.label} · ${s.startTime} - ${s.endTime}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            _daysText(s.days),
                            'Batas pesan: ${_cutoffText(s.cutoffMinutes)}',
                            'Kuota/hari: ${s.quota ?? 'Tanpa batas'}',
                          ].join('\n'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(value: s.isActive, onChanged: (_) => onToggle(s)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
                              onPressed: () => onDelete(s),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
  }
}

class _HolidaysList extends ConsumerWidget {
  const _HolidaysList({super.key, required this.method, required this.onDelete});

  final ScheduledShippingMethod method;
  final ValueChanged<DeliveryHoliday> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_holidaysProvider(method.id))
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              ErrorView(message: errorMessage(e), onRetry: () => ref.invalidate(_holidaysProvider(method.id))),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyView(icon: Icons.event_available_outlined, text: 'Tidak ada hari libur mendatang.');
            }
            return Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, h) in items.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.event_busy_outlined, color: AppColors.destructive),
                      title: Text(formatDate(h.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(h.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusBadge(
                            label: h.shippingMethodId != null ? method.name : 'Semua metode',
                            color: h.shippingMethodId != null ? AppColors.mutedForeground : AppColors.warning,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
                            onPressed: () => onDelete(h),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
  }
}

class _ScheduleForm extends ConsumerStatefulWidget {
  const _ScheduleForm({required this.method, this.schedule});

  final ScheduledShippingMethod method;
  final DeliverySchedule? schedule;

  @override
  ConsumerState<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends ConsumerState<_ScheduleForm> {
  late final _label = TextEditingController(text: widget.schedule?.label);
  late final _cutoff = TextEditingController(text: '${widget.schedule?.cutoffMinutes ?? 60}');
  late final _quota = TextEditingController(text: widget.schedule?.quota?.toString());
  late String _start = widget.schedule?.startTime ?? '09:00';
  late String _end = widget.schedule?.endTime ?? '12:00';
  late final Set<int> _selectedDays = {...(widget.schedule?.days ?? _days.keys)};
  late bool _isActive = widget.schedule?.isActive ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _cutoff.dispose();
    _quota.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final current = (start ? _start : _end).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(current[0]), minute: int.parse(current[1])),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _start = value : _end = value);
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    final cutoff = int.tryParse(_cutoff.text.trim());
    final quotaText = _quota.text.trim();
    final quota = quotaText.isEmpty ? null : int.tryParse(quotaText);
    String? error;
    if (_selectedDays.isEmpty) {
      error = 'Pilih minimal satu hari.';
    } else if (label.isEmpty) {
      error = 'Nama jadwal wajib diisi.';
    } else if (cutoff == null || cutoff < 0 || cutoff > 10080) {
      error = 'Batas pesan harus 0 - 10080 menit.';
    } else if (quotaText.isNotEmpty && (quota == null || quota < 1)) {
      error = 'Kuota minimal 1, atau kosongkan.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(deliveryScheduleServiceProvider)
          .saveSchedule(
            widget.method.id,
            DeliveryScheduleInput(
              label: label,
              startTime: _start,
              endTime: _end,
              cutoffMinutes: cutoff!,
              quota: quota,
              days: _selectedDays.toList()..sort(),
              isActive: _isActive,
            ),
            id: widget.schedule?.id,
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.schedule == null ? 'Tambah' : 'Ubah'} Jadwal · ${widget.method.name}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            const Text('Hari Pengiriman', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _days.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: _selectedDays.contains(e.key),
                    onSelected: (on) => setState(() => on ? _selectedDays.add(e.key) : _selectedDays.remove(e.key)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeField(label: 'Jam Mulai (WIB)', value: _start, onTap: () => _pickTime(true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(label: 'Jam Selesai (WIB)', value: _end, onTap: () => _pickTime(false)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Nama Jadwal', hintText: 'mis. Pagi', counterText: ''),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _cutoff,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Batas Pesan (menit)',
                      helperText: 'Sebelum jam mulai (1440 = 1 hari)',
                      helperMaxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quota,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kuota per Hari',
                      hintText: 'Tanpa batas',
                      helperText: 'Kosongkan jika tidak dibatasi',
                      helperMaxLines: 2,
                    ),
                  ),
                ),
              ],
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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule)),
      child: Text(value, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
    ),
  );
}

class _HolidayForm extends ConsumerStatefulWidget {
  const _HolidayForm({required this.method});

  final ScheduledShippingMethod method;

  @override
  ConsumerState<_HolidayForm> createState() => _HolidayFormState();
}

class _HolidayFormState extends ConsumerState<_HolidayForm> {
  final _name = TextEditingController();
  DateTime? _date;
  bool _allMethods = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (_date == null || name.isEmpty) {
      setState(() => _error = 'Tanggal dan keterangan wajib diisi.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(deliveryScheduleServiceProvider)
          .addHoliday(date: _date!, name: name, methodId: _allMethods ? null : widget.method.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tambah Hari Libur', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Tanggal', suffixIcon: Icon(Icons.calendar_today)),
                child: Text(_date == null ? 'Pilih tanggal' : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_date!)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Keterangan', hintText: 'mis. Idul Fitri', counterText: ''),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Berlaku untuk semua metode'),
              value: _allMethods,
              onChanged: (v) => setState(() => _allMethods = v ?? false),
            ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.destructive)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Tambah Libur'),
            ),
          ],
        ),
      ),
    );
  }
}
