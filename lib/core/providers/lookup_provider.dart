import 'package:flutter/material.dart';
import 'package:meal_app/core/models/lookup_models.dart';
import 'package:meal_app/core/network/lookup_repository.dart';
import 'package:meal_app/core/storage/cache_store.dart';

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

  LookupProvider(this._repository) {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final cached = await CacheStore.getJson('lookup_initial_data');
      if (cached is Map<String, dynamic>) {
        if (cached['schools'] is List) {
          _schools = (cached['schools'] as List).map((s) => SchoolModel.fromJson(s)).toList();
        }
        if (cached['standards'] is List) {
          _standards = (cached['standards'] as List).map((s) => StandardModel.fromJson(s)).toList();
        }
        if (cached['mealSizes'] is List) {
          _mealSizes = (cached['mealSizes'] as List).map((s) => MealSizeModel.fromJson(s)).toList();
        }
        if (cached['corporateLocations'] is List) {
          _corporateLocations = (cached['corporateLocations'] as List).map((l) => CorporateLocationModel.fromJson(l)).toList();
        }
        if (cached['states'] is List) {
          _states = (cached['states'] as List).map((s) => StateModel.fromJson(s)).toList();
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchInitialData({bool force = false}) async {
    final isFresh = _lastFetchedAt != null && DateTime.now().difference(_lastFetchedAt!).inMinutes < 60;
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

      await CacheStore.setJson('lookup_initial_data', {
        'schools': _schools.map((e) => e.toJson()).toList(),
        'standards': _standards.map((e) => e.toJson()).toList(),
        'mealSizes': _mealSizes.map((e) => e.toJson()).toList(),
        'corporateLocations': _corporateLocations.map((e) => e.toJson()).toList(),
        'states': _states.map((e) => e.toJson()).toList(),
      }, ttl: const Duration(days: 1));
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
