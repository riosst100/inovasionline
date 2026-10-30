import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
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

/// A field label followed by a red asterisk, marking the field as required.
Widget requiredLabel(String text) => Text.rich(
      TextSpan(
        text: text,
        children: const [
          TextSpan(text: ' *', style: TextStyle(color: Color(0xFFEF4444))),
        ],
      ),
    );

class AddressPicker extends ConsumerStatefulWidget {
  const AddressPicker({
    super.key,
    required this.onChanged,
    this.initial,
    this.showErrors = false,
    this.autoSelectSingle = false,
  });

  final ValueChanged<AddressSelection> onChanged;
  final AddressSelection? initial;

  /// Picks a region by itself whenever it is the only one on offer, at every
  /// level (province down to village).
  final bool autoSelectSingle;

  /// Marks every region still empty as required.
  final bool showErrors;

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

      if (_province == null &&
          widget.autoSelectSingle &&
          provinces.length == 1) {
        await _onProvinceChanged(provinces.first);
        return;
      }

      if (_province != null) {
        final cities = await ref.read(regionServiceProvider).cities(_province!.code);
        if (!mounted) return;
        setState(() => _cities = cities);
        if (_city == null && widget.autoSelectSingle && cities.length == 1) {
          await _onCityChanged(cities.first);
          return;
        }
      }
      if (_city != null) {
        final districts = await ref.read(regionServiceProvider).districts(_city!.code);
        if (!mounted) return;
        setState(() => _districts = districts);
        if (_district == null &&
            widget.autoSelectSingle &&
            districts.length == 1) {
          await _onDistrictChanged(districts.first);
          return;
        }
      }
      if (_district != null) {
        final villages = await ref.read(regionServiceProvider).villages(_district!.code);
        if (!mounted) return;
        setState(() => _villages = villages);
        if (_village == null &&
            widget.autoSelectSingle &&
            villages.length == 1) {
          _onVillageChanged(villages.first);
        }
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
    if (widget.autoSelectSingle && cities.length == 1) {
      await _onCityChanged(cities.first);
    }
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
    if (widget.autoSelectSingle && districts.length == 1) {
      await _onDistrictChanged(districts.first);
    }
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
    if (widget.autoSelectSingle && villages.length == 1) {
      _onVillageChanged(villages.first);
    }
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
          showError: widget.showErrors,
          onChanged: _onProvinceChanged,
        ),
        const SizedBox(height: 12),
        _RegionDropdown(
          label: 'Kabupaten/Kota',
          value: _city,
          items: _cities,
          showError: widget.showErrors,
          enabled: _province != null,
          onChanged: _onCityChanged,
        ),
        const SizedBox(height: 12),
        _RegionDropdown(
          label: 'Kecamatan',
          value: _district,
          items: _districts,
          showError: widget.showErrors,
          enabled: _city != null,
          onChanged: _onDistrictChanged,
        ),
        const SizedBox(height: 12),
        _RegionDropdown(
          label: 'Desa/Kelurahan',
          value: _village,
          items: _villages,
          showError: widget.showErrors,
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
    this.showError = false,
  });

  final bool showError;
  final String label;
  final Region? value;
  final List<Region> items;
  final bool enabled;
  final ValueChanged<Region?> onChanged;

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    // The list loads after the value is known; until then show it empty, as a
    // value missing from the items is an error.
    return DropdownButtonFormField<Region>(
      // Rebuilt when the value is set from code (e.g. auto-selected).
      key: ValueKey('$label-${value?.code}'),
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.foreground,
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      iconSize: 22,
      borderRadius: BorderRadius.circular(14),
      dropdownColor: Colors.white,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        label: requiredLabel(label),
        labelStyle: const TextStyle(fontSize: 13.5),
        floatingLabelStyle: const TextStyle(fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: enabled ? const Color(0xFFF3F6F9) : const Color(0xFFF8FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        errorText: showError && value == null ? '$label wajib dipilih' : null,
        border: _border(Colors.transparent),
        enabledBorder: _border(Colors.transparent),
        disabledBorder: _border(Colors.transparent),
        focusedBorder: _border(AppColors.primary, width: 1.5),
        errorBorder: _border(const Color(0xFFEF4444)),
        focusedErrorBorder: _border(const Color(0xFFEF4444), width: 1.5),
      ),
      items: items
          .map((region) => DropdownMenuItem(value: region, child: Text(region.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (value) => value == null ? '$label wajib dipilih' : null,
    );
  }
}
