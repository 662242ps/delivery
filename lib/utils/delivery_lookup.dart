import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';

class DeliveryLookupCache {
  DeliveryLookupCache({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  final Map<String, Future<UserSummary?>> _userFutureCache = {};
  final Map<String, UserSummary?> _userCache = {};

  final Map<String, Future<AddressSummary?>> _addressFutureCache = {};
  final Map<String, AddressSummary?> _addressCache = {};

  Future<UserSummary?> getUser(String? id) {
    if (id == null || id.isEmpty) return Future.value(null);
    if (_userCache.containsKey(id)) return Future.value(_userCache[id]);
    return _userFutureCache.putIfAbsent(id, () async {
      final snap = await _firestore.collection('user').doc(id).get();
      if (!snap.exists) {
        _userCache[id] = null;
        return null;
      }
      final summary = UserSummary.fromSnapshot(snap);
      _userCache[id] = summary;
      return summary;
    });
  }

  Future<AddressSummary?> getAddress(String? id) {
    if (id == null || id.isEmpty) return Future.value(null);
    if (_addressCache.containsKey(id)) {
      return Future.value(_addressCache[id]);
    }
    return _addressFutureCache.putIfAbsent(id, () async {
      final snap = await _firestore.collection('user_address').doc(id).get();
      if (!snap.exists) {
        _addressCache[id] = null;
        return null;
      }
      final summary = AddressSummary.fromSnapshot(snap);
      _addressCache[id] = summary;
      return summary;
    });
  }

  void clear() {
    _userFutureCache.clear();
    _userCache.clear();
    _addressFutureCache.clear();
    _addressCache.clear();
  }
}
