import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/rider_active_delivery_map.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/utils/delivery_status.dart';
import 'package:flutter_application_4/utils/location_utils.dart';

class RiderJobDetailPage extends StatefulWidget {
  const RiderJobDetailPage({
    super.key,
    required this.deliveryId,
    required this.userId,
    required this.lookup,
  });

  final String deliveryId;
  final String userId;
  final DeliveryLookupCache lookup;

  @override
  State<RiderJobDetailPage> createState() => _RiderJobDetailPageState();
}

class _RiderJobDetailPageState extends State<RiderJobDetailPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _accepting = false;

  Future<void> _acceptJob(Map<String, dynamic> data) async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      final senderAddress = await widget.lookup.getAddress(
        data['addressid_sender']?.toString(),
      );
      if (senderAddress == null) {
        throw Exception('ไม่พบพิกัดรับสินค้า');
      }

      final position = await LocationUtils.ensureCurrentPosition();
      final within = LocationUtils.isWithinDistance(
        position: position,
        targetLat: senderAddress.lat,
        targetLng: senderAddress.lng,
        maxDistanceMeters: 20,
      );
      if (!within) {
        throw const LocationException(
          'ต้องอยู่ห่างจากจุดรับสินค้าไม่เกิน 20 เมตรเพื่อรับงาน',
        );
      }

      final activeSnapshot = await _firestore
          .collection('delivery')
          .where('riderid', isEqualTo: widget.userId)
          .where('status', whereIn: [
            DeliveryStatus.riderAccepted,
            DeliveryStatus.riderPickedUp,
          ])
          .limit(1)
          .get();
      if (activeSnapshot.docs.isNotEmpty) {
        throw Exception('คุณมีงานที่กำลังจัดส่งอยู่แล้ว');
      }

      await _firestore.runTransaction((transaction) async {
        final docRef =
            _firestore.collection('delivery').doc(widget.deliveryId);
        final snap = await transaction.get(docRef);
        if (!snap.exists) {
          throw Exception('งานนี้ถูกลบไปแล้ว');
        }
        final current = snap.data()!;
        final status = DeliveryStatus.normalize(current['status']?.toString());
        final riderId = current['riderid']?.toString();
        if (riderId != null && riderId.isNotEmpty && riderId != widget.userId) {
          throw Exception('งานนี้มีไรเดอร์รับไปแล้ว');
        }
        if (status != DeliveryStatus.waitingForRider) {
          throw Exception('งานนี้ไม่อยู่ในสถานะรอรับงานแล้ว');
        }
        transaction.update(docRef, {
          'riderid': widget.userId,
          'status': DeliveryStatus.riderAccepted,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RiderActiveDeliveryMapPage(
            userId: widget.userId,
            deliveryId: widget.deliveryId,
          ),
        ),
        (route) => false,
      );
    } on LocationException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
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
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('delivery')
                  .doc(widget.deliveryId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('ไม่พบงานนี้แล้ว'));
                }

                final data = snapshot.data!.data() ?? {};
                final status = DeliveryStatus.normalize(
                  data['status']?.toString(),
                );
                final riderId = data['riderid']?.toString();

                if (riderId == widget.userId &&
                    DeliveryStatus.isMapRelated(status) &&
                    status != DeliveryStatus.waitingForRider) {
                  Future.microtask(() {
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => RiderActiveDeliveryMapPage(
                          userId: widget.userId,
                          deliveryId: widget.deliveryId,
                        ),
                      ),
                    );
                  });
                }

                final amount = data['amount'];
                final detail = data['detail']?.toString() ?? '-';

                return Column(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE96356),
                        border: Border(
                          bottom: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, color: Colors.black),
                          ),
                          const Expanded(
                            child: Text(
                              'รายละเอียดงาน',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.88),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.black54, width: 1.6),
                              ),
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                              child: FutureBuilder<List<_DetailSection>>(
                                future: _buildSections(data),
                                builder: (context, sectionsSnap) {
                                  if (sectionsSnap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final sections = sectionsSnap.data ?? const [];
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'สถานะสินค้า: $status',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: sections.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 14),
                                          itemBuilder: (context, index) {
                                            final section = sections[index];
                                            return _SectionCard(section: section);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text('จำนวนสินค้า: ${amount ?? '-'} ชิ้น'),
                                      const SizedBox(height: 8),
                                      Text('รายละเอียด: $detail'),
                                      const SizedBox(height: 16),
                                      if (status == DeliveryStatus.waitingForRider &&
                                          (riderId == null || riderId.isEmpty))
                                        SizedBox(
                                          width: double.infinity,
                                          height: 54,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFE96356),
                                              foregroundColor: Colors.black,
                                              textStyle: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            onPressed: _accepting
                                                ? null
                                                : () => _acceptJob(data),
                                            child: _accepting
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : const Text('รับงานนี้'),
                                          ),
                                        )
                                      else if (riderId != null &&
                                          riderId.isNotEmpty &&
                                          riderId != widget.userId)
                                        const Text(
                                          'งานนี้ถูกไรเดอร์คนอื่นรับแล้ว',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<_DetailSection>> _buildSections(Map<String, dynamic> data) async {
    final senderUser = await widget.lookup.getUser(
      data['userid_sender']?.toString(),
    );
    final receiverUser = await widget.lookup.getUser(
      data['userid_receiver']?.toString(),
    );
    final senderAddress = await widget.lookup.getAddress(
      data['addressid_sender']?.toString(),
    );
    final receiverAddress = await widget.lookup.getAddress(
      data['addressid_receiver']?.toString(),
    );

    return [
      _DetailSection(
        title: 'ที่อยู่ของผู้ส่ง',
        lines: [
          'ชื่อ: ${senderUser?.name ?? data['sender_name'] ?? '-'}',
          'เบอร์: ${senderUser?.phone ?? data['phone_sender'] ?? '-'}',
          'ที่อยู่: ${senderAddress?.address ?? '-'}',
        ],
      ),
      _DetailSection(
        title: 'ที่อยู่ของผู้รับ',
        lines: [
          'ชื่อ: ${receiverUser?.name ?? data['receiver_name'] ?? '-'}',
          'เบอร์: ${receiverUser?.phone ?? data['phone_receiver'] ?? '-'}',
          'ที่อยู่: ${receiverAddress?.address ?? '-'}',
        ],
      ),
    ];
  }
}

class _DetailSection {
  const _DetailSection({required this.title, required this.lines});
  final String title;
  final List<String> lines;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final _DetailSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black45, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...section.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line),
            ),
          ),
        ],
      ),
    );
  }
}
