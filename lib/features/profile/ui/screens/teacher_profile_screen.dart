import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/features/profile/data/models/profile_models.dart';
import 'package:meal_app/core/utils/error_handler.dart';

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
  late TextEditingController _locationController;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().teacherProfile;
    _nameController = TextEditingController(text: profile?.name);
    _schoolController = TextEditingController(text: profile?.schoolCollegeName);
    _cityController = TextEditingController(text: profile?.city);
    _stateController = TextEditingController(text: profile?.state);
    _locationController = TextEditingController(text: profile?.location);
    _status = profile?.status ?? 'active';
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Profile'),
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
                    'Update your teacher profile details below.',
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
                    controller: _schoolController,
                    decoration: const InputDecoration(
                      labelText: 'School/College Name',
                      prefixIcon: Icon(CupertinoIcons.building_2_fill),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
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
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Specific Location',
                      prefixIcon: Icon(CupertinoIcons.placemark_fill),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final profile = TeacherProfileModel(
                          name: _nameController.text,
                          schoolCollegeName: _schoolController.text,
                          city: _cityController.text,
                          state: _stateController.text,
                          location: _locationController.text,
                          status: _status,
                        );
                        
                        final success = await profileProvider.saveTeacherProfile(profile);
                        if (success && mounted) {
                          ErrorHandler.showSuccess(context, 'Teacher profile saved successfully');
                          Navigator.pop(context);
                        } else if (mounted) {
                          ErrorHandler.showError(context, profileProvider.error);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    child: const Text('Save Profile'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
