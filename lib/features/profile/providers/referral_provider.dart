import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meal_app/core/models/referral_model.dart';
import 'package:meal_app/core/network/referral_repository.dart';

class ReferralProvider with ChangeNotifier {
  final ReferralRepository _repository;

  ReferralProvider(this._repository);

  List<ReferralRewardModel> _rewards = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastSeenTime;

  List<ReferralRewardModel> get rewards => _rewards;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchRewards() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rewards = await _repository.getReferralRewards();
      if (_lastSeenTime == null) {
        final prefs = await SharedPreferences.getInstance();
        final timeStr = prefs.getString('referral_rewards_last_seen');
        if (timeStr != null) {
          _lastSeenTime = DateTime.tryParse(timeStr);
        }
      }
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

  bool get hasUnclaimedRewards {
    if (_lastSeenTime == null) {
      return _rewards.any((r) => r.mealsRemaining > 0);
    }
    return _rewards.any((r) => r.mealsRemaining > 0 && r.createdAt.isAfter(_lastSeenTime!));
  }

  Future<void> markRewardsAsSeen() async {
    _lastSeenTime = DateTime.now();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('referral_rewards_last_seen', _lastSeenTime!.toIso8601String());
    } catch (_) {}
  }

  Future<bool> allocateMeals({
    required int rewardId,
    required String entityType,
    required String entityId,
    int? mealsToClaim,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.allocateReferralMeals(
        rewardId: rewardId,
        entityType: entityType,
        entityId: entityId,
        mealsToClaim: mealsToClaim,
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

  Future<bool> allocateMultipleMeals({
    required String entityType,
    required String entityId,
    required int totalMealsToClaim,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      int remainingToClaim = totalMealsToClaim;
      final activeRewards = _rewards.where((r) => r.mealsRemaining > 0).toList();

      for (final reward in activeRewards) {
        if (remainingToClaim <= 0) break;
        final toClaimFromThisReward = reward.mealsRemaining < remainingToClaim
            ? reward.mealsRemaining
            : remainingToClaim;

        final success = await _repository.allocateReferralMeals(
          rewardId: reward.id,
          entityType: entityType,
          entityId: entityId,
          mealsToClaim: toClaimFromThisReward,
        );

        if (!success) {
          throw Exception('Failed to claim meals for reward ID ${reward.id}');
        }
        remainingToClaim -= toClaimFromThisReward;
      }

      await fetchRewards();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      await fetchRewards();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
