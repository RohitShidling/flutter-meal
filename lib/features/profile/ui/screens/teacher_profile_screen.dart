import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/profile/data/models/profile_models.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/utils/validators.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/widgets/searchable_dropdown.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/utils/time_utils.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _schoolController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _timeController;
  
  SchoolModel? _selectedSchool;
  StateModel? _selectedState;
  CityModel? _selectedCity;
  MealSizeModel? _selectedMealSize;
  
  String _status = 'active';
  bool _isInitializing = true;
  bool _isSaving = false;
  bool _isEditing = false;

  // Switch to onUserInteraction after first submit attempt
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _schoolController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _timeController = TextEditingController(text: '13:30');
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ProfileProvider>();
      final lookupProvider = context.read<LookupProvider>();
      
      // Fetch lookup data first so dropdowns are ready
      await lookupProvider.fetchInitialData();
      await provider.fetchProfiles(force: true);
      
      final profile = provider.teacherProfile;
      if (profile != null && mounted) {
        // Match existing selections from lookup data
        _selectedSchool = lookupProvider.schools.where((s) => s.name == profile.schoolCollegeName).firstOrNull;
        _selectedState = lookupProvider.states.where((s) => s.name.toLowerCase() == profile.state.toLowerCase()).firstOrNull;

        // Trigger dependent fetches if values exist
        if (_selectedState != null) {
          await lookupProvider.fetchCitiesByState(_selectedState!.id);
          if (mounted) {
            _selectedCity = lookupProvider.cities.where((s) => s.name.toLowerCase() == profile.city.toLowerCase()).firstOrNull;
          }
        }

        if (mounted) {
          setState(() {
            _nameController.text = profile.name;
            _schoolController.text = profile.schoolCollegeName;
            _cityController.text = profile.city;
            _stateController.text = profile.state;
            _status = profile.status;
            _timeController.text = profile.mealTime ?? '13:30';
            _selectedMealSize = lookupProvider.mealSizes.where((m) => m.id == profile.mealSizeId).firstOrNull;
            _isEditing = false;
            _isInitializing = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _isEditing = true;
          _isInitializing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _timeController.dispose();
    super.dispose();
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

  Future<void> _submitForm() async {
    final profileProvider = context.read<ProfileProvider>();

    // Activate auto-validation so errors clear on user interaction
    if (_autovalidateMode != AutovalidateMode.onUserInteraction) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    }

    if (!_formKey.currentState!.validate()) {
      return; // errors are shown inline by validators
    }

    if (_selectedMealSize == null) {
      ErrorHandler.showError(context, 'Please select a meal size');
      return;
    }

    setState(() => _isSaving = true);

    final profile = TeacherProfileModel(
      name: _nameController.text.trim(),
      schoolCollegeName: _schoolController.text,
      city: _cityController.text,
      state: _stateController.text,
      location: '',
      status: _status,
      mealSizeId: _selectedMealSize!.id,
      mealTime: _timeController.text,
    );
    
    final success = await profileProvider.saveTeacherProfile(profile);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ErrorHandler.showSuccess(context, 'Teacher profile saved successfully');
      setState(() => _isEditing = false);
      profileProvider.fetchProfiles(force: true);
    } else {
      ErrorHandler.showError(context, profileProvider.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final lookupProvider = context.watch<LookupProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = profileProvider.teacherProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Teacher Profile',
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: (profileProvider.isLoading || _isInitializing)
        ? const Center(child: CircularProgressIndicator())
        : (profile != null && !_isEditing)
          ? _buildProfileCard(context, profile)
          : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    profile == null 
                      ? 'Setup your teacher profile for school deliveries.'
                      : 'Update your teacher profile details below.',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 1. Full Name
                  TextFormField(
                    controller: _nameController,
                    autofocus: false,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(CupertinoIcons.person_fill),
                    ),
                    textInputAction: TextInputAction.done,
                    validator: (v) => Validators.name(v, fieldName: 'Full Name'),
                  ),
                  const SizedBox(height: 20),

                  // 2. School/College — ALL active schools from GET /api/client/schools
                  SearchableDropdown<SchoolModel>(
                    label: 'School/College Name',
                    items: lookupProvider.schools,
                    itemLabel: (s) => '${s.name} (${s.city})',
                    value: _selectedSchool,
                    isLoading: lookupProvider.isLoading,
                    listenable: lookupProvider,
                    itemsGetter: () => lookupProvider.schools,
                    loadingGetter: () => lookupProvider.isLoading,
                    validator: (v) => Validators.requiredField(v, 'School/College'),
                    onInteraction: () {
                      FocusScope.of(context).unfocus();
                      lookupProvider.fetchInitialData();
                    },
                    onChanged: (v) {
                      setState(() {
                        _selectedSchool = v;
                        _schoolController.text = v?.name ?? '';
                        // Auto-fill state and city from school data
                        if (v != null) {
                          _selectedState = lookupProvider.states.where((s) => s.name.toLowerCase() == v.state.toLowerCase()).firstOrNull;
                          _stateController.text = v.state;
                          if (_selectedState != null) {
                            lookupProvider.fetchCitiesByState(_selectedState!.id).then((_) {
                              if (mounted) {
                                setState(() {
                                  _selectedCity = lookupProvider.cities.where((c) => c.name.toLowerCase() == v.city.toLowerCase()).firstOrNull;
                                  _cityController.text = v.city;
                                });
                              }
                            });
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. State (auto-filled from school, but can be manually changed)
                  SearchableDropdown<StateModel>(
                    label: 'State',
                    items: lookupProvider.states,
                    itemLabel: (s) => s.name,
                    value: _selectedState,
                    isLoading: lookupProvider.isLoading,
                    listenable: lookupProvider,
                    itemsGetter: () => lookupProvider.states,
                    loadingGetter: () => lookupProvider.isLoading,
                    validator: (v) => Validators.requiredField(v, 'State'),
                    onInteraction: () {
                      FocusScope.of(context).unfocus();
                      lookupProvider.fetchInitialData();
                    },
                    onChanged: (v) {
                      setState(() {
                        if (_selectedState?.id != v?.id) {
                          _selectedState = v;
                          _stateController.text = v?.name ?? '';
                          _selectedCity = null;
                          _cityController.text = '';
                          if (v != null) {
                            lookupProvider.fetchCitiesByState(v.id);
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // 4. City
                  SearchableDropdown<CityModel>(
                    label: 'City',
                    items: lookupProvider.cities,
                    itemLabel: (s) => s.name,
                    value: _selectedCity,
                    isLoading: lookupProvider.isLoading,
                    listenable: lookupProvider,
                    itemsGetter: () => lookupProvider.cities,
                    loadingGetter: () => lookupProvider.isLoading,
                    validator: (v) => Validators.requiredField(v, 'City'),
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
                        _cityController.text = v?.name ?? '';
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // 5. Meal Size
                  SearchableDropdown<MealSizeModel>(
                    label: 'Meal Size',
                    items: lookupProvider.mealSizes,
                    itemLabel: (m) => m.displayName,
                    value: _selectedMealSize,
                    isLoading: lookupProvider.isLoading,
                    listenable: lookupProvider,
                    itemsGetter: () => lookupProvider.mealSizes,
                    loadingGetter: () => lookupProvider.isLoading,
                    validator: (v) => Validators.requiredField(v, 'Meal Size'),
                    onInteraction: () {
                      FocusScope.of(context).unfocus();
                      lookupProvider.fetchInitialData();
                    },
                    onChanged: (v) {
                      setState(() => _selectedMealSize = v);
                    },
                  ),

                  const SizedBox(height: 20),

                  // 6. Meal Time
                  InkWell(
                    onTap: () => _selectTime(context),
                    child: IgnorePointer(
                      child: TextFormField(
                        controller: TextEditingController(text: TimeUtils.formatToDisplay(_timeController.text)),
                        decoration: const InputDecoration(
                          labelText: 'Meal Time',
                          hintText: 'Select meal delivery time',
                          prefixIcon: Icon(CupertinoIcons.clock_fill),
                          suffixIcon: Icon(CupertinoIcons.chevron_down, size: 16),
                        ),
                        validator: (v) => Validators.time(_timeController.text, fieldName: 'Meal time'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(profile == null ? 'Save Teacher Profile' : 'Update Profile'),
                  ),
                  if (_isEditing && profile != null) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Cancel Edit'),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildProfileCard(BuildContext context, TeacherProfileModel profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lookup = context.read<LookupProvider>();
    final mealSizeName = lookup.mealSizes.where((m) => m.id == profile.mealSizeId).firstOrNull?.displayName ?? 'Default';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark 
                          ? [AppTheme.primaryColor.withOpacity(0.2), Colors.transparent]
                          : [AppTheme.primaryColor.withOpacity(0.05), Colors.transparent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.person_crop_square_fill, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                style: TextStyle(
                                  fontSize: 20, 
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                ),
                              ),
                              Text(
                                'Teacher Profile',
                                style: TextStyle(
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildIconButton(CupertinoIcons.pencil, Colors.blue, () => setState(() => _isEditing = true)),
                        const SizedBox(width: 8),
                        _buildIconButton(CupertinoIcons.trash, Colors.red, () => _confirmDelete(context)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        _buildInfoRow(CupertinoIcons.building_2_fill, profile.schoolCollegeName, isDark),
                        const SizedBox(height: 14),
                        _buildInfoRow(CupertinoIcons.location_solid, '${profile.city}, ${profile.state}', isDark),
                        const SizedBox(height: 14),
                        _buildInfoRow(CupertinoIcons.clock_fill, 'Meal Time: ${TimeUtils.formatToDisplay(profile.mealTime ?? '12:30:00')}', isDark),
                        const SizedBox(height: 14),
                        _buildInfoRow(CupertinoIcons.square_grid_2x2_fill, 'Meal Size: $mealSizeName', isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Your teacher profile is active. Meals will be delivered to your school/college.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white.withOpacity(0.9) : AppTheme.textPrimaryLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Teacher Profile'),
        content: const Text('Are you sure you want to delete your teacher profile? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final success = await context.read<ProfileProvider>().deleteTeacherProfile();
              if (!mounted) return;
              if (success) {
                ErrorHandler.showSuccess(this.context, 'Teacher profile deleted successfully');
                // Provider update will show empty form
              } else {
                ErrorHandler.showError(this.context, 'Failed to delete — profile may have active subscriptions');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
