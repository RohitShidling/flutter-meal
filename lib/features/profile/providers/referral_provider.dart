import 'package:flutter/material.dart';
import 'package:meal_app/core/models/referral_model.dart';
import 'package:meal_app/core/network/referral_repository.dart';

class ReferralProvider with ChangeNotifier {
  final ReferralRepository _repository;

  ReferralProvider(this._repository);

  List<ReferralRewardModel> _rewards = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ReferralRewardModel> get rewards => _rewards;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchRewards() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rewards = await _repository.getReferralRewards();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> applyCode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.applyReferralCode(code);
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> allocateMeals({
    required int rewardId,
    required String entityType,
    required String entityId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.allocateReferralMeals(
        rewardId: rewardId,
        entityType: entityType,
        entityId: entityId,
      );
      if (success) {
        await fetchRewards();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
