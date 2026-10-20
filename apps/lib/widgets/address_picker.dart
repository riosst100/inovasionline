import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/region.dart';
import '../providers/core_providers.dart';

class AddressSelection {
  const AddressSelection({
    this.province,
    this.city,
    this.district,
    this.village,
  });

  final Region? province;
  final Region? city;
  final Region? district;
  final Region? village;

  bool get isComplete => province != null && city != null && district != null && village != null;
}

class AddressPicker extends ConsumerStatefulWidget {
  const AddressPicker({super.key, required this.onChanged, this.initial});

  final ValueChanged<AddressSelection> onChanged;
  final AddressSelection? initial;

  @override
  ConsumerState<AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends ConsumerState<AddressPicker> {
  List<Region> _provinces = [];
  List<Region> _cities = [];
  List<Region> _districts = [];
  List<Region> _villages = [];

  Region? _province;
  Region? _city;
  Region? _district;
  Region? _village;

  bool _loadingProvinces = true;

  @override
  void initState() {
    super.initState();
    _province = widget.initial?.province;
    _city = widget.initial?.city;
    _district = widget.initial?.district;
    _village = widget.initial?.village;
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final provinces = await ref.read(regionServiceProvider).provinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _loadingProvinces = false;
      });

      if (_province != null) {
        final cities = await ref.read(regionServiceProvider).cities(_province!.code);
        if (!mounted) return;
        setState(() => _cities = cities);
      }
      if (_city != null) {
        final districts = await ref.read(regionServiceProvider).districts(_city!.code);
        if (!mounted) return;
        setState(() => _districts = districts);
      }
      if (_district != null) {
        final villages = await ref.read(regionServiceProvider).villages(_district!.code);
        if (!mounted) return;
        setState(() => _villages = villages);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _onProvinceChanged(Region? province) async {
    setState(() {
      _province = province;
      _city = null;
      _district = null;
      _village = null;
      _cities = [];
      _districts = [];
      _villages = [];
    });
    _notify();

    if (province == null) return;
    final cities = await ref.read(regionServiceProvider).cities(province.code);
    if (!mounted) return;
    setState(() => _cities = cities);
  }

  Future<void> _onCityChanged(Region? city) async {
    setState(() {
      _city = city;
      _district = null;
      _village = null;
      _districts = [];
      _villages = [];
    });
    _notify();

    if (city == null) return;
    final districts = await ref.read(regionServiceProvider).districts(city.code);
    if (!mounted) return;
    setState(() => _districts = districts);
  }

  Future<void> _onDistrictChanged(Region? district) async {
    setState(() {
      _district = district;
      _village = null;
      _villages = [];
    });
    _notify();

    if (district == null) return;
    final villages = await ref.read(regionServiceProvider).villages(district.code);
    if (!mounted) return;
    setState(() => _villages = villages);
  }

  void _onVillageChanged(Region? village) {
    setState(() => _village = village);
    _notify();
  }

  void _notify() {
    widget.onChanged(AddressSelection(
      province: _province,
      city: _city,
      district: _district,
      village: _village,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProvinces) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RegionDropdown(
          label: 'Provinsi',
          value: _province,
          items: _provinces,
          onChanged: _onProvinceChanged,
        ),
        const SizedBox(height: 16),
        _RegionDropdown(
          label: 'Kabupaten/Kota',
          value: _city,
          items: _cities,
          enabled: _province != null,
          onChanged: _onCityChanged,
        ),
        const SizedBox(height: 16),
        _RegionDropdown(
          label: 'Kecamatan',
          value: _district,
          items: _districts,
          enabled: _city != null,
          onChanged: _onDistrictChanged,
        ),
        const SizedBox(height: 16),
        _RegionDropdown(
          label: 'Desa/Kelurahan',
          value: _village,
          items: _villages,
          enabled: _district != null,
          onChanged: _onVillageChanged,
        ),
      ],
    );
  }
}

class _RegionDropdown extends StatelessWidget {
  const _RegionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final Region? value;
  final List<Region> items;
  final bool enabled;
  final ValueChanged<Region?> onChanged;

  @override
  Widget build(BuildContext context) {
    // The list loads after the value is known; until then show it empty, as a
    // value missing from the items is an error.
    return DropdownButtonFormField<Region>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((region) => DropdownMenuItem(value: region, child: Text(region.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (value) => value == null ? '$label wajib dipilih' : null,
    );
  }
}
