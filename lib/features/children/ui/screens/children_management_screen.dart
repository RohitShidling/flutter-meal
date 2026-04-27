import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/widgets/apple_card.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/children/data/models/child_model.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/widgets/searchable_dropdown.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/utils/error_handler.dart';

class ChildrenManagementScreen extends StatefulWidget {
  const ChildrenManagementScreen({super.key});

  @override
  State<ChildrenManagementScreen> createState() => _ChildrenManagementScreenState();
}

class _ChildrenManagementScreenState extends State<ChildrenManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final childrenProvider = context.watch<ChildrenProvider>();
    final children = childrenProvider.children;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Manage Children'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: childrenProvider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (children.isEmpty)
                _buildEmptyState()
              else
                ...children.map((child) => _buildChildCard(context, child)),
              
              if (children.length < 3)
                const SizedBox(height: 20),
              if (children.length < 3)
                ElevatedButton.icon(
                  onPressed: () => _showChildForm(context),
                  icon: const Icon(CupertinoIcons.add),
                  label: const Text('Add Child'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                  ),
                ),
              if (children.length >= 3)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    'Maximum 3 children allowed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        Icon(CupertinoIcons.person_2, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 20),
        Text(
          'No children added yet',
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w600, 
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Register your children to manage their meals.',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
      ],
    );
  }

  Widget _buildChildCard(BuildContext context, ChildModel child) {
    return AppleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                child.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.pencil, color: AppTheme.primaryColor),
                    onPressed: () => _showChildForm(context, child: child),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.trash, color: AppTheme.accentColor),
                    onPressed: () => _confirmDelete(context, child),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          _buildInfoRow(CupertinoIcons.building_2_fill, child.schoolName ?? 'School ID: ${child.schoolId}'),
          _buildInfoRow(CupertinoIcons.book_fill, child.standardName ?? 'Standard ID: ${child.standardId}'),
          _buildInfoRow(CupertinoIcons.clock_fill, 'Meal Time: ${child.mealTime}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    final color = Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  void _showChildForm(BuildContext context, {ChildModel? child}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChildForm(child: child),
    );
  }

  void _confirmDelete(BuildContext context, ChildModel child) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Child'),
        content: Text('Are you sure you want to delete ${child.name}?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              context.read<ChildrenProvider>().deleteChild(child.id!);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ChildForm extends StatefulWidget {
  final ChildModel? child;
  const _ChildForm({this.child});

  @override
  State<_ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends State<_ChildForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rollController;
  late TextEditingController _timeController;
  
  SchoolModel? _selectedSchool;
  StandardModel? _selectedStandard;
  MealSizeModel? _selectedMealSize;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child?.name);
    _rollController = TextEditingController(text: widget.child?.rollNumber);
    _timeController = TextEditingController(text: widget.child?.mealTime ?? '12:30:00');
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
    final lookup = context.watch<LookupProvider>();
    final childrenProvider = context.read<ChildrenProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        left: 24, 
        right: 24, 
        top: 24, 
        bottom: MediaQuery.of(context).viewInsets.bottom + 24
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.child == null ? 'Add Child' : 'Edit Child',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Child Name', prefixIcon: Icon(CupertinoIcons.person)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rollController,
                decoration: const InputDecoration(labelText: 'Roll Number', prefixIcon: Icon(CupertinoIcons.number)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              SearchableDropdown<SchoolModel>(
                label: 'School',
                items: lookup.schools,
                itemLabel: (s) => s.name,
                value: _selectedSchool,
                onChanged: (v) => setState(() => _selectedSchool = v),
                onSearch: (q) => lookup.searchSchools(q),
              ),
              const SizedBox(height: 16),
              SearchableDropdown<StandardModel>(
                label: 'Standard',
                items: lookup.standards,
                itemLabel: (s) => s.displayName,
                value: _selectedStandard,
                onChanged: (v) => setState(() => _selectedStandard = v),
              ),
              const SizedBox(height: 16),
              SearchableDropdown<MealSizeModel>(
                label: 'Meal Size',
                items: lookup.mealSizes,
                itemLabel: (s) => s.displayName,
                value: _selectedMealSize,
                onChanged: (v) => setState(() => _selectedMealSize = v),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectTime(context),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: _timeController,
                    decoration: InputDecoration(
                      labelText: 'Meal Time', 
                      hintText: 'Select delivery time',
                      prefixIcon: const Icon(CupertinoIcons.clock),
                      suffixIcon: const Icon(CupertinoIcons.chevron_down, size: 16),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate() && 
                      _selectedSchool != null && 
                      _selectedStandard != null && 
                      _selectedMealSize != null) {
                    
                    final newChild = ChildModel(
                      name: _nameController.text,
                      rollNumber: _rollController.text,
                      schoolId: _selectedSchool!.id,
                      standardId: _selectedStandard!.id,
                      mealSizeId: _selectedMealSize!.id,
                      mealTime: _timeController.text,
                    );

                    bool success;
                    if (widget.child == null) {
                      success = await childrenProvider.addChild(newChild);
                    } else {
                      success = await childrenProvider.updateChild(widget.child!.id!, newChild);
                    }

                    if (success) {
                      if (mounted) ErrorHandler.showSuccess(context, widget.child == null ? 'Child registered!' : 'Profile updated!');
                      Navigator.pop(context);
                    } else {
                      if (mounted) ErrorHandler.showError(context, childrenProvider.error);
                    }
                  } else {
                    ErrorHandler.showError(context, 'Please fill all fields');
                  }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
                child: Text(widget.child == null ? 'Register Child' : 'Update Child'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

