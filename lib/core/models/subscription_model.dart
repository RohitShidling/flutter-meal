class SubscriptionModel {
  final String id;
  final String planName;
  final String price;
  final String billingCycle;
  final int trialDays;
  final int displayOrder;
  final bool? isActive;

  SubscriptionModel({
    required this.id,
    required this.planName,
    required this.price,
    required this.billingCycle,
    required this.trialDays,
    required this.displayOrder,
    this.isActive,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'],
      planName: json['plan_name'],
      price: json['price'],
      billingCycle: json['billing_cycle'],
      trialDays: json['trial_days'],
      displayOrder: json['display_order'],
      isActive: json['is_active'],
    );
  }
}
