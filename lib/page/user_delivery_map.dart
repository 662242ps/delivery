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

  // ฟิลเตอร์การแสดงผล
  bool _showMyAddresses = true; // พิกัดคุณ (ที่อยู่ของฉัน)
  bool _showReceiverAddresses = true; // พิกัดผู้รับ (งานที่ฉันเป็นผู้ส่ง)
  bool _showSenderRiders =
      true; // ไรเดอร์ที่ "กำลังส่ง" ให้ผู้รับ (งานที่ฉันเป็นผู้ส่ง)
  bool _showReceiverRiders =
      true; // ไรเดอร์ที่ "กำลังมารับ/ส่งให้ฉัน" (งานที่ฉันเป็นผู้รับ)

  bool _hasCentered = false;

  // ---------- Utilities ----------
  Future<Map<String, AddressSummary>> _loadAddresses(
    Iterable<String> ids,
  ) async {
    final result = <String, AddressSummary>{};
    for (final id in ids) {
      final summary = await _lookup.getAddress(id);
      if (summary != null) result[id] = summary;
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

  // รวมสตรีมตำแหน่งไรเดอร์แบบเรียลไทม์ (จำกัด whereIn <= 10)
  Stream<List<QuerySnapshot<Map<String, dynamic>>>> _riderLocationsStream(
    Set<String> riderIds,
  ) {
    final parts = _chunk(riderIds, 10);
    final streams = parts.map(
      (c) => _firestore
          .collection('rider_location')
          .where('riderid', whereIn: c)
          .snapshots(),
    );
    if (streams.isEmpty) return const Stream.empty();
    return StreamZip(streams.toList());
  }

  void _centerIfNeeded(List<LatLng> points) {
    if (_hasCentered || points.isEmpty) return;
    _hasCentered = true;
    final bounds = LatLngBounds.fromPoints(points);
    Future.microtask(() {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    });
  }

  // ---------- Header ----------
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

  // ---------- Top filter bar ----------
  Widget _topFilterBar() {
    const double gap = 10;
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
            onTap: () => setState(() {
              _showMyAddresses = !_showMyAddresses;
              _hasCentered = false;
            }),
          ),
          const SizedBox(width: gap),
          _topButton(
            active: _showReceiverAddresses,
            label: 'พิกัดผู้รับ',
            icon: const Icon(
              Icons.location_on,
              color: Colors.black87,
              size: 20,
            ),
            onTap: () => setState(() {
              _showReceiverAddresses = !_showReceiverAddresses;
              _hasCentered = false;
            }),
          ),
          const SizedBox(width: gap),
          _topButton(
            active: _showSenderRiders,
            label: 'ส่งสินค้า',
            icon: const Icon(Icons.two_wheeler, size: 20, color: Colors.orange),
            onTap: () => setState(() {
              _showSenderRiders = !_showSenderRiders;
              _hasCentered = false;
            }),
          ),
          const SizedBox(width: gap),
          _topButton(
            active: _showReceiverRiders,
            label: 'รับสินค้า',
            icon: const Icon(Icons.pedal_bike, size: 20, color: Colors.black87),
            onTap: () => setState(() {
              _showReceiverRiders = !_showReceiverRiders;
              _hasCentered = false;
            }),
          ),
        ],
      ),
    );
  }

  Widget _topButton({
    required bool active,
    required String label,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _black, width: 2),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
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
        ),
      ),
    );
  }

  // ---------- Pins ----------
  Marker _pinCircle({
    required LatLng point,
    required Color color,
    required IconData icon,
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

  // ---------- Map builder ----------
  Widget _buildMapView({
    required List<AddressSummary> myAddresses,
    required List<DeliveryRecord> senderRecords,
    required List<DeliveryRecord> receiverRecords,
    required Map<String, AddressSummary> addressMap,
    required Map<String, LatLng> riderMap,
  }) {
    final markers = <Marker>[];
    final points = <LatLng>[];

    // พิกัดคุณ (ที่อยู่ของฉัน)
    if (_showMyAddresses) {
      for (final addr in myAddresses) {
        if (addr.lat != null && addr.lng != null) {
          final p = LatLng(addr.lat!, addr.lng!);
          points.add(p);
          const iconSize = 40.0;
          markers.addAll([
            _pinCircle(
              point: p,
              color: Colors.redAccent,
              icon: Icons.location_on,
              size: iconSize,
            ),
            _pinLabel(point: p, text: 'คุณ', above: iconSize * 1.25),
          ]);
        }
      }
    }

    // พิกัดผู้รับ (เฉพาะงานที่เราเป็นผู้ส่ง)
    if (_showReceiverAddresses) {
      for (final rec in senderRecords) {
        final a = addressMap[rec.receiverAddressId ?? ''];
        if (a?.lat != null && a?.lng != null) {
          final p = LatLng(a!.lat!, a.lng!);
          points.add(p);
          const iconSize = 40.0;
          markers.addAll([
            _pinCircle(
              point: p,
              color: Colors.black87,
              icon: Icons.location_on,
              size: iconSize,
            ),
            _pinLabel(point: p, text: 'ผู้รับ', above: iconSize * 1.25),
          ]);
        }
      }
    }

    // ไรเดอร์กำลัง "ส่ง" (งานที่เราเป็นผู้ส่ง)
    if (_showSenderRiders) {
      for (final rec in senderRecords) {
        final id = rec.riderId;
        if (id != null && riderMap.containsKey(id)) {
          final p = riderMap[id]!;
          points.add(p);
          const iconSize = 40.0;
          markers.addAll([
            _pinCircle(
              point: p,
              color: Colors.orange,
              icon: Icons.delivery_dining,
              size: iconSize,
            ),
            _pinLabel(point: p, text: 'ส่ง', above: iconSize * 1.25),
          ]);
        }
      }
    }

    // ไรเดอร์กำลัง "รับ/นำส่งให้ฉัน" (งานที่เราเป็นผู้รับ)
    if (_showReceiverRiders) {
      for (final rec in receiverRecords) {
        final id = rec.riderId;
        if (id != null && riderMap.containsKey(id)) {
          final p = riderMap[id]!;
          points.add(p);
          const iconSize = 40.0;
          markers.addAll([
            _pinCircle(
              point: p,
              color: _brandRed,
              icon: Icons.pedal_bike,
              size: iconSize,
            ),
            _pinLabel(point: p, text: 'รับ', above: iconSize * 1.25),
          ]);
        }
      }
    }

    if (markers.isEmpty) {
      return const Center(
        child: Text(
          'ยังไม่มีข้อมูลตำแหน่งสำหรับแสดงบนแผนที่',
          textAlign: TextAlign.center,
        ),
      );
    }

    _centerIfNeeded(points);
    final initialCenter = points.isNotEmpty
        ? points.first
        : const LatLng(13.7563, 100.5018);

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
          initialCenter: initialCenter,
          initialZoom: 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.delivery',
            maxZoom: 19,
          ),
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
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore
                        .collection('user_address')
                        .where('userid', isEqualTo: widget.userId)
                        .snapshots(),
                    builder: (context, userAddrSnap) {
                      if (userAddrSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (userAddrSnap.hasError) {
                        return Center(
                          child: Text(
                            'โหลดข้อมูลที่อยู่ล้มเหลว: ${userAddrSnap.error}',
                          ),
                        );
                      }
                      final myAddresses =
                          userAddrSnap.data?.docs
                              .map(AddressSummary.fromSnapshot)
                              .toList() ??
                          [];

                      // งานที่เราเป็น "ผู้ส่ง"
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _firestore
                            .collection('delivery')
                            .where('userid_sender', isEqualTo: widget.userId)
                            .snapshots(),
                        builder: (context, senderSnap) {
                          if (senderSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (senderSnap.hasError) {
                            return Center(
                              child: Text(
                                'โหลดรายการส่งล้มเหลว: ${senderSnap.error}',
                              ),
                            );
                          }
                          final senderRecords =
                              senderSnap.data?.docs
                                  .map((d) => DeliveryRecord(d))
                                  .where((rec) => rec.isMapRelated)
                                  .toList() ??
                              [];

                          // งานที่เราเป็น "ผู้รับ"
                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: _firestore
                                .collection('delivery')
                                .where(
                                  'userid_receiver',
                                  isEqualTo: widget.userId,
                                )
                                .snapshots(),
                            builder: (context, receiverSnap) {
                              if (receiverSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (receiverSnap.hasError) {
                                return Center(
                                  child: Text(
                                    'โหลดรายการรับล้มเหลว: ${receiverSnap.error}',
                                  ),
                                );
                              }
                              final receiverRecords =
                                  receiverSnap.data?.docs
                                      .map((d) => DeliveryRecord(d))
                                      .where((rec) => rec.isMapRelated)
                                      .toList() ??
                                  [];

                              // โหลดที่อยู่ปลายทางทั้งหมด (ของผู้รับสำหรับ senderRecords และของผู้ส่งสำหรับ receiverRecords)
                              final addressIds = <String>{
                                ...senderRecords
                                    .map((rec) => rec.receiverAddressId ?? '')
                                    .where((id) => id.isNotEmpty),
                                ...receiverRecords
                                    .map((rec) => rec.senderAddressId ?? '')
                                    .where((id) => id.isNotEmpty),
                              };

                              return FutureBuilder<Map<String, AddressSummary>>(
                                future: _loadAddresses(addressIds),
                                builder: (context, addrSnapshot) {
                                  if (addrSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (addrSnapshot.hasError) {
                                    return Center(
                                      child: Text(
                                        'โหลดที่อยู่ปลายทางล้มเหลว: ${addrSnapshot.error}',
                                      ),
                                    );
                                  }
                                  final addressMap = addrSnapshot.data ?? {};

                                  // รวบรวมไอดีไรเดอร์ที่เกี่ยวข้องทั้งหมด
                                  final riderIds = <String>{
                                    ...senderRecords
                                        .map((rec) => rec.riderId ?? '')
                                        .where((id) => id.isNotEmpty),
                                    ...receiverRecords
                                        .map((rec) => rec.riderId ?? '')
                                        .where((id) => id.isNotEmpty),
                                  };

                                  // ถ้ายังไม่มีไรเดอร์ (ยังไม่ถูกจับคู่) ก็วาดเฉพาะหมุดที่อยู่
                                  if (riderIds.isEmpty) {
                                    return _buildMapView(
                                      myAddresses: myAddresses,
                                      senderRecords: senderRecords,
                                      receiverRecords: receiverRecords,
                                      addressMap: addressMap,
                                      riderMap: const {},
                                    );
                                  }

                                  // ตำแหน่งไรเดอร์แบบเรียลไทม์
                                  return StreamBuilder<
                                    List<QuerySnapshot<Map<String, dynamic>>>
                                  >(
                                    stream: _riderLocationsStream(riderIds),
                                    builder: (context, riderSnaps) {
                                      if (riderSnaps.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      if (riderSnaps.hasError) {
                                        return Center(
                                          child: Text(
                                            'โหลดตำแหน่งไรเดอร์ล้มเหลว: ${riderSnaps.error}',
                                          ),
                                        );
                                      }

                                      final riderMap = <String, LatLng>{};
                                      for (final qs
                                          in riderSnaps.data ?? const []) {
                                        for (final doc in qs.docs) {
                                          final d = doc.data();
                                          final lat = d['lat'];
                                          final lng = d['lng'];
                                          final riderId =
                                              (d['riderid'] ?? doc.id)
                                                  .toString();
                                          if (lat is num && lng is num) {
                                            riderMap[riderId] = LatLng(
                                              lat.toDouble(),
                                              lng.toDouble(),
                                            );
                                          }
                                        }
                                      }

                                      return _buildMapView(
                                        myAddresses: myAddresses,
                                        senderRecords: senderRecords,
                                        receiverRecords: receiverRecords,
                                        addressMap: addressMap,
                                        riderMap: riderMap,
                                      );
                                    },
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

// ===== Painter: หมุดปลายแหลมชี้ตรงจุดพิกัด =====
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
      ..style = ui.PaintingStyle.fill;
    final strokePaint = ui.Paint()
      ..color = stroke
      ..style = ui.PaintingStyle.stroke
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
