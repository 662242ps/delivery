import 'dart:async';
import 'dart:ui';

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

  final _mapController = MapController();
  final _firestore = FirebaseFirestore.instance;
  final _lookup = DeliveryLookupCache();

  bool _showMyAddresses = true;
  bool _showReceiverAddresses = true;
  bool _showSenderRiders = true;
  bool _showReceiverRiders = true;

  bool _hasCentered = false;

  Future<Map<String, AddressSummary>> _loadAddresses(
      Iterable<String> ids) async {
    final result = <String, AddressSummary>{};
    for (final id in ids) {
      final summary = await _lookup.getAddress(id);
      if (summary != null) {
        result[id] = summary;
      }
    }
    return result;
  }

  void _centerIfNeeded(List<LatLng> points) {
    if (_hasCentered || points.isEmpty) return;
    _hasCentered = true;
    final target = points.first;
    Future.microtask(() {
      if (mounted) {
        _mapController.move(target, 14);
      }
    });
  }

  Widget _buildToggleButton({
    required bool active,
    required String label,
    required VoidCallback onTap,
    Color activeColor = _brandRed,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: [
              if (active)
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.black : Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapView({
    required List<AddressSummary> myAddresses,
    required List<DeliveryRecord> senderRecords,
    required List<DeliveryRecord> receiverRecords,
    required Map<String, AddressSummary> addressMap,
    required Map<String, LatLng> riderMap,
  }) {
    final markers = <Marker>[];
    final points = <LatLng>[];

    if (_showMyAddresses) {
      for (final addr in myAddresses) {
        if (addr.lat != null && addr.lng != null) {
          final point = LatLng(addr.lat!, addr.lng!);
          points.add(point);
          markers.add(
            Marker(
              width: 60,
              height: 60,
              point: point,
              builder: (_) => const _MapMarker(
                label: 'คุณ',
                color: Colors.blueAccent,
                icon: Icons.home,
              ),
            ),
          );
        }
      }
    }

    if (_showReceiverAddresses) {
      for (final rec in senderRecords) {
        final addr = addressMap[rec.receiverAddressId ?? ''];
        if (addr?.lat != null && addr?.lng != null) {
          final point = LatLng(addr!.lat!, addr.lng!);
          points.add(point);
          markers.add(
            Marker(
              width: 60,
              height: 60,
              point: point,
              builder: (_) => const _MapMarker(
                label: 'ผู้รับ',
                color: Colors.green,
                icon: Icons.place,
              ),
            ),
          );
        }
      }
    }

    if (_showSenderRiders) {
      for (final rec in senderRecords) {
        final riderId = rec.riderId;
        if (riderId != null && riderMap.containsKey(riderId)) {
          final point = riderMap[riderId]!;
          points.add(point);
          markers.add(
            Marker(
              width: 70,
              height: 70,
              point: point,
              builder: (_) => const _MapMarker(
                label: 'ไรเดอร์ส่ง',
                color: Colors.orange,
                icon: Icons.delivery_dining,
              ),
            ),
          );
        }
      }
    }

    if (_showReceiverRiders) {
      for (final rec in receiverRecords) {
        final riderId = rec.riderId;
        if (riderId != null && riderMap.containsKey(riderId)) {
          final point = riderMap[riderId]!;
          points.add(point);
          markers.add(
            Marker(
              width: 70,
              height: 70,
              point: point,
              builder: (_) => const _MapMarker(
                label: 'ไรเดอร์รับ',
                color: _brandRed,
                icon: Icons.pedal_bike,
              ),
            ),
          );
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
    final initialCenter =
        points.isNotEmpty ? points.first : LatLng(13.7563, 100.5018);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
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
            subdomains: const ['a', 'b', 'c'],
            userAgentPackageName: 'com.example.delivery',
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }

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
                  colors: [Colors.transparent, Colors.black38],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: _brandRed,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  child: const Text(
                    'ดูตำแหน่ง',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      shadows: [
                        Shadow(
                          blurRadius: 1.5,
                          offset: Offset(0.8, 0.8),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      _buildToggleButton(
                        active: _showMyAddresses,
                        label: 'พิกัดคุณ',
                        onTap: () => setState(() {
                          _showMyAddresses = !_showMyAddresses;
                        }),
                      ),
                      _buildToggleButton(
                        active: _showReceiverAddresses,
                        label: 'พิกัดผู้รับ',
                        onTap: () => setState(() {
                          _showReceiverAddresses = !_showReceiverAddresses;
                        }),
                      ),
                      _buildToggleButton(
                        active: _showSenderRiders,
                        label: 'ส่งสินค้า',
                        onTap: () => setState(() {
                          _showSenderRiders = !_showSenderRiders;
                        }),
                      ),
                      _buildToggleButton(
                        active: _showReceiverRiders,
                        label: 'รับสินค้า',
                        onTap: () => setState(() {
                          _showReceiverRiders = !_showReceiverRiders;
                        }),
                      ),
                    ],
                  ),
                ),
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
                          child: Text('โหลดข้อมูลที่อยู่ล้มเหลว: ${userAddrSnap.error}'),
                        );
                      }
                      final myAddresses = userAddrSnap.data?.docs
                              .map(AddressSummary.fromSnapshot)
                              .toList() ??
                          [];

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
                              child: Text('โหลดรายการส่งล้มเหลว: ${senderSnap.error}'),
                            );
                          }
                          final senderRecords = senderSnap.data?.docs
                                  .map((doc) => DeliveryRecord(doc))
                                  .where((rec) => rec.isMapRelated)
                                  .toList() ??
                              [];

                          return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: _firestore
                                .collection('delivery')
                                .where('userid_receiver', isEqualTo: widget.userId)
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
                                  child: Text('โหลดรายการรับล้มเหลว: ${receiverSnap.error}'),
                                );
                              }
                              final receiverRecords = receiverSnap.data?.docs
                                      .map((doc) => DeliveryRecord(doc))
                                      .where((rec) => rec.isMapRelated)
                                      .toList() ??
                                  [];

                              final addressIds = <String>{
                                ...senderRecords
                                    .map((rec) => rec.receiverAddressId ?? '')
                                    .where((id) => id.isNotEmpty),
                                ...receiverRecords
                                    .map((rec) => rec.senderAddressId ?? '')
                                    .where((id) => id.isNotEmpty),
                              };

                              return FutureBuilder<
                                  Map<String, AddressSummary>>(
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

                                  final riderIds = <String>{
                                    ...senderRecords
                                        .map((rec) => rec.riderId ?? '')
                                        .where((id) => id.isNotEmpty),
                                    ...receiverRecords
                                        .map((rec) => rec.riderId ?? '')
                                        .where((id) => id.isNotEmpty),
                                  };

                                  if (riderIds.isEmpty) {
                                    return _buildMapView(
                                      myAddresses: myAddresses,
                                      senderRecords: senderRecords,
                                      receiverRecords: receiverRecords,
                                      addressMap: addressMap,
                                      riderMap: const {},
                                    );
                                  }

                                  return StreamBuilder<
                                      QuerySnapshot<Map<String, dynamic>>>(
                                    stream: _firestore
                                        .collection('rider_location')
                                        .where('riderid',
                                            whereIn: riderIds.toList())
                                        .snapshots(),
                                    builder: (context, riderSnap) {
                                      if (riderSnap.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      if (riderSnap.hasError) {
                                        return Center(
                                          child: Text(
                                            'โหลดตำแหน่งไรเดอร์ล้มเหลว: ${riderSnap.error}',
                                          ),
                                        );
                                      }

                                      final riderMap = <String, LatLng>{};
                                      for (final doc in riderSnap.data?.docs ?? []) {
                                        final data = doc.data();
                                        final lat = data['lat'];
                                        final lng = data['lng'];
                                        final riderId =
                                            (data['riderid'] ?? doc.id).toString();
                                        if (lat is num && lng is num) {
                                          riderMap[riderId] =
                                              LatLng(lat.toDouble(), lng.toDouble());
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
      bottomNavigationBar:
          FooterNavBar(currentIndex: 2, userId: widget.userId),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.black87, size: 24),
        ),
      ],
    );
  }
}
