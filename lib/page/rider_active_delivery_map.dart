import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  final _firestore = FirebaseFirestore.instance;
  final _mapController = MapController();
  final _lookup = DeliveryLookupCache();

  StreamSubscription<Position>? _positionSub;
  Position? _currentPosition;
  bool _centered = false;

  bool _processing = false; // กันทริกเกอร์ซ้อน
  Map<String, dynamic>? _latestData; // เก็บ snapshot ล่าสุด

  AddressSummary? _senderAddress;
  AddressSummary? _receiverAddress;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    try {
      final position = await LocationUtils.ensureCurrentPosition();
      await _handlePosition(position);
      _positionSub = LocationUtils.livePositionStream().listen(_handlePosition);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handlePosition(Position position) async {
    _currentPosition = position;
    if (!_centered) {
      _centered = true;
      _mapController.move(LatLng(position.latitude, position.longitude), 16);
    }
    setState(() {});
    // อัปเดตตำแหน่งไรเดอร์
    await _firestore.collection('rider_location').doc(widget.userId).set({
      'riderid': widget.userId,
      'lat': position.latitude,
      'lng': position.longitude,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _maybeAutoProgress();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
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

  /// เดิน flow อัตโนมัติเมื่อ "เข้าใกล้ 20 ม."
  Future<void> _maybeAutoProgress() async {
    if (_processing) return;
    if (_latestData == null || _currentPosition == null) return;

    final data = _latestData!;
    final status = DeliveryStatus.normalize(data['status']?.toString());
    final riderId = data['riderid']?.toString();
    if (riderId != widget.userId) return;

    await _ensureAddresses(data);

    // 1) ถึงจุดรับ (กำลังไปรับ)
    if (status == DeliveryStatus.waitingForRider) {
      final s = _senderAddress;
      if (s?.lat == null || s?.lng == null) return;

      final nearPickup = LocationUtils.isWithinDistance(
        position: _currentPosition!,
        targetLat: s!.lat,
        targetLng: s.lng,
        maxDistanceMeters: 20,
      );
      if (!nearPickup) return;

      _processing = true;
      try {
        final ref = _firestore.collection('delivery').doc(widget.deliveryId);
        await ref.update({
          'status': DeliveryStatus.riderAccepted,
          'updated_at': FieldValue.serverTimestamp(),
        });

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
          await ref.update({'picture_status3': url});
        }
      } finally {
        _processing = false;
      }
      return;
    }

    // 2) ถึงจุดส่ง (กำลังไปส่ง)
    if (status == DeliveryStatus.riderAccepted) {
      final r = _receiverAddress;
      if (r?.lat == null || r?.lng == null) return;

      final nearDrop = LocationUtils.isWithinDistance(
        position: _currentPosition!,
        targetLat: r!.lat,
        targetLng: r.lng,
        maxDistanceMeters: 20,
      );
      if (!nearDrop) return;

      _processing = true;
      try {
        final ref = _firestore.collection('delivery').doc(widget.deliveryId);
        await ref.update({
          'status': DeliveryStatus.riderPickedUp,
          'updated_at': FieldValue.serverTimestamp(),
        });

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

          await ref.update({
            'picture_status4': url,
            'status': DeliveryStatus.delivered,
            'updated_at': FieldValue.serverTimestamp(),
          });

          try {
            await _firestore
                .collection('rider_location')
                .doc(widget.userId)
                .delete();
          } catch (_) {}
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('จัดส่งสำเร็จ ✅')));
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => JobsPage(userId: widget.userId)),
            (r) => false,
          );
        }
      } finally {
        _processing = false;
      }
    }
  }

  String _headerTitle(String status) {
    if (status == DeliveryStatus.waitingForRider) return 'ไปรับสินค้า';
    if (status == DeliveryStatus.riderAccepted) return 'ไปส่งสินค้า';
    return 'ติดตามงาน';
  }

  LatLng? _currentTarget(String status) {
    if (status == DeliveryStatus.waitingForRider) {
      final s = _senderAddress;
      if (s?.lat != null && s?.lng != null) return LatLng(s!.lat!, s.lng!);
    } else if (status == DeliveryStatus.riderAccepted) {
      final r = _receiverAddress;
      if (r?.lat != null && r?.lng != null) return LatLng(r!.lat!, r.lng!);
    }
    return null;
  }

  Future<void> _centerToTarget(String status) async {
    final t = _currentTarget(status);
    if (t == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยังไม่มีพิกัดเป้าหมาย')));
      return;
    }
    _mapController.move(t, 17);
  }

  Future<void> _centerToMe() async {
    final pos = _currentPosition;
    if (pos == null) return;
    _mapController.move(LatLng(pos.latitude, pos.longitude), 17);
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(13.7563, 100.5018); // fallback กทม.

    // ====== สร้างเลเยอร์ marker และวงกลม (ใช้บ่อย แยกประกาศตรงนี้) ======
    List<Marker> _buildMarkers(String status) {
      final markers = <Marker>[];

      final pos = _currentPosition;
      if (pos != null) {
        // รถมอไซค์ (ถ้าไฟล์ไม่มีจะ fallback เป็นไอคอน)
        markers.add(
          Marker(
            point: LatLng(pos.latitude, pos.longitude),
            width: 80,
            height: 80,
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/rider_bike.png', // ใส่ไฟล์นี้ไว้ที่ assets/images/
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.motorcycle, size: 44, color: Colors.black),
            ),
          ),
        );
      }

      final target = _currentTarget(status);
      if (target != null) {
        markers.add(
          Marker(
            point: target,
            width: 40,
            height: 40,
            child: const Icon(Icons.location_on, color: Colors.black, size: 40),
          ),
        );
      }
      return markers;
    }

    List<CircleMarker> _buildCircles() {
      final circles = <CircleMarker>[];
      final pos = _currentPosition;
      if (pos != null) {
        circles.add(
          CircleMarker(
            point: LatLng(pos.latitude, pos.longitude),
            // ✅ ใช้หน่วย “เมตร” ไม่ใช่พิกเซล
            radius: 20, // 20 เมตร
            useRadiusInMeter: true,
            color: _brandRed.withOpacity(0.22),
            borderColor: Colors.black,
            borderStrokeWidth: 2,
          ),
        );
      }
      return circles;
    }

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
            _latestData = data;

            final status = DeliveryStatus.normalize(data['status']?.toString());
            final riderId = data['riderid']?.toString();

            _ensureAddresses(data);

            if (riderId != widget.userId) {
              return const Center(
                child: Text('งานนี้ไม่อยู่ในความดูแลของคุณแล้ว'),
              );
            }

            if (status == DeliveryStatus.delivered) {
              Future.microtask(() {
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => JobsPage(userId: widget.userId),
                  ),
                  (route) => false,
                );
              });
            }

            final markers = _buildMarkers(status);
            final circles = _buildCircles();

            return Column(
              children: [
                // ===== Header อยู่ใน SafeArea และเพิ่ม padding กันชน =====
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

                // ===== แผนที่เต็มพื้นที่ + ปุ่มด้านขวาล่างตามดีไซน์ =====
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: initialCenter,
                          initialZoom: 16,
                          maxZoom: 18,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.flutter_application_4',
                          ),
                          // ✅ วงรัศมีแบบเมตร
                          CircleLayer(circles: circles),
                          MarkerLayer(markers: markers),
                        ],
                      ),

                      // ปุ่มกลม 2 ปุ่ม มุมขวาล่าง
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

// ====== UI helpers ======

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
