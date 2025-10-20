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
  final _firestore = FirebaseFirestore.instance;
  final _mapController = MapController();
  final _lookup = DeliveryLookupCache();

  StreamSubscription<Position>? _positionSub;
  Position? _currentPosition;
  bool _centered = false;
  bool _processing = false;

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
      _handlePosition(position);
      _positionSub = LocationUtils.livePositionStream().listen(_handlePosition);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handlePosition(Position position) async {
    _currentPosition = position;
    if (!_centered) {
      _centered = true;
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        16,
      );
    }
    setState(() {});
    await _firestore.collection('rider_location').doc(widget.userId).set({
          'riderid': widget.userId,
          'lat': position.latitude,
          'lng': position.longitude,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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
      final cached = _senderAddress;
      if (cached == null || cached.id != senderId) {
        final result = await _lookup.getAddress(senderId);
        if (mounted) {
          setState(() => _senderAddress = result);
        }
      }
    }

    if (receiverId != null && receiverId.isNotEmpty) {
      final cached = _receiverAddress;
      if (cached == null || cached.id != receiverId) {
        final result = await _lookup.getAddress(receiverId);
        if (mounted) {
          setState(() => _receiverAddress = result);
        }
      }
    }
  }

  Future<void> _onPickup(Map<String, dynamic> data) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final position = await LocationUtils.ensureCurrentPosition();
      final sender = _senderAddress;
      if (!LocationUtils.isWithinDistance(
        position: position,
        targetLat: sender?.lat,
        targetLng: sender?.lng,
        maxDistanceMeters: 20,
      )) {
        throw const LocationException(
          'ต้องอยู่ใกล้จุดรับสินค้ามากกว่า 20 เมตรเพื่อกดรับงาน',
        );
      }

      final file = await Navigator.of(context).push<File?>(
        MaterialPageRoute(
          builder: (_) => const RiderCapturePhotoPage(
            title: 'ถ่ายภาพหลักฐาน',
            subtitle: 'รูปรับสินค้า',
          ),
        ),
      );
      if (file == null) return;

      final url = await uploadImageToSupabase(
        file: file,
        path:
            'deliveries/${widget.deliveryId}/picked_up_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await _firestore.collection('delivery').doc(widget.deliveryId).update({
            'status': DeliveryStatus.riderPickedUp,
            'picture_status3': url,
            'updated_at': FieldValue.serverTimestamp(),
          });
    } on LocationException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('บันทึกสถานะไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _onDelivered(Map<String, dynamic> data) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final position = await LocationUtils.ensureCurrentPosition();
      final receiver = _receiverAddress;
      if (!LocationUtils.isWithinDistance(
        position: position,
        targetLat: receiver?.lat,
        targetLng: receiver?.lng,
        maxDistanceMeters: 20,
      )) {
        throw const LocationException(
          'ต้องอยู่ใกล้จุดส่งสินค้ามากกว่า 20 เมตรเพื่อบันทึกการจัดส่ง',
        );
      }

      final file = await Navigator.of(context).push<File?>(
        MaterialPageRoute(
          builder: (_) => const RiderCapturePhotoPage(
            title: 'ถ่ายภาพหลักฐาน',
            subtitle: 'รูปส่งสินค้า',
          ),
        ),
      );
      if (file == null) return;

      final url = await uploadImageToSupabase(
        file: file,
        path:
            'deliveries/${widget.deliveryId}/delivered_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await _firestore.collection('delivery').doc(widget.deliveryId).update({
            'status': DeliveryStatus.delivered,
            'picture_status4': url,
            'updated_at': FieldValue.serverTimestamp(),
          });
      try {
        await _firestore.collection('rider_location').doc(widget.userId).delete();
      } catch (_) {
        // ignore if location document already removed
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('จัดส่งสำเร็จ ✅')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => JobsPage(userId: widget.userId)),
        (route) => false,
      );
    } on LocationException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('บันทึกสถานะไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Widget _buildHeader(String status) {
    String title;
    if (status == DeliveryStatus.riderAccepted) {
      title = 'ไปรับสินค้า';
    } else if (status == DeliveryStatus.riderPickedUp) {
      title = 'ไปส่งสินค้า';
    } else {
      title = 'ติดตามงาน';
    }
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFE96356),
        border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildActionArea(String status, Map<String, dynamic> data) {
    if (status == DeliveryStatus.riderAccepted) {
      return _ActionButton(
        label: 'บันทึกการรับสินค้า',
        onPressed: _processing ? null : () => _onPickup(data),
      );
    }
    if (status == DeliveryStatus.riderPickedUp) {
      return _ActionButton(
        label: 'บันทึกการส่งสินค้า',
        onPressed: _processing ? null : () => _onDelivered(data),
      );
    }
    return const SizedBox.shrink();
  }

  List<Marker> _buildMarkers(String status) {
    final markers = <Marker>[];
    if (_currentPosition != null) {
      final pos = _currentPosition!;
      markers.add(
        Marker(
          point: LatLng(pos.latitude, pos.longitude),
          width: 80,
          height: 80,
          builder: (_) => Image.asset(
            'assets/images/rider_red.png',
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    LatLng? target;
    if (status == DeliveryStatus.riderAccepted) {
      if (_senderAddress?.lat != null && _senderAddress?.lng != null) {
        target = LatLng(_senderAddress!.lat!, _senderAddress!.lng!);
      }
    } else if (status == DeliveryStatus.riderPickedUp) {
      if (_receiverAddress?.lat != null && _receiverAddress?.lng != null) {
        target = LatLng(_receiverAddress!.lat!, _receiverAddress!.lng!);
      }
    }

    if (target != null) {
      markers.add(
        Marker(
          point: target,
          width: 40,
          height: 40,
          builder: (_) => const Icon(
            Icons.location_on,
            color: Colors.black,
            size: 40,
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('delivery').doc(widget.deliveryId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('ไม่พบงานจัดส่งนี้แล้ว'));
            }

            final data = snapshot.data!.data() ?? {};
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
                  MaterialPageRoute(builder: (_) => JobsPage(userId: widget.userId)),
                  (route) => false,
                );
              });
            }

            final markers = _buildMarkers(status);

            return Stack(
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
                        colors: [Colors.transparent, Colors.black38],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(status),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialZoom: 16,
                                    maxZoom: 18,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      subdomains: const ['a', 'b', 'c'],
                                    ),
                                    MarkerLayer(markers: markers),
                                  ],
                                ),
                                Positioned(
                                  right: 12,
                                  bottom: 12,
                                  child: FloatingActionButton(
                                    backgroundColor: const Color(0xFFE96356),
                                    foregroundColor: Colors.black,
                                    onPressed: () {
                                      final pos = _currentPosition;
                                      if (pos != null) {
                                        _mapController.move(
                                          LatLng(pos.latitude, pos.longitude),
                                          17,
                                        );
                                      }
                                    },
                                    child: const Icon(Icons.my_location),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'สถานะปัจจุบัน: $status',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_senderAddress != null)
                              Text('จุดรับสินค้า: ${_senderAddress!.address}'),
                            if (_receiverAddress != null)
                              Text('จุดส่งสินค้า: ${_receiverAddress!.address}'),
                            const SizedBox(height: 12),
                            _buildActionArea(status, data),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE96356),
          foregroundColor: Colors.black,
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
