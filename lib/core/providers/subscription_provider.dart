import 'package:flutter/material.dart';
import 'package:meal_app/core/models/subscription_model.dart';
import 'package:meal_app/core/network/subscription_repository.dart';
import 'package:meal_app/core/storage/cache_store.dart';

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionRepository _repository;

  SubscriptionProvider(this._repository) {
    _loadFromCache();
  }

  List<SubscriptionModel> _subscriptions = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchedAt;
  Future<void>? _inflightFetch;

  List<SubscriptionModel> get subscriptions => _subscriptions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _loadFromCache() async {
    try {
      final cached = await CacheStore.getJsonList('subscriptions_list');
      if (cached.isNotEmpty) {
        _subscriptions = cached.map(SubscriptionModel.fromJson).toList();
        notifyListeners();
      }
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> fetchSubscriptions({bool force = false, bool silent = false}) async {
    final isFresh = _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!).inMinutes < 10;
    if (!force && _subscriptions.isNotEmpty && isFresh) return;
    if (_inflightFetch != null) return _inflightFetch;

    final request = _doFetch(silent: silent);
    _inflightFetch = request;
    try {
      await request;
    } finally {
      _inflightFetch = null;
    }
  }

  Future<void> _doFetch({bool silent = false}) async {
    if (!silent) {
      if (_subscriptions.isEmpty) _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _subscriptions = await _repository.getSubscriptions();
      await CacheStore.setJson(
        'subscriptions_list',
        _subscriptions.map((e) => e.toJson()).toList(),
        ttl: const Duration(hours: 12),
      );
      _lastFetchedAt = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
