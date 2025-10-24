import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/widgets/user_footer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ใช้ RTDB โปรเจกต์เดียวกับฝั่งไรเดอร์
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

// ✅ ใช้เพื่อดึงพิกัด GPS ปัจจุบัน
import 'package:geolocator/geolocator.dart';

class UserDeliveryMapPage extends StatefulWidget {
  const UserDeliveryMapPage({super.key, required this.userId});
  final String userId;

  @override
  State<UserDeliveryMapPage> createState() => _UserDeliveryMapPageState();
}

class _UserDeliveryMapPageState extends State<UserDeliveryMapPage> {
  static const _brandRed = Color(0xFFE96356);
  static const _black = Colors.black;

  final _mapController = MapController();
  final _firestore = FirebaseFirestore.instance;
  final _lookup = DeliveryLookupCache();

  late final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://delivery-test-61f4a-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // แถบปุ่มด้านบน — เรา “ไม่ให้กด”
  final bool _showMyAddresses = true;
  final bool _showReceiverAddresses = true;
  final bool _showSenderRiders = true;
  final bool _showReceiverRiders = true;

  // กล้อง/แผนที่
  final _mapPadding = const EdgeInsets.all(60.0);

  // ✅ ฟิตกล้องไป "พิกัดฉัน" ครั้งเดียว (ใช้ center แทน bounds)
  bool _mapReady = false;
  bool _didFitToMe = false;
  LatLng? _pendingCenterForMe;

  // ✅ พิกัดฉัน (GPS)
  LatLng? _myGpsPoint;

  static const _iconSend = 'assets/Icons/16.png'; // แดง
  static const _iconRecv = 'assets/Icons/17.png'; // ดำ

  @override
  void initState() {
    super.initState();
    // เตรียมรูปให้โหลดไวขึ้น
    Future.microtask(() async {
      if (!mounted) return;
      await precacheImage(const AssetImage(_iconSend), context);
      await precacheImage(const AssetImage(_iconRecv), context);
    });

    // เริ่มดึงพิกัดฉันทันที
    _initMyLocation();
  }

