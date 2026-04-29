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
import 'package:meal_app/core/utils/time_utils.dart';

class ChildrenManagementScreen extends StatefulWidget {
  const ChildrenManagementScreen({super.key});

  @override
  State<ChildrenManagementScreen> createState() => _ChildrenManagementScreenState();
}

class _ChildrenManagementScreenState extends State<ChildrenManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChildrenProvider>().fetchChildren();
    });
  }

  @override
  Widget build(BuildContext context) {
    final childrenProvider = context.watch<ChildrenProvider>();
    final children = childrenProvider.children;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Children'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => childrenProvider.fetchChildren(),
        child: childrenProvider.isLoading && children.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                const SizedBox(height: 80),
              ],
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
                    ? [Colors.indigo.withOpacity(0.2), Colors.transparent]
                    : [Colors.indigo.withOpacity(0.05), Colors.transparent],
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
                    child: const Icon(CupertinoIcons.person_fill, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Roll No: ${child.rollNumber}',
                          style: TextStyle(
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildIconButton(CupertinoIcons.pencil, Colors.blue, () => _showChildForm(context, child: child)),
                  const SizedBox(width: 8),
                  _buildIconButton(CupertinoIcons.trash, Colors.red, () => _confirmDelete(context, child)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildInfoRow(CupertinoIcons.building_2_fill, child.schoolName ?? 'School ID: ${child.schoolId}', isDark),
                  const SizedBox(height: 10),
                  _buildInfoRow(CupertinoIcons.book_fill, child.standardName ?? 'Standard ID: ${child.standardId}', isDark),
                  const SizedBox(height: 10),
                  _buildInfoRow(CupertinoIcons.clock_fill, 'Meal Delivery: ${TimeUtils.formatToDisplay(child.mealTime)}', isDark),
                ],
              ),
            ),
          ],
        ),
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
        Icon(icon, size: 16, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.textPrimaryDark.withOpacity(0.8) : AppTheme.textPrimaryLight.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              final success = await context.read<ChildrenProvider>().deleteChild(child.id!);
              if (success) {
                if (mounted) ErrorHandler.showSuccess(context, 'Child deleted successfully');
              } else {
                if (mounted) ErrorHandler.showError(context, 'Failed to delete child');
              }
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

  final _nameFocus = FocusNode();
  final _rollFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    
    _nameController = TextEditingController(text: widget.child?.name);
    _rollController = TextEditingController(text: widget.child?.rollNumber);
    _timeController = TextEditingController(text: widget.child?.mealTime ?? '13:30');

    // If editing, we need to fetch lookup data to pre-fill the selections
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lookup = context.read<LookupProvider>();
      if (widget.child != null) {
        await lookup.fetchInitialData();
        setState(() {
          _selectedSchool = lookup.schools.where((s) => s.id == widget.child!.schoolId).firstOrNull;
          _selectedStandard = lookup.standards.where((s) => s.id == widget.child!.standardId).firstOrNull;
          _selectedMealSize = lookup.mealSizes.where((s) => s.id == widget.child!.mealSizeId).firstOrNull;
        });
      }
    });
  }

  Future<void> _selectTime(BuildContext context) async {
    FocusScope.of(context).unfocus(); // Prevent focus jumping
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
                focusNode: _nameFocus,
                decoration: const InputDecoration(labelText: 'Child Name', prefixIcon: Icon(CupertinoIcons.person)),
                validator: (v) => v!.isEmpty ? 'Child Name is required' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rollController,
                focusNode: _rollFocus,
                decoration: const InputDecoration(labelText: 'Roll Number', prefixIcon: Icon(CupertinoIcons.number)),
                validator: (v) => v!.isEmpty ? 'Roll Number is required' : null,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              SearchableDropdown<SchoolModel>(
                label: 'School',
                items: lookup.schools,
                itemLabel: (s) => s.name,
                value: _selectedSchool,
                isLoading: lookup.isLoading,
                listenable: lookup,
                itemsGetter: () => lookup.schools,
                loadingGetter: () => lookup.isLoading,
                validator: (v) => v == null ? 'School is required' : null,
                onInteraction: () {
                  _rollFocus.unfocus();
                  _nameFocus.unfocus();
                  lookup.fetchInitialData();
                },
                onChanged: (v) => setState(() => _selectedSchool = v),
              ),
              const SizedBox(height: 16),
              SearchableDropdown<StandardModel>(
                label: 'Standard',
                items: lookup.standards,
                itemLabel: (s) => s.displayName,
                value: _selectedStandard,
                isLoading: lookup.isLoading,
                listenable: lookup,
                itemsGetter: () => lookup.standards,
                loadingGetter: () => lookup.isLoading,
                validator: (v) => v == null ? 'Standard is required' : null,
                onInteraction: () {
                  _rollFocus.unfocus();
                  _nameFocus.unfocus();
                  lookup.fetchInitialData();
                },
                onChanged: (v) => setState(() => _selectedStandard = v),
              ),
              const SizedBox(height: 16),
              SearchableDropdown<MealSizeModel>(
                label: 'Meal Size',
                items: lookup.mealSizes,
                itemLabel: (s) => s.displayName,
                value: _selectedMealSize,
                isLoading: lookup.isLoading,
                listenable: lookup,
                itemsGetter: () => lookup.mealSizes,
                loadingGetter: () => lookup.isLoading,
                validator: (v) => v == null ? 'Meal Size is required' : null,
                onInteraction: () {
                  _rollFocus.unfocus();
                  _nameFocus.unfocus();
                  lookup.fetchInitialData();
                },
                onChanged: (v) => setState(() => _selectedMealSize = v),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectTime(context),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: TextEditingController(text: TimeUtils.formatToDisplay(_timeController.text)),
                    decoration: const InputDecoration(
                      labelText: 'Meal Time', 
                      hintText: 'Select delivery time',
                      prefixIcon: Icon(CupertinoIcons.clock),
                      suffixIcon: Icon(CupertinoIcons.chevron_down, size: 16),
                    ),
                    validator: (v) => _timeController.text.isEmpty ? 'Meal time is required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    
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

