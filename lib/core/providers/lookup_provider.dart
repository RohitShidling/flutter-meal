import 'package:flutter/material.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/network/lookup_repository.dart';

class LookupProvider with ChangeNotifier {
  final LookupRepository _repository;

  LookupProvider(this._repository);

  List<SchoolModel> _schools = [];
  List<StandardModel> _standards = [];
  List<MealSizeModel> _mealSizes = [];
  List<CorporateLocationModel> _corporateLocations = [];

  bool _isLoading = false;

  List<SchoolModel> get schools => _schools;
  List<StandardModel> get standards => _standards;
  List<MealSizeModel> get mealSizes => _mealSizes;
  List<CorporateLocationModel> get corporateLocations => _corporateLocations;
  bool get isLoading => _isLoading;

  Future<void> fetchInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getSchools(),
        _repository.getStandards(),
        _repository.getMealSizes(),
        _repository.getCorporateLocations(),
      ]);

      _schools = results[0] as List<SchoolModel>;
      _standards = results[1] as List<StandardModel>;
      _mealSizes = results[2] as List<MealSizeModel>;
      _corporateLocations = results[3] as List<CorporateLocationModel>;
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchSchools(String query) async {
    try {
      _schools = await _repository.getSchools(search: query);
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }
}
