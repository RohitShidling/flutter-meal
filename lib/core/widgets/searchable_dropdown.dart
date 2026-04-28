import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final List<T> items;
  final String Function(T) itemLabel;
  final T? value;
  final Function(T?) onChanged;
  final String hint;
  final bool isLoading;
  final Function(String)? onSearch;
  final VoidCallback? onInteraction;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.itemLabel,
    this.value,
    required this.onChanged,
    this.hint = 'Select an option',
    this.isLoading = false,
    this.onSearch,
    this.onInteraction,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: widget.isLoading ? null : () {
            if (widget.onInteraction != null) widget.onInteraction!();
            _showSearchDialog(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.value != null ? widget.itemLabel(widget.value as T) : widget.hint,
                    style: TextStyle(
                      color: widget.value != null 
                        ? (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight)
                        : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                      fontSize: 16,
                    ),
                  ),
                ),
                if (widget.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.keyboard_arrow_down_rounded, 
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSearchDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SearchDialog<T>(
          items: widget.items,
          itemLabel: widget.itemLabel,
          onSelected: (value) {
            widget.onChanged(value);
            Navigator.pop(context);
          },
          onSearch: widget.onSearch,
        );
      },
    );
  }
}

class _SearchDialog<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) itemLabel;
  final Function(T) onSelected;
  final Function(String)? onSearch;

  const _SearchDialog({
    required this.items,
    required this.itemLabel,
    required this.onSelected,
    this.onSearch,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  late List<T> filteredItems;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredItems = widget.items;
  }

  void _filterItems(String query) {
    setState(() {
      filteredItems = widget.items
          .where((item) =>
              widget.itemLabel(item).toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: _filterItems,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor: isDark ? AppTheme.surfaceDark : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return ListTile(
                  title: Text(widget.itemLabel(item)),
                  onTap: () => widget.onSelected(item),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

