import 'package:flutter/material.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/network/subscription_repository.dart';

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionRepository _repository;

  SubscriptionProvider(this._repository);

  List<SubscriptionModel> _subscriptions = [];
  bool _isLoading = false;
  String? _error;

  List<SubscriptionModel> get subscriptions => _subscriptions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchSubscriptions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _subscriptions = await _repository.getSubscriptions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