  // ---------- ดึงพิกัดฉัน & ฟิตครั้งเดียว ----------
  Future<void> _initMyLocation() async {
    try {
      // last known (เร็ว) -> current (แม่น)
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        _myGpsPoint = LatLng(last.latitude, last.longitude);
        _fitToMeOnce(_myGpsPoint!);
        setState(() {});
      }

      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return; // ไม่มีสิทธิ์ → fallback ไปพิกัด address
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      _myGpsPoint = LatLng(pos.latitude, pos.longitude);
      _fitToMeOnce(_myGpsPoint!);
      setState(() {});
    } catch (_) {
      // เงียบ ๆ แล้ว fallback ไป myAddresses
    }
  }

  void _fitToMeOnce(LatLng p) {
    if (_didFitToMe) return;
    if (!_mapReady) {
      _pendingCenterForMe = p;
      return;
    }
    // ใช้ center + zoom ปลอดภัยแม้มีจุดเดียว
    _mapController.move(p, 16); // ปรับ 15–17 ตามต้องการ
    _didFitToMe = true;
  }

  // ---------- Utilities ----------
  Future<Map<String, AddressSummary>> _loadAddresses(
    Iterable<String> ids,
  ) async {
    final result = <String, AddressSummary>{};
    for (final id in ids) {
      final s = await _lookup.getAddress(id);
      if (s != null) result[id] = s;
    }
    return result;
  }

  List<List<T>> _chunk<T>(Iterable<T> src, int size) {
    final list = src.toList();
    final out = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      out.add(list.sublist(i, math.min(i + size, list.length)));
    }
    return out;
  }

  // ---------- Firestore: delivery_assignment (accepted only) ----------
  Stream<List<QuerySnapshot<Map<String, dynamic>>>> _assignmentStream(
    Set<String> deliveryIds,
  ) {
    if (deliveryIds.isEmpty) return const Stream.empty();
    final asInts = deliveryIds.map(int.tryParse).whereType<int>().toSet();

    final parts = _chunk(asInts, 10);
    final streams = parts.map(
      (c) => _firestore
          .collection('delivery_assignment')
          .where('deliveryid', whereIn: c)
          .where('accepted', isEqualTo: true)
          .snapshots(),
    );
    return StreamZip(streams.toList());
  }

  /// ฟังตำแหน่งไรเดอร์ตาม deliveryId ที่มี assignment
  /// จาก RTDB: delivery_status/{deliveryId} -> { lat, lng, ... }
  Stream<Map<String, LatLng>> _riderPositionsByDeliveryIds(
    Set<String> assignedDeliveryIds,
  ) {
    if (assignedDeliveryIds.isEmpty) return Stream.value(const {});
    final controller = StreamController<Map<String, LatLng>>.broadcast();
    final cache = <String, LatLng>{};
    final subs = <StreamSubscription<DatabaseEvent>>[];

    void push() => controller.add(Map<String, LatLng>.from(cache));

    for (final did in assignedDeliveryIds) {
      final ref = _rtdb.ref('delivery_status/$did');
      final sub = ref.onValue.listen(
        (event) {
          final v = event.snapshot.value;
          if (v is Map) {
            final lat = v['lat'];
            final lng = v['lng'];
            if (lat is num && lng is num) {
              cache[did] = LatLng(lat.toDouble(), lng.toDouble());
            } else {
              cache.remove(did);
            }
          } else {
            cache.remove(did);
          }
          push();
        },
        onError: (_) {
          cache.remove(did);
          push();
        },
      );
      subs.add(sub);
    }

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };
    return controller.stream;
  }

  // ---------- UI ----------
  Widget _pageHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _brandRed,
        border: Border(bottom: BorderSide(color: _black, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: const Text(
        'ดูตำแหน่ง',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: _black,
          shadows: [
            Shadow(
              blurRadius: 1.5,
              offset: Offset(0.8, 0.8),
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  // แถบปุ่มด้านบน (ปิดการกด) — คงพื้นหลังแถบ “แดง” ไว้ตามที่ต้องการ
  Widget _topFilterBar() {
    const gap = 10.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _brandRed,
        border: Border.all(color: _black, width: 2),
      ),
      child: Row(
        children: [
          _topButton(
            active: _showMyAddresses,
            label: 'พิกัดคุณ',
            icon: const Icon(
              Icons.location_on,
              color: Colors.redAccent,
              size: 20,
            ),
            enabled: false,
          ),
          const SizedBox(width: gap),
          _topButton(
            active: _showReceiverAddresses,
            label: 'พิกัดคนอื่น',
            icon: const Icon(
              Icons.location_on,
              color: Colors.black87,
              size: 20,
            ),
            enabled: false,
          ),
          const SizedBox(width: gap),
          _topButton(
            active: _showSenderRiders,
            label: 'ส่งสินค้า',
            icon: Image.asset(
              _iconSend,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
            enabled: false,
          ),
          const SizedBox(width: gap),
          _topButton(
            active: _showReceiverRiders,
            label: 'รับสินค้า',
            icon: Image.asset(
              _iconRecv,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _topButton({
    required bool active,
    required String label,
    required Widget icon,
    bool enabled = false,
    VoidCallback? onTap,
  }) {
    final content = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _black, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  color: _black,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: IgnorePointer(
        ignoring: !enabled,
        child: GestureDetector(onTap: enabled ? onTap : null, child: content),
      ),
    );
  }

  // ---------- Pins ----------
  Marker _pinCircle({
    required LatLng point,
    required Color color,
    double size = 40,
  }) {
    return Marker(
      point: point,
      width: size,
      height: size,
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size(size, size),
        painter: _TipAtCenterPinPainter(fill: color, stroke: Colors.black),
      ),
    );
  }

  Marker _pinLabel({
    required LatLng point,
    required String text,
    double above = 48,
  }) {
    return Marker(
      point: point,
      width: 0,
      height: 0,
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: ui.Offset(0, -above),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Marker _imagePin({
    required LatLng point,
    required String assetPath,
    double size = 56,
    double bottomOffset = 2,
  }) {
    return Marker(
      point: point,
      width: size,
      height: size + bottomOffset,
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomOffset),
        child: Image.asset(assetPath, fit: BoxFit.contain),
      ),
    );
  }

  // ---------- Map builder ----------
  Widget _buildMapViewByDelivery({
    required List<AddressSummary> myAddresses,
    required List<MapEntry<String, DeliveryRecord>> senderPairs,
    required List<MapEntry<String, DeliveryRecord>> receiverPairs,
    required Map<String, AddressSummary> addressMap,
    required Map<String, LatLng> riderByDeliveryId,
  }) {
    final markers = <Marker>[];
    final circles = <CircleMarker>[]; // <-- NEW: เก็บวงกลม
    final myPoints = <LatLng>[]; // ใช้กำหนดกล้องเฉพาะหมุดแดง/พิกัดฉัน

    // ---------- พิกัด GPS ของฉัน: วงกลมสีฟ้า ----------
    if (_myGpsPoint != null) {
      final p = _myGpsPoint!;
      myPoints.add(p);

      // วงโปร่งสีฟ้า (รัศมีเป็นพิกเซล ไม่ใช่เมตร)
      circles.add(
        CircleMarker(
          point: p,
          radius: 22, // ปรับขนาดได้
          useRadiusInMeter: false,
          color: Colors.lightBlueAccent.withOpacity(0.35),
          borderColor: Colors.blueAccent,
          borderStrokeWidth: 2,
        ),
      );

      // จุดสีน้ำเงินตรงกลาง (ดูคล้ายตำแหน่งปัจจุบันในแผนที่ทั่วไป)
      markers.add(
        Marker(
          point: p,
          width: 14,
          height: 14,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
      // ถ้าต้องการป้าย "คุณ" ด้วย ให้ปลดคอมเมนต์บรรทัดด้านล่าง
      // markers.add(_pinLabel(point: p, text: 'คุณ', above: 30));
    }

    // ---------- ที่อยู่ของเรา (หมุดวงกลมแดงเหมือนเดิม) ----------
    if (_showMyAddresses) {
      for (final a in myAddresses) {
        if (a.lat != null && a.lng != null) {
          final p = LatLng(a.lat!, a.lng!);
          myPoints.add(p);
          const s = 40.0;
          markers.addAll([
            _pinCircle(point: p, color: Colors.redAccent, size: s),
            _pinLabel(point: p, text: 'คุณ', above: s * 1.25),
          ]);
        }
      }
    }

    // ---------- ปลายทางอีกฝั่ง (หมุดวงกลมดำเหมือนเดิม) ----------
    if (_showReceiverAddresses) {
      for (final e in senderPairs) {
        final a = addressMap[e.value.receiverAddressId ?? ''];
        if (a?.lat != null && a?.lng != null) {
          final p = LatLng(a!.lat!, a.lng!);
          const s = 40.0;
          markers.addAll([
            _pinCircle(point: p, color: Colors.black87, size: s),
            _pinLabel(point: p, text: 'ผู้รับ', above: s * 1.25),
          ]);
        }
      }
      for (final e in receiverPairs) {
        final a = addressMap[e.value.senderAddressId ?? ''];
        if (a?.lat != null && a?.lng != null) {
          final p = LatLng(a!.lat!, a.lng!);
          const s = 40.0;
          markers.addAll([
            _pinCircle(point: p, color: Colors.black87, size: s),
            _pinLabel(point: p, text: 'ผู้ส่ง', above: s * 1.25),
          ]);
        }
      }
    }

    // ---------- ไรเดอร์ (ไอคอนเดิม) ----------
    if (_showSenderRiders) {
      for (final e in senderPairs) {
        final p = riderByDeliveryId[e.key];
        if (p != null) {
          const s = 56.0;
          markers.addAll([
            _imagePin(point: p, assetPath: _iconSend, size: s),
            _pinLabel(point: p, text: 'ส่ง', above: s * .95),
          ]);
        }
      }
    }
    if (_showReceiverRiders) {
      for (final e in receiverPairs) {
        final p = riderByDeliveryId[e.key];
        if (p != null) {
          const s = 56.0;
          markers.addAll([
            _imagePin(point: p, assetPath: _iconRecv, size: s),
            _pinLabel(point: p, text: 'รับ', above: s * .95),
          ]);
        }
      }
    }

    if (myPoints.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: _black, width: 2),
          borderRadius: BorderRadius.circular(28),
        ),
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text('ยังไม่มีพิกัดของคุณที่จะแสดง'),
        ),
      );
    }

    final useBounds = myPoints.length > 1;
    final firstMy = myPoints.first;

    _fitToMeOnce(firstMy);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _black, width: 2),
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCameraFit: useBounds
              ? CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(myPoints),
                  padding: _mapPadding,
                )
              : null,
          onMapReady: () {
            _mapReady = true;
            if (!_didFitToMe && _pendingCenterForMe != null) {
              _mapController.move(_pendingCenterForMe!, 16);
              _didFitToMe = true;
            }
          },
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.delivery',
            maxZoom: 19,
          ),

          // <-- NEW: วงกลมสีฟ้า (และวงกลมอื่น ๆ ถ้ามี)
          if (circles.isNotEmpty) CircleLayer(circles: circles),

          // หมุดอื่น ๆ เหมือนเดิม
          MarkerLayer(rotate: false, markers: markers),

          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/พื้นหลังแอพ.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black26],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _pageHeader(),
                _topFilterBar(),
                Expanded(
                  child:
                      StreamBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
                        stream: StreamZip([
                          _firestore
                              .collection('delivery')
                              .where('userid_sender', isEqualTo: widget.userId)
                              .snapshots(),
                          _firestore
                              .collection('delivery')
                              .where(
                                'userid_receiver',
                                isEqualTo: widget.userId,
                              )
                              .snapshots(),
                        ]),
                        builder: (context, comboSnap) {
                          final senderDocs = comboSnap.data != null
                              ? comboSnap.data![0].docs
                              : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                          final receiverDocs = comboSnap.data != null
                              ? comboSnap.data![1].docs
                              : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                          final senderPairs = senderDocs
                              .map((d) => MapEntry(d.id, DeliveryRecord(d)))
                              .where((e) => e.value.isMapRelated)
                              .toList();
                          final receiverPairs = receiverDocs
                              .map((d) => MapEntry(d.id, DeliveryRecord(d)))
                              .where((e) => e.value.isMapRelated)
                              .toList();

                          // ที่อยู่ที่ต้องโหลด
                          final myAddrIds = <String>{
                            ...senderPairs
                                .map((e) => e.value.senderAddressId ?? '')
                                .where((id) => id.isNotEmpty),
                            ...receiverPairs
                                .map((e) => e.value.receiverAddressId ?? '')
                                .where((id) => id.isNotEmpty),
                          };
                          final otherAddrIds = <String>{
                            ...senderPairs
                                .map((e) => e.value.receiverAddressId ?? '')
                                .where((id) => id.isNotEmpty),
                            ...receiverPairs
                                .map((e) => e.value.senderAddressId ?? '')
                                .where((id) => id.isNotEmpty),
                          };
                          final allAddrIds = {...myAddrIds, ...otherAddrIds};

                          // ไอดีงานทั้งหมด
                          final deliveryIds = <String>{
                            ...senderPairs.map((e) => e.key),
                            ...receiverPairs.map((e) => e.key),
                          };

                          // assignment ที่รับงานแล้ว
                          final assStream = deliveryIds.isEmpty
                              ? const Stream<
                                  List<QuerySnapshot<Map<String, dynamic>>>
                                >.empty()
                              : _assignmentStream(deliveryIds);

                          return StreamBuilder<
                            List<QuerySnapshot<Map<String, dynamic>>>
                          >(
                            stream: assStream,
                            builder: (context, assSnap) {
                              final acceptedDeliveryIds = <String>{};
                              for (final qs in assSnap.data ?? const []) {
                                for (final doc in qs.docs) {
                                  final did = doc.data()['deliveryid'];
                                  if (did is int)
                                    acceptedDeliveryIds.add('$did');
                                  if (did is String)
                                    acceptedDeliveryIds.add(did);
                                }
                              }

                              // ตำแหน่งไรเดอร์แบบเรียลไทม์ (หลายงานพร้อมกัน)
                              final riderStream = _riderPositionsByDeliveryIds(
                                acceptedDeliveryIds,
                              );

                              return StreamBuilder<Map<String, LatLng>>(
                                stream: riderStream,
                                builder: (context, riderSnap) {
                                  final riderByDeliveryId =
                                      riderSnap.data ??
                                      const <String, LatLng>{};

                                  if (allAddrIds.isEmpty &&
                                      _myGpsPoint == null) {
                                    // ไม่มีทั้งพิกัดคุณ & ที่อยู่ -> แสดงข้อความ
                                    return _buildMapViewByDelivery(
                                      myAddresses: const [],
                                      senderPairs: senderPairs,
                                      receiverPairs: receiverPairs,
                                      addressMap: const {},
                                      riderByDeliveryId: riderByDeliveryId,
                                    );
                                  }

                                  return FutureBuilder<
                                    Map<String, AddressSummary>
                                  >(
                                    future: allAddrIds.isEmpty
                                        ? Future.value(
                                            <String, AddressSummary>{},
                                          )
                                        : _loadAddresses(allAddrIds).timeout(
                                            const Duration(seconds: 8),
                                            onTimeout: () =>
                                                <String, AddressSummary>{},
                                          ),
                                    builder: (context, addrSnapshot) {
                                      final addressMap =
                                          addrSnapshot.data ??
                                          <String, AddressSummary>{};
                                      final myAddresses = myAddrIds
                                          .map((id) => addressMap[id])
                                          .where((a) => a != null)
                                          .cast<AddressSummary>()
                                          .toList();

                                      return _buildMapViewByDelivery(
                                        myAddresses: myAddresses,
                                        senderPairs: senderPairs,
                                        receiverPairs: receiverPairs,
                                        addressMap: addressMap,
                                        riderByDeliveryId: riderByDeliveryId,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FooterNavBar(currentIndex: 2, userId: widget.userId),
    );
  }
}

// ===== Painter: หมุดปลายแหลมชี้ตรงพิกัด =====
class _TipAtCenterPinPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  _TipAtCenterPinPainter({required this.fill, required this.stroke});

  @override
  void paint(ui.Canvas canvas, ui.Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    final tip = ui.Offset(cx, cy);

    final r = s.width * 0.22;
    final tailH = s.height * 0.28;
    final baseY = cy - tailH;

    final left = ui.Offset(cx - r * 0.9, baseY);
    final right = ui.Offset(cx + r * 0.9, baseY);
    final headCenter = ui.Offset(cx, baseY - r * 0.05 - r);

    final fillPaint = ui.Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    final strokePaint = ui.Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final tail = ui.Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(tail, fillPaint);
    canvas.drawCircle(headCenter, r, fillPaint);

    canvas.drawPath(tail, strokePaint);
    canvas.drawCircle(headCenter, r, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TipAtCenterPinPainter old) =>
      old.fill != fill || old.stroke != stroke;
}
