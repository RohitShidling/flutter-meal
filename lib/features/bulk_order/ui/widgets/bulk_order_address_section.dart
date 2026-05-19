import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/core/widgets/searchable_dropdown.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';

/// Delivery address for bulk orders (state/city from master data + street address).
class BulkOrderAddressSection extends StatefulWidget {
  const BulkOrderAddressSection({super.key});

  @override
  State<BulkOrderAddressSection> createState() => _BulkOrderAddressSectionState();
}

class _BulkOrderAddressSectionState extends State<BulkOrderAddressSection> {
  StateModel? _selectedState;
  CityModel? _selectedCity;
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LookupProvider>().fetchInitialData();
      _hydrateFromProvider();
    });
  }

  void _hydrateFromProvider() {
    final saved = context.read<BulkOrderProvider>().deliveryAddress;
    if (saved == null || _hydrated) return;
    _addressController.text = saved.addressLine;
    _pincodeController.text = saved.pincode ?? '';
    final lookup = context.read<LookupProvider>();
    _selectedState = lookup.states.where((s) => s.id == saved.stateId).firstOrNull;
    if (_selectedState != null) {
      lookup.fetchCitiesByState(_selectedState!.id).then((_) {
        if (!mounted) return;
        setState(() {
          _selectedCity = lookup.cities.where((c) => c.id == saved.cityId).firstOrNull;
          _hydrated = true;
        });
      });
    } else {
      _hydrated = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _syncToProvider() {
    final state = _selectedState;
    final city = _selectedCity;
    final line = _addressController.text.trim();
    final pin = _pincodeController.text.trim();
    final provider = context.read<BulkOrderProvider>();

    if (state == null || city == null || line.length < 5) {
      provider.setDeliveryAddress(null);
      return;
    }

    provider.setDeliveryAddress(
      BulkDeliveryAddress(
        stateId: state.id,
        cityId: city.id,
        addressLine: line,
        pincode: pin.isEmpty ? null : pin,
        stateName: state.name,
        cityName: city.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lookup = context.watch<LookupProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Delivery address',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Where meals should be delivered',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          SearchableDropdown<StateModel>(
            label: 'State',
            items: lookup.states,
            itemLabel: (s) => s.name,
            value: _selectedState,
            isLoading: lookup.isLoading,
            listenable: lookup,
            itemsGetter: () => lookup.states,
            loadingGetter: () => lookup.isLoading,
            onInteraction: () {
              FocusScope.of(context).unfocus();
              lookup.fetchInitialData();
            },
            onChanged: (v) {
              setState(() {
                if (_selectedState?.id != v?.id) {
                  _selectedState = v;
                  _selectedCity = null;
                  if (v != null) {
                    lookup.fetchCitiesByState(v.id);
                  }
                }
              });
              _syncToProvider();
            },
          ),
          const SizedBox(height: 16),
          SearchableDropdown<CityModel>(
            label: 'City',
            items: lookup.cities,
            itemLabel: (c) => c.name,
            value: _selectedCity,
            isLoading: lookup.isLoading,
            listenable: lookup,
            itemsGetter: () => lookup.cities,
            loadingGetter: () => lookup.isLoading,
            onInteraction: () {
              FocusScope.of(context).unfocus();
              if (_selectedState == null) {
                ErrorHandler.showError(context, 'Please select a state first');
              }
            },
            onChanged: (v) {
              setState(() => _selectedCity = v);
              _syncToProvider();
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Street / building address',
              hintText: 'House no., street, landmark',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => _syncToProvider(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pincodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Pincode (optional)',
              counterText: '',
            ),
            onChanged: (_) => _syncToProvider(),
          ),
        ],
      ),
    );
  }
}
