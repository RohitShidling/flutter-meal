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
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  const ProfessionalProfileScreen({super.key});

  @override
  State<ProfessionalProfileScreen> createState() => _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _timeController;
  
  CorporateLocationModel? _selectedCorporateLocation;
  StateModel? _selectedState;
  CityModel? _selectedCity;
  
  bool _isInitializing = true;

  // Track per-field errors for clearing on interaction
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _timeController = TextEditingController(text: '13:30');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lookup = context.read<LookupProvider>();
      final profileProvider = context.read<ProfileProvider>();
      
      // Fetch lookup data FIRST so dropdowns can be pre-filled
      await lookup.fetchInitialData();
      // Also fetch corporate locations
      await lookup.fetchCorporateLocations();
      await profileProvider.fetchProfiles(force: true);

      final profile = profileProvider.professionalProfile;
      if (profile != null && mounted) {
        setState(() {
          _nameController.text = profile.name;
          _timeController.text = profile.lunchTime;
          
          // Match corporate location by name
          _selectedCorporateLocation = lookup.corporateLocations
              .where((c) => c.name == profile.companyName || c.id == profile.corporateLocationId)
              .firstOrNull;
          
          _selectedState = lookup.states.where((s) => s.name == profile.state).firstOrNull;
          
          // Trigger dependent fetch for cities
          if (_selectedState != null) {
            lookup.fetchCitiesByState(_selectedState!.id).then((_) {
              if (mounted) {
                setState(() {
                  _selectedCity = lookup.cities.where((c) => c.name == profile.city).firstOrNull;
                });
              }
            });
          }
          
          _isInitializing = false;
        });
      } else if (mounted) {
        setState(() => _isInitializing = false);
      }
    });
  }

  Future<void> _selectTime(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 13, minute: 30),
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
      setState(() {
        _timeController.text = TimeUtils.toBackendFormat(picked);
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
        title: Text(
          'Professional Profile',
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: (profileProvider.isLoading || _isInitializing)
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
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // 1. Full Name
                  TextFormField(
                    controller: _nameController,
                    autofocus: false,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(CupertinoIcons.person_fill),
                      errorText: _nameError,
                    ),
                    onTap: () {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Full Name is required';
                      if (RegExp(r'^\d+$').hasMatch(v)) return 'Name cannot be just a number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // 2. Company Name (from Corporate Locations API)
                  SearchableDropdown<CorporateLocationModel>(
                    label: 'Company Name',
                    items: lookup.corporateLocations,
                    itemLabel: (c) => c.name,
                    value: _selectedCorporateLocation,
                    isLoading: lookup.isLoading,
                    listenable: lookup,
                    itemsGetter: () => lookup.corporateLocations,
                    loadingGetter: () => lookup.isLoading,
                    validator: (v) => v == null ? 'Company Name is required' : null,
                    onInteraction: () {
                      FocusScope.of(context).unfocus();
                      lookup.fetchCorporateLocations();
                    },
                    onChanged: (v) {
                      setState(() {
                        _selectedCorporateLocation = v;
                        // Auto-fill state and city from corporate location
                        if (v != null) {
                          _selectedState = lookup.states.where((s) => s.name == v.state).firstOrNull;
                          if (_selectedState != null) {
                            lookup.fetchCitiesByState(_selectedState!.id).then((_) {
                              if (mounted) {
                                setState(() {
                                  _selectedCity = lookup.cities.where((c) => c.name == v.city).firstOrNull;
                                });
                              }
                            });
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  // 3. State
                  SearchableDropdown<StateModel>(
                    label: 'State',
                    items: lookup.states,
                    itemLabel: (s) => s.name,
                    value: _selectedState,
                    isLoading: lookup.isLoading,
                    listenable: lookup,
                    itemsGetter: () => lookup.states,
                    loadingGetter: () => lookup.isLoading,
                    validator: (v) => v == null ? 'State is required' : null,
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
                    },
                  ),
                  const SizedBox(height: 20),
                  // 4. City
                  SearchableDropdown<CityModel>(
                    label: 'City',
                    items: lookup.cities,
                    itemLabel: (c) => c.name,
                    value: _selectedCity,
                    isLoading: lookup.isLoading,
                    listenable: lookup,
                    itemsGetter: () => lookup.cities,
                    loadingGetter: () => lookup.isLoading,
                    validator: (v) => v == null ? 'City is required' : null,
                    onInteraction: () {
                      FocusScope.of(context).unfocus();
                      if (_selectedState == null) {
                        ErrorHandler.showError(context, 'Please select a state first');
                        return;
                      }
                    },
                    onChanged: (v) {
                      setState(() {
                        _selectedCity = v;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  // 5. Lunch Time
                  InkWell(
                    onTap: () => _selectTime(context),
                    child: IgnorePointer(
                      child: TextFormField(
                        controller: TextEditingController(text: TimeUtils.formatToDisplay(_timeController.text)),
                        decoration: const InputDecoration(
                          labelText: 'Lunch Time',
                          hintText: 'Select lunch delivery time',
                          prefixIcon: Icon(CupertinoIcons.clock_fill),
                          suffixIcon: Icon(CupertinoIcons.chevron_down, size: 16),
                        ),
                        validator: (v) => v!.isEmpty ? 'Lunch time is required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () async {
                      final childrenProvider = context.read<ChildrenProvider>();
                      final profileProvider = context.read<ProfileProvider>();
                      
                      if (childrenProvider.children.isNotEmpty || profileProvider.teacherProfile != null) {
                        ErrorHandler.showError(context, 'Professional account is not allowed for users with existing Children or Teacher profiles.');
                        return;
                      }

                      if (_formKey.currentState!.validate() && _selectedCorporateLocation != null) {
                        final profile = ProfessionalProfileModel(
                          name: _nameController.text,
                          companyName: _selectedCorporateLocation!.name,
                          corporateLocationId: _selectedCorporateLocation!.id.toString(),
                          city: _selectedCity?.name ?? _selectedCorporateLocation!.city,
                          state: _selectedState?.name ?? _selectedCorporateLocation!.state,
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
                        ErrorHandler.showError(context, 'Please fill all fields and select a company');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    child: const Text('Save Professional Profile'),
                  ),
                  if (context.read<ProfileProvider>().professionalProfile != null) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _confirmDelete(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Delete Professional Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Professional Profile'),
        content: const Text('Are you sure you want to delete your professional profile? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final success = await context.read<ProfileProvider>().deleteProfessionalProfile();
              if (success && mounted) {
                ErrorHandler.showSuccess(context, 'Professional profile deleted successfully');
                Navigator.pop(context);
              } else if (mounted) {
                ErrorHandler.showError(context, 'Failed to delete Already Subscribed');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
