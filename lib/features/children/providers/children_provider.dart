import 'package:flutter/material.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/services/offline_queue.dart';
import 'package:meal_app/features/children/data/models/child_model.dart';
import 'package:meal_app/features/children/data/repositories/children_repository.dart';

class ChildrenProvider with ChangeNotifier {
  final ChildrenRepository _repository;

  ChildrenProvider(this._repository);

  List<ChildModel> _children = [];
  bool _isLoading = false;
  /// Stores the raw error object (DioException or String) so ErrorHandler
  /// can extract the proper server message.
  dynamic _error;

  List<ChildModel> get children => _children;
  bool get isLoading => _isLoading;
  dynamic get error => _error;

  Future<void> fetchChildren() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _children = await _repository.getChildren();
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addChild(ChildModel child) async {
    if (!NetworkStatusService.instance.isOnline) {
      // Queue write for later replay.
      await OfflineQueue.enqueue(
        method: 'POST',
        path: ApiEndpoints.children,
        data: {
          'children': [child.toJson()],
        },
      );

      // Optimistic local update (temporary id until synced).
      final optimistic = ChildModel(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        name: child.name,
        rollNumber: child.rollNumber,
        schoolId: child.schoolId,
        standardId: child.standardId,
        mealSizeId: child.mealSizeId,
        mealTime: child.mealTime,
      );
      _children = [..._children, optimistic];
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.registerChildren([child]);
      if (success) {
        await fetchChildren();
        return true;
      }
      return false;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateChild(String id, ChildModel child) async {
    if (!NetworkStatusService.instance.isOnline) {
      await OfflineQueue.enqueue(
        method: 'PUT',
        path: ApiEndpoints.child(id),
        data: child.toJson(),
      );

      _children = _children
          .map((c) => c.id == id
              ? ChildModel(
                  id: id,
                  name: child.name,
                  rollNumber: child.rollNumber,
                  schoolId: child.schoolId,
                  standardId: child.standardId,
                  mealSizeId: child.mealSizeId,
                  mealTime: child.mealTime,
                  schoolName: c.schoolName,
                  standardName: c.standardName,
                  mealSizeName: c.mealSizeName,
                )
              : c)
          .toList();
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.updateChild(id, child);
      if (success) {
        await fetchChildren();
        return true;
      }
      return false;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteChild(String id) async {
    if (!NetworkStatusService.instance.isOnline) {
      await OfflineQueue.enqueue(
        method: 'DELETE',
        path: ApiEndpoints.child(id),
      );
      _children = _children.where((c) => c.id != id).toList();
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _repository.deleteChild(id);
      if (success) {
        await fetchChildren();
        return true;
      }
      return false;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
