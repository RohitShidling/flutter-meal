import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Industrial-grade reactive SearchableDropdown.
///
/// Pass [listenable], [itemsGetter], and [loadingGetter] so the
/// open bottom sheet auto-rebuilds when the provider notifies
/// (spinner shows while loading, list appears instantly when ready).
class SearchableDropdown<T> extends FormField<T> {
  final String label;
  final List<T> items;
  final String Function(T) itemLabel;
  final String hint;
  final bool isLoading;
  final VoidCallback? onInteraction;
  final Listenable? listenable;
  final List<T> Function()? itemsGetter;
  final bool Function()? loadingGetter;

  SearchableDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.itemLabel,
    T? value,
    required FormFieldSetter<T> onChanged,
    FormFieldValidator<T>? validator,
    this.hint = 'Select an option',
    this.isLoading = false,
    this.onInteraction,
    this.listenable,
    this.itemsGetter,
    this.loadingGetter,
  }) : super(
          initialValue: value,
          onSaved: onChanged,
          validator: validator,
          builder: (FormFieldState<T> state) {
            final isDark =
                Theme.of(state.context).brightness == Brightness.dark;
            final hasError = state.hasError;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    FocusScope.of(state.context).unfocus();
                    if (onInteraction != null) onInteraction!();
                    // Use static method — safe to call from builder
                    _openSheet<T>(
                      context: state.context,
                      state: state,
                      staticItems: items,
                      itemLabel: itemLabel,
                      staticIsLoading: isLoading,
                      listenable: listenable,
                      itemsGetter: itemsGetter,
                      loadingGetter: loadingGetter,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasError
                            ? Colors.red
                            : (isDark ? Colors.white10 : Colors.black12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.value != null
                                ? itemLabel(state.value as T)
                                : hint,
                            style: TextStyle(
                              color: state.value != null
                                  ? (isDark
                                      ? AppTheme.textPrimaryDark
                                      : AppTheme.textPrimaryLight)
                                  : (isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CupertinoActivityIndicator(radius: 8),
                          )
                        else
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                      ],
                    ),
                  ),
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 12),
                    child: Text(
                      state.errorText!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        );

  /// Static so it can be safely called inside the FormField builder.
  static void _openSheet<T>({
    required BuildContext context,
    required FormFieldState<T> state,
    required List<T> staticItems,
    required String Function(T) itemLabel,
    required bool staticIsLoading,
    Listenable? listenable,
    List<T> Function()? itemsGetter,
    bool Function()? loadingGetter,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ReactiveSearchSheet<T>(
          staticItems: staticItems,
          itemLabel: itemLabel,
          staticIsLoading: staticIsLoading,
          listenable: listenable,
          itemsGetter: itemsGetter,
          loadingGetter: loadingGetter,
          onSelected: (value) {
            state.didChange(value);
            state.save();
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }
}

/// Bottom sheet that listens to a [Listenable] and rebuilds reactively.
class _ReactiveSearchSheet<T> extends StatefulWidget {
  final List<T> staticItems;
  final String Function(T) itemLabel;
  final bool staticIsLoading;
  final ValueChanged<T> onSelected;
  final Listenable? listenable;
  final List<T> Function()? itemsGetter;
  final bool Function()? loadingGetter;

  const _ReactiveSearchSheet({
    required this.staticItems,
    required this.itemLabel,
    required this.staticIsLoading,
    required this.onSelected,
    this.listenable,
    this.itemsGetter,
    this.loadingGetter,
  });

  @override
  State<_ReactiveSearchSheet<T>> createState() =>
      _ReactiveSearchSheetState<T>();
}

class _ReactiveSearchSheetState<T>
    extends State<_ReactiveSearchSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<T> get _currentItems =>
      widget.itemsGetter != null
          ? widget.itemsGetter!()
          : widget.staticItems;

  bool get _currentLoading =>
      widget.loadingGetter != null
          ? widget.loadingGetter!()
          : widget.staticIsLoading;

  List<T> get _filteredItems {
    if (_query.isEmpty) return _currentItems;
    return _currentItems
        .where((item) => widget
            .itemLabel(item)
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    widget.listenable?.addListener(_onDataChange);
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_onDataChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loading = _currentLoading;
    final items = _filteredItems;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (q) => setState(() => _query = q),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor:
                    isDark ? AppTheme.surfaceDark : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Content — spinner, empty state, or list
          Expanded(
            child: loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoActivityIndicator(radius: 14),
                        SizedBox(height: 16),
                        Text(
                          'Loading data...',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Please wait',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48,
                                color: Colors.grey.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            const Text(
                              'No items found',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            title: Text(
                              widget.itemLabel(item),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                            ),
                            trailing: const Icon(
                                CupertinoIcons.chevron_right,
                                size: 14,
                                color: Colors.grey),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              widget.onSelected(item);
                            },
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 4),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
