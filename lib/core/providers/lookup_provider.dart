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
  List<Map<String, dynamic>> _subscriptions = [];
  List<StateModel> _states = [];
  List<CityModel> _cities = [];
  List<CompanyModel> _companies = [];

  bool _isLoading = false;
  DateTime? _lastFetchedAt;
  Future<void>? _inflightInitialRequest;

  List<SchoolModel> get schools => _schools;
  List<StandardModel> get standards => _standards;
  List<MealSizeModel> get mealSizes => _mealSizes;
  List<CorporateLocationModel> get corporateLocations => _corporateLocations;
  List<Map<String, dynamic>> get subscriptions => _subscriptions;
  List<StateModel> get states => _states;
  List<CityModel> get cities => _cities;
  List<CompanyModel> get companies => _companies;
  bool get isLoading => _isLoading;

  Future<void> fetchInitialData({bool force = false}) async {
    final isFresh = _lastFetchedAt != null && DateTime.now().difference(_lastFetchedAt!).inMinutes < 10;
    if (!force && _schools.isNotEmpty && _standards.isNotEmpty && isFresh) return;
    if (_inflightInitialRequest != null) return _inflightInitialRequest;
    if (_isLoading) return;

    final request = _doFetchInitialData();
    _inflightInitialRequest = request;
    try {
      await request;
    } finally {
      _inflightInitialRequest = null;
    }
  }

  Future<void> _doFetchInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getSchools(),
        _repository.getStandards(),
        _repository.getMealSizes(),
        _repository.getCorporateLocations(),
        _repository.getSubscriptions(),
        _repository.getStates(),
      ]);

      _schools = results[0] as List<SchoolModel>;
      _standards = results[1] as List<StandardModel>;
      _mealSizes = results[2] as List<MealSizeModel>;
      _corporateLocations = results[3] as List<CorporateLocationModel>;
      _subscriptions = results[4] as List<Map<String, dynamic>>;
      _states = results[5] as List<StateModel>;
      _cities = [];
      _companies = [];
      _lastFetchedAt = DateTime.now();
    } catch (e) {
      // keep old cached data for offline fallback
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCitiesByState(int stateId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _cities = await _repository.getCities(stateId: stateId);
      _companies = []; // Reset companies when state/city changes
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCompaniesByCity(int cityId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _companies = await _repository.getCompanies(cityId: cityId);
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

  Future<void> fetchCorporateLocations() async {
    try {
      _corporateLocations = await _repository.getCorporateLocations();
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }
}
