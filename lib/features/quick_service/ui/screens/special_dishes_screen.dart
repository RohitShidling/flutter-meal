import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';
import 'package:meal_app/features/quick_service/ui/widgets/quick_service_checkout.dart';

class SpecialDishesScreen extends StatefulWidget {
  const SpecialDishesScreen({super.key});

  @override
  State<SpecialDishesScreen> createState() => _SpecialDishesScreenState();
}

class _SpecialDishesScreenState extends State<SpecialDishesScreen> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<QuickServiceProvider>();
      await p.loadCategories();
      await p.loadCartFromServer();
      await context.read<BulkOrderProvider>().loadSavedDeliveryAddress();
      final backendAddr = await p.loadSavedDeliveryAddress();
      final bulk = context.read<BulkOrderProvider>();
      final addr = backendAddr ?? bulk.deliveryAddress;
      if (addr != null) {
        bulk.setDeliveryAddress(addr);
        p.setAddress(addr);
      }
      if (p.categories.isNotEmpty) {
        final id = p.categories.first['id']?.toString();
        if (id != null) {
          setState(() => _selectedCategoryId = id);
          await p.loadItems(id);
        }
      }
    });
  }

  Future<void> _checkout() async {
    await QuickServiceCheckout.paySpecialDishes(context, skipAddressPrompt: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<QuickServiceProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? AppTheme.backgroundDark : Colors.white;

    return Scaffold(
      backgroundColor: pageBg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Buuttii Specials'),
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (p.cartItemCount > 0)
            TextButton(
              onPressed: p.isLoading ? null : _checkout,
              child: Text('Pay (${p.cartItemCount})'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: p.isLoading && p.categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (p.categories.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: p.categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = p.categories[i];
                        final id = cat['id']?.toString() ?? '';
                        final selected = id == _selectedCategoryId;
                        return ChoiceChip(
                          label: Text(cat['name']?.toString() ?? 'Category'),
                          selected: selected,
                          onSelected: (_) async {
                            setState(() => _selectedCategoryId = id);
                            await p.loadItems(id);
                          },
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: p.items.length,
                    itemBuilder: (_, i) {
                      final item = p.items[i];
                      final id = item['id']?.toString() ?? '';
                      final qty = p.cartQty[id] ?? 0;
                      final price = double.tryParse(item['price']?.toString() ?? '') ?? 0.0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: item['image_url']?.toString() ?? '',
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 72,
                                    height: 72,
                                    color: Colors.grey.shade200,
                                    child: const Icon(CupertinoIcons.photo),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name']?.toString() ?? 'Item',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    Text('₹${price.toStringAsFixed(0)}'),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: qty > 0 ? () => p.setCartQty(id, qty - 1) : null,
                                          icon: const Icon(CupertinoIcons.minus_circle),
                                        ),
                                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
                                        IconButton(
                                          onPressed: () => p.setCartQty(id, qty + 1),
                                          icon: const Icon(CupertinoIcons.plus_circle),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (p.cartItemCount > 0)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BulkOrderAddressSection(),
                        Builder(
                          builder: (ctx) {
                            final addr = ctx.watch<BulkOrderProvider>().deliveryAddress;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) ctx.read<QuickServiceProvider>().setAddress(addr);
                            });
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: p.isLoading ? null : _checkout,
                            child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ),
    );
  }
}
