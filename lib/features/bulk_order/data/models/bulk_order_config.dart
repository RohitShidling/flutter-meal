class BulkOrderConfig {
  final int minQuantity;
  final int standardMaxQuantity;
  final int minLeadDays;
  final int tierThreshold;
  final double pricePerMealUnderThreshold;
  final int varietyMenuLookaheadDays;
  final int maxVarietyTypes;
  final bool allowMultipleVarietyMeals;
  final int minQuantityPerVarietyMeal;
  final bool isActive;
  final String earliestDeliveryDate;
  final List<BulkVarietyPrice> varietyPrices;
  final String? hubIntroText;
  final String? standardTierTitle;
  final String? standardTierSubtitle;
  final String? standardTierDescription;
  final String? varietyTierTitle;
  final String? varietyTierSubtitle;
  final String? varietyTierDescription;

  BulkOrderConfig({
    required this.minQuantity,
    required this.standardMaxQuantity,
    required this.minLeadDays,
    required this.tierThreshold,
    required this.pricePerMealUnderThreshold,
    required this.varietyMenuLookaheadDays,
    required this.maxVarietyTypes,
    required this.allowMultipleVarietyMeals,
    required this.minQuantityPerVarietyMeal,
    required this.isActive,
    required this.earliestDeliveryDate,
    required this.varietyPrices,
    this.hubIntroText,
    this.standardTierTitle,
    this.standardTierSubtitle,
    this.standardTierDescription,
    this.varietyTierTitle,
    this.varietyTierSubtitle,
    this.varietyTierDescription,
  });

  factory BulkOrderConfig.fromJson(Map<String, dynamic> json) {
    final prices = json['variety_prices'];
    final minQ = int.tryParse('${json['min_quantity'] ?? 10}') ?? 10;
    final tier = int.tryParse('${json['tier_threshold'] ?? 50}') ?? 50;
    return BulkOrderConfig(
      minQuantity: minQ,
      standardMaxQuantity: int.tryParse('${json['standard_max_quantity'] ?? (tier - 1)}') ?? (tier - 1),
      minLeadDays: int.tryParse('${json['min_lead_days'] ?? 3}') ?? 3,
      tierThreshold: tier,
      pricePerMealUnderThreshold:
          double.tryParse('${json['price_per_meal_under_threshold'] ?? 0}') ?? 0,
      varietyMenuLookaheadDays:
          int.tryParse('${json['variety_menu_lookahead_days'] ?? 14}') ?? 14,
      maxVarietyTypes: int.tryParse('${json['max_variety_types'] ?? 5}') ?? 5,
      allowMultipleVarietyMeals: json['allow_multiple_variety_meals'] != false,
      minQuantityPerVarietyMeal:
          int.tryParse('${json['min_quantity_per_variety_meal'] ?? 1}') ?? 1,
      isActive: json['is_active'] != false,
      earliestDeliveryDate: '${json['earliest_delivery_date'] ?? ''}',
      hubIntroText: json['hub_intro_text'] as String?,
      standardTierTitle: json['standard_tier_title'] as String?,
      standardTierSubtitle: json['standard_tier_subtitle'] as String?,
      standardTierDescription: json['standard_tier_description'] as String?,
      varietyTierTitle: json['variety_tier_title'] as String?,
      varietyTierSubtitle: json['variety_tier_subtitle'] as String?,
      varietyTierDescription: json['variety_tier_description'] as String?,
      varietyPrices: prices is List
          ? prices
              .map((e) => BulkVarietyPrice.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : [],
    );
  }
}

class BulkVarietyPrice {
  final int slotNumber;
  final double pricePerMeal;

  BulkVarietyPrice({required this.slotNumber, required this.pricePerMeal});

  factory BulkVarietyPrice.fromJson(Map<String, dynamic> json) {
    return BulkVarietyPrice(
      slotNumber: int.tryParse('${json['slot_number'] ?? 0}') ?? 0,
      pricePerMeal: double.tryParse('${json['price_per_meal'] ?? 0}') ?? 0,
    );
  }
}

class BulkMenuOption {
  final String id;
  final String menuDate;
  final String items;
  final String? imageUrl;
  final double? pricePerMeal;
  final int minOrderQuantity;

  BulkMenuOption({
    required this.id,
    required this.menuDate,
    required this.items,
    this.imageUrl,
    this.pricePerMeal,
    this.minOrderQuantity = 1,
  });

  factory BulkMenuOption.fromJson(Map<String, dynamic> json) {
    final price = json['price_per_meal'];
    return BulkMenuOption(
      id: '${json['id']}',
      menuDate: '${json['menu_date'] ?? ''}',
      items: '${json['name'] ?? json['items'] ?? ''}',
      imageUrl: json['image_url'] as String?,
      pricePerMeal: price == null ? null : double.tryParse('$price'),
      minOrderQuantity:
          int.tryParse('${json['min_order_quantity'] ?? 1}') ?? 1,
    );
  }
}
