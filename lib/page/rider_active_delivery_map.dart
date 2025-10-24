import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show ValueListenable, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/jobs.dart';
import 'package:flutter_application_4/page/rider_capture_photo.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/utils/delivery_status.dart';
import 'package:flutter_application_4/utils/location_utils.dart';
import 'package:flutter_application_4/utils/supabase_storage.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// RTDB + Auth
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class RiderActiveDeliveryMapPage extends StatefulWidget {
  const RiderActiveDeliveryMapPage({
    super.key,
    required this.userId,
    required this.deliveryId,
  });

  final String userId;
  final String deliveryId;

  @override
  State<RiderActiveDeliveryMapPage> createState() =>
      _RiderActiveDeliveryMapPageState();
}

class _RiderActiveDeliveryMapPageState
    extends State<RiderActiveDeliveryMapPage> {
  static const _brandRed = Color(0xFFE96356);

  // ระยะ trigger
  static const double kArriveRadiusMeters = 20.0;
  static const int kAutoCooldownSec = 8;
  bool _wasNearPickup = false;
  bool _wasNearDrop = false;
  DateTime? _lastAutoAt;
  bool _canAutoNow() =>
      _lastAutoAt == null ||
      DateTime.now().difference(_lastAutoAt!).inSeconds >= kAutoCooldownSec;

  final _firestore = FirebaseFirestore.instance;
  final _mapController = MapController();
  final _lookup = DeliveryLookupCache();

  // Map lifecycle
  bool _mapReady = false;
  bool _centered = false;
  LatLng? _pendingCenter;

  // Auth + RTDB
  final _auth = FirebaseAuth.instance;
  String? _uid;
  late final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://delivery-test-61f4a-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // Location
  StreamSubscription<Position>? _positionSub;
  Position? _currentPosition;

  // rebuild เฉพาะชั้น marker
  final ValueNotifier<LatLng?> _myPosVN = ValueNotifier<LatLng?>(null);
  final ValueNotifier<LatLng?> _targetVN = ValueNotifier<LatLng?>(null);
  final ValueNotifier<double> _headingVN = ValueNotifier<double>(0);

  LatLng? _prevPosForHeading;

  bool _processing = false;
  Map<String, dynamic>? _latestData;
  AddressSummary? _senderAddress;
  AddressSummary? _receiverAddress;

  // assignment
  bool _assignmentReady = false;
  bool _hasMyAssignment = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _assignSub;
  int? _deliveryIdInt;
  String? _assignmentDocId;

  // cache ว่ามี "รูปรับ" แล้วหรือยัง
  bool? _hasPickupProofCached;

  // ไอคอนรถหันเหนืออยู่แล้ว => 0
  static const double _iconFacingOffsetDeg = 0;

  @override
  void initState() {
    super.initState();
    _startAssignmentListener();
    _initAuthThenStart();
  }

  @override
  void dispose() {
    _assignSub?.cancel();
    _positionSub?.cancel();
    _myPosVN.dispose();
    _targetVN.dispose();
    _headingVN.dispose();
    super.dispose();
  }

  // ===== assignment =====
  void _startAssignmentListener() {
    final id = int.tryParse(widget.deliveryId);
    if (id == null) return;
    _deliveryIdInt = id;

    _assignSub = _firestore
        .collection('delivery_assignment')
        .where('deliveryid', isEqualTo: id)
        .where('riderid', isEqualTo: widget.userId)
        .limit(1)
        .snapshots()
        .listen((qs) {
          _assignmentReady = true;
          _hasMyAssignment = qs.docs.isNotEmpty;
          if (qs.docs.isNotEmpty) _assignmentDocId = qs.docs.first.id;
          if (mounted) setState(() {});
        });
  }

  Future<String?> _getMyAssignmentDocId() async {
    if (_assignmentDocId != null) return _assignmentDocId;
    final did = _deliveryIdInt ?? int.tryParse(widget.deliveryId);
    if (did == null) return null;

    try {
      final qs = await _firestore
          .collection('delivery_assignment')
          .where('deliveryid', isEqualTo: did)
          .where('riderid', isEqualTo: widget.userId)
          .limit(1)
          .get();
      if (qs.docs.isEmpty) return null;
      _assignmentDocId = qs.docs.first.id;
      return _assignmentDocId;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        final qs = await _firestore
            .collection('delivery_assignment')
            .where('deliveryid', isEqualTo: did)
            .get();
        for (final d in qs.docs) {
          final r = d.data()['riderid']?.toString();
          if (r == widget.userId) {
            _assignmentDocId = d.id;
            return _assignmentDocId;
          }
        }
        return null;
      }
      rethrow;
    }
  }

  Future<bool> _hasPickupProof() async {
    if (_hasPickupProofCached != null) return _hasPickupProofCached!;
    final aId = await _getMyAssignmentDocId();
    if (aId == null) return false;
    final aSnap = await _firestore
        .collection('delivery_assignment')
        .doc(aId)
        .get();
    final v = (aSnap.data()?['picture_status3'] ?? '').toString();
    _hasPickupProofCached = v.isNotEmpty;
    return _hasPickupProofCached!;
  }

  Future<void> _updateAssignmentPicture({
    required String fieldName,
    required String pictureUrl,
  }) async {
    final aId = await _getMyAssignmentDocId();
    if (aId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ไม่พบใบมอบหมายของงานนี้')));
      return;
    }
    await _firestore.collection('delivery_assignment').doc(aId).update({
      fieldName: pictureUrl,
    });
    if (fieldName == 'picture_status3' && pictureUrl.isNotEmpty) {
      _hasPickupProofCached = true;
    }
  }

  Future<void> _setAssignmentAccepted(bool v) async {
    final aId = await _getMyAssignmentDocId();
    if (aId == null) return;
    await _firestore.collection('delivery_assignment').doc(aId).update({
      'accepted': v,
    });
  }

  Future<void> _syncAcceptedFlagForStatus(String status) async {
    if (!_assignmentReady || !_hasMyAssignment) return;
    if (status == DeliveryStatus.riderAccepted ||
        status == DeliveryStatus.riderPickedUp) {
      await _setAssignmentAccepted(true);
    } else if (status == DeliveryStatus.delivered) {
      await _setAssignmentAccepted(false);
    }
  }

  // ===== Auth + live location (RTDB) =====
  Future<void> _initAuthThenStart() async {
    final current = _auth.currentUser;
    if (current == null) {
      final cred = await _auth.signInAnonymously();
      _uid = cred.user?.uid;
    } else {
      _uid = current.uid;
    }
    if (_uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เข้าสู่ระบบไม่สำเร็จ')));
      }
      return;
    }
    await _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    try {
      final position = await LocationUtils.ensureCurrentPosition();
      await _handlePosition(position);

      _positionSub = LocationUtils.livePositionStream(
        distanceFilter: 0,
        androidInterval: const Duration(milliseconds: 800),
      ).listen(_handlePosition);

      await _handlePosition(position);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // bearing 0..360 (0 = เหนือ)
  double _bearingDeg(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lon1 = from.longitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final lon2 = to.longitude * math.pi / 180.0;
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    var brng = math.atan2(y, x) * 180.0 / math.pi;
    brng = (brng + 360.0) % 360.0;
    return brng;
  }

  Future<void> _handlePosition(Position position) async {
    _currentPosition = position;

    final me = LatLng(position.latitude, position.longitude);
    _myPosVN.value = me;
    _pendingCenter = me;

    // heading
    double? newHeading;
    if (position.heading != null && position.heading >= 0) {
      newHeading = position.heading;
    } else if (_prevPosForHeading != null) {
      final moved =
          Geolocator.distanceBetween(
            _prevPosForHeading!.latitude,
            _prevPosForHeading!.longitude,
            me.latitude,
            me.longitude,
          ) >
          1.5;
      if (moved) newHeading = _bearingDeg(_prevPosForHeading!, me);
    }
    _prevPosForHeading = me;
    if (newHeading != null) _headingVN.value = newHeading;

    if (_mapReady && !_centered && _pendingCenter != null) {
      _mapController.move(_pendingCenter!, 16);
      _centered = true;
    }

    final uid = _uid;
    if (uid == null) return;

    // rider_location/<uid>
    final riderLocRef = _rtdb.ref('rider_location/$uid');
    try {
      try {
        if (Platform.isAndroid || Platform.isIOS) riderLocRef.keepSynced(true);
      } catch (_) {}
      await riderLocRef.set({
        'riderid': uid,
        'lat': position.latitude,
        'lng': position.longitude,
        'updatedAt': ServerValue.timestamp,
      });
      try {
        riderLocRef.onDisconnect().remove();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกตำแหน่งขึ้น Realtime DB ไม่ได้: $e')),
      );
    }

    // mirror เข้า delivery_status/<deliveryId>
    try {
      final statusRef = _rtdb.ref('delivery_status/${widget.deliveryId}');
      await statusRef.update({
        'riderid': widget.userId,
        'rider_uid': uid,
        'lat': position.latitude,
        'lng': position.longitude,
        'posTs': ServerValue.timestamp,
      });
    } catch (_) {}

    await _maybeAutoProgress();
  }

  Future<void> _ensureAddresses(Map<String, dynamic> data) async {
    final senderId = data['addressid_sender']?.toString();
    final receiverId = data['addressid_receiver']?.toString();

    if (senderId != null && senderId.isNotEmpty) {
      if (_senderAddress?.id != senderId) {
        final result = await _lookup.getAddress(senderId);
        if (mounted) setState(() => _senderAddress = result);
      }
    }
    if (receiverId != null && receiverId.isNotEmpty) {
      if (_receiverAddress?.id != receiverId) {
        final result = await _lookup.getAddress(receiverId);
        if (mounted) setState(() => _receiverAddress = result);
      }
    }
  }

  // ===== main flow: 20m -> ถ่ายรูป -> อัปเดตสถานะ =====
  Future<void> _maybeAutoProgress() async {
    if (_processing) return;
    if (_latestData == null || _currentPosition == null) return;
    if (!_assignmentReady || !_hasMyAssignment) return;

    final data = _latestData!;
    final status = DeliveryStatus.normalize(data['status']?.toString());

    await _ensureAddresses(data);

    // ---- เฟสรับของ (หลัง "รับงาน" แต่ยังไม่ถ่ายรูปรับ) ----
    // เงื่อนไข: status == riderAccepted  (ไรเดอร์รับงาน)
    if (status == DeliveryStatus.riderAccepted) {
      final s = _senderAddress;
      if (s?.lat == null || s?.lng == null) return;

      final nearPickup = LocationUtils.isWithinDistance(
        position: _currentPosition!,
        targetLat: s!.lat,
        targetLng: s.lng,
        maxDistanceMeters: kArriveRadiusMeters,
      );

      if (nearPickup && !_wasNearPickup && _canAutoNow()) {
        _wasNearPickup = true;
        _lastAutoAt = DateTime.now();

        _processing = true;
        try {
          // เปิดหน้า "ถ่ายรูปรับสินค้า"
          final file = await Navigator.of(context).push<File?>(
            MaterialPageRoute(
              builder: (_) => const RiderCapturePhotoPage(
                title: 'ถ่ายภาพหลักฐาน',
                subtitle: 'รูปรับสินค้า',
              ),
            ),
          );

          if (file != null) {
            final url = await uploadImageToSupabase(
              file: file,
              path:
                  'deliveries/${widget.deliveryId}/picked_up_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            if (url != null && url.isNotEmpty) {
              await _updateAssignmentPicture(
                fieldName: 'picture_status3',
                pictureUrl: url,
              );

              // เปลี่ยนสถานะเป็น "รับสินค้าแล้วและกำลังไปส่ง"
              final dRef = _firestore
                  .collection('delivery')
                  .doc(widget.deliveryId);
              await dRef.update({'status': DeliveryStatus.riderPickedUp});
              await _rtdb.ref('delivery_status/${widget.deliveryId}').set({
                'status': DeliveryStatus.riderPickedUp,
                'riderid': widget.userId,
                'ts': ServerValue.timestamp,
              });

              await _setAssignmentAccepted(true);
            }
          }
        } finally {
          _processing = false;
        }
      }
      if (!nearPickup) _wasNearPickup = false;
      return;
    }

    // ---- เฟสส่งของ (มีรูปรับแล้ว) ----
    if (status == DeliveryStatus.riderPickedUp) {
      final r = _receiverAddress;
      if (r?.lat == null || r?.lng == null) return;

      final nearDrop = LocationUtils.isWithinDistance(
        position: _currentPosition!,
        targetLat: r!.lat,
        targetLng: r.lng,
        maxDistanceMeters: kArriveRadiusMeters,
      );

      if (nearDrop && !_wasNearDrop && _canAutoNow()) {
        _wasNearDrop = true;
        _lastAutoAt = DateTime.now();

        _processing = true;
        try {
          // เปิดหน้า "ถ่ายรูปส่งสินค้า"
          final file = await Navigator.of(context).push<File?>(
            MaterialPageRoute(
              builder: (_) => const RiderCapturePhotoPage(
                title: 'ถ่ายภาพหลักฐาน',
                subtitle: 'รูปส่งสินค้า',
              ),
            ),
          );

          if (file != null) {
            final url = await uploadImageToSupabase(
              file: file,
              path:
                  'deliveries/${widget.deliveryId}/delivered_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );

            if (url != null && url.isNotEmpty) {
              await _updateAssignmentPicture(
                fieldName: 'picture_status4',
                pictureUrl: url,
              );

              // ปิดงานเป็น delivered
              final dRef = _firestore
                  .collection('delivery')
                  .doc(widget.deliveryId);
              await dRef.update({'status': DeliveryStatus.delivered});
              await _rtdb.ref('delivery_status/${widget.deliveryId}').set({
                'status': DeliveryStatus.delivered,
                'riderid': widget.userId,
                'ts': ServerValue.timestamp,
              });

              await _setAssignmentAccepted(false);

              final uid = _uid;
              if (uid != null) {
                try {
                  await _rtdb.ref('rider_location/$uid').remove();
                } catch (_) {}
              }

              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('จัดส่งสำเร็จ ✅')));
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => JobsPage(userId: widget.userId),
                  ),
                  (r) => false,
                );
              }
            }
          }
        } finally {
          _processing = false;
        }
      }
      if (!nearDrop) _wasNearDrop = false;
    }
  }

  // ===== UI helpers =====
  String _headerTitle(String status) {
    // ก่อนถ่ายรูปรับ => "ไปรับสินค้า", หลังถ่ายรูปรับ => "ไปส่งสินค้า"
    if (status == DeliveryStatus.riderPickedUp) return 'ไปส่งสินค้า';
    return 'ไปรับสินค้า';
  }

  LatLng? _computeTarget(String status) {
    if (status == DeliveryStatus.riderPickedUp) {
      final r = _receiverAddress;
      if (r?.lat != null && r?.lng != null) return LatLng(r!.lat!, r.lng!);
    } else {
      final s = _senderAddress;
      if (s?.lat != null && s?.lng != null) return LatLng(s!.lat!, s.lng!);
    }
    return null;
  }

  Future<void> _centerToTarget(String status) async {
    if (!_mapReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('แผนที่กำลังโหลด…')));
    } else {
      final t = _targetVN.value ?? _computeTarget(status);
      if (t == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ยังไม่มีพิกัดเป้าหมาย')));
      } else {
        _mapController.move(t, 17);
      }
    }
  }

  Future<void> _centerToMe() async {
    if (!_mapReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('แผนที่กำลังโหลด…')));
      return;
    }
    final me = _myPosVN.value;
    if (me == null) return;
    _mapController.move(me, 17);
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _myPosVN.value ?? const LatLng(13.7563, 100.5018);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('delivery')
              .doc(widget.deliveryId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('ไม่พบงานจัดส่งนี้แล้ว'));
            }

            final data = snapshot.data!.data() ?? {};
            final status = DeliveryStatus.normalize(data['status']?.toString());

            final changed = !mapEquals(_latestData, data);
            _latestData = data;
            if (changed) {
              _syncAcceptedFlagForStatus(status);
              _maybeAutoProgress();
            }

            // อัปเดต target
            final t = _computeTarget(status);
            final curr = _targetVN.value;
            if (t != null &&
                (curr == null ||
                    curr.latitude != t.latitude ||
                    curr.longitude != t.longitude)) {
              _targetVN.value = t;
            }

            if (!_assignmentReady) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!_hasMyAssignment) {
              // ออกจากหน้าถ้าไม่ใช่งานเราแล้ว
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => JobsPage(userId: widget.userId),
                    ),
                    (r) => false,
                  );
                }
              });
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                // Header
                SafeArea(
                  bottom: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _brandRed,
                      border: Border(
                        bottom: BorderSide(color: Colors.black, width: 2),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    alignment: Alignment.center,
                    child: _StrokeText(
                      _headerTitle(status),
                      fillColor: Colors.white,
                      strokeColor: Colors.black,
                      strokeWidth: 4,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                // Map
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: initialCenter,
                          initialZoom: 16,
                          maxZoom: 18,
                          onMapReady: () {
                            _mapReady = true;
                            if (_pendingCenter != null && !_centered) {
                              _mapController.move(_pendingCenter!, 16);
                              _centered = true;
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.flutter_application_4',
                          ),

                          // วงระยะ 20 ม.
                          ValueListenableBuilder<LatLng?>(
                            valueListenable: _myPosVN,
                            builder: (_, me, __) {
                              final circles = <CircleMarker>[];
                              if (me != null) {
                                circles.add(
                                  CircleMarker(
                                    point: me,
                                    radius: 20.0,
                                    useRadiusInMeter: true,
                                    color: _brandRed.withOpacity(0.22),
                                    borderColor: Colors.black,
                                    borderStrokeWidth: 2,
                                  ),
                                );
                              }
                              return CircleLayer(circles: circles);
                            },
                          ),

                          // ไอคอนรถ + เป้าหมาย (ฟัง heading ด้วย)
                          ValueListenableBuilder<LatLng?>(
                            valueListenable: _myPosVN,
                            builder: (_, me, __) {
                              return ValueListenableBuilder<LatLng?>(
                                valueListenable: _targetVN,
                                builder: (_, target, __) {
                                  return ValueListenableBuilder<double>(
                                    valueListenable: _headingVN,
                                    builder: (_, headingDeg, __) {
                                      final markers = <Marker>[];

                                      if (me != null) {
                                        final angleRad =
                                            (headingDeg +
                                                _iconFacingOffsetDeg) *
                                            math.pi /
                                            180.0; // <-- fix
                                        markers.add(
                                          Marker(
                                            point: me,
                                            width: 50,
                                            height: 50,
                                            alignment: Alignment.center,
                                            child: Transform.rotate(
                                              angle: angleRad,
                                              child: Image.asset(
                                                'assets/Icons/16.png',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      if (target != null) {
                                        markers.add(
                                          Marker(
                                            point: target,
                                            width: 50,
                                            height: 50,
                                            alignment: Alignment.bottomCenter,
                                            child: Transform.translate(
                                              offset: const Offset(0, -40),
                                              child: const Icon(
                                                Icons.location_on,
                                                color: Colors.black,
                                                size: 50,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      return MarkerLayer(
                                        rotate: false,
                                        markers: markers,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      // ปุ่มกลม 2 ปุ่ม
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Column(
                          children: [
                            _MapCircleButton(
                              icon: Icons.place,
                              onTap: () => _centerToTarget(status),
                            ),
                            const SizedBox(height: 12),
                            _MapCircleButton(
                              icon: Icons.my_location,
                              onTap: _centerToMe,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _RiderActiveDeliveryMapPageState._brandRed,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 3,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 28, color: Colors.black),
        ),
      ),
    );
  }
}

class _StrokeText extends StatelessWidget {
  const _StrokeText(
    this.text, {
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.style,
  });
  final String text;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        Text(text, style: style.copyWith(color: fillColor)),
      ],
    );
  }
}
