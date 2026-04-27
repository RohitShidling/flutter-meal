import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/profile/data/models/profile_models.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/widgets/searchable_dropdown.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/utils/error_handler.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  const ProfessionalProfileScreen({super.key});

  @override
  State<ProfessionalProfileScreen> createState() => _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _timeController;
  
  CorporateLocationModel? _selectedLocation;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().professionalProfile;
    _nameController = TextEditingController(text: profile?.name);
    _companyController = TextEditingController(text: profile?.companyName);
    _cityController = TextEditingController(text: profile?.city);
    _stateController = TextEditingController(text: profile?.state);
    _timeController = TextEditingController(text: profile?.lunchTime ?? '13:00:00');
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primaryColor,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _timeController.text = '$hour:$minute:00';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final lookup = context.watch<LookupProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional Profile'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: profileProvider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Setup your corporate profile for lunch deliveries.',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(CupertinoIcons.person_fill),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _companyController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      prefixIcon: Icon(CupertinoIcons.briefcase_fill),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  SearchableDropdown<CorporateLocationModel>(
                    label: 'Corporate Location',
                    items: lookup.corporateLocations,
                    itemLabel: (l) => l.name,
                    value: _selectedLocation,
                    onChanged: (v) {
                      setState(() {
                        _selectedLocation = v;
                        if (v != null) {
                          _cityController.text = v.city;
                          _stateController.text = v.state;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(CupertinoIcons.location_fill),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      prefixIcon: Icon(CupertinoIcons.map_fill),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => _selectTime(context),
                    child: IgnorePointer(
                      child: TextFormField(
                        controller: _timeController,
                        decoration: const InputDecoration(
                          labelText: 'Lunch Time',
                          hintText: 'Select lunch delivery time',
                          prefixIcon: Icon(CupertinoIcons.clock_fill),
                          suffixIcon: Icon(CupertinoIcons.chevron_down, size: 16),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate() && _selectedLocation != null) {
                        final profile = ProfessionalProfileModel(
                          name: _nameController.text,
                          companyName: _companyController.text,
                          corporateLocationId: _selectedLocation!.id,
                          city: _cityController.text,
                          state: _stateController.text,
                          lunchTime: _timeController.text,
                        );
                        
                        final success = await profileProvider.saveProfessionalProfile(profile);
                        if (success && mounted) {
                          ErrorHandler.showSuccess(context, 'Professional profile saved successfully');
                          Navigator.pop(context);
                        } else if (mounted) {
                          ErrorHandler.showError(context, profileProvider.error);
                        }
                      } else {
                        ErrorHandler.showError(context, 'Please fill all fields and select a location');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    child: const Text('Save Professional Profile'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

