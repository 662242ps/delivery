// lib/page/jobs.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_4/page/rider_active_delivery_map.dart';
import 'package:flutter_application_4/page/rider_job_detail.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/utils/delivery_status.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart';

class JobsPage extends StatefulWidget {
  final String userId;
  const JobsPage({super.key, required this.userId});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  static const _brandRed = Color(0xFFE96356);
  final _firestore = FirebaseFirestore.instance;
  final _lookup = DeliveryLookupCache();
  bool _checkingActive = true;

  @override
  void initState() {
    super.initState();
    _checkActiveDelivery();
  }

  /// ✅ พาไป "งานค้าง" โดยดูจาก delivery_assignment.accepted == true
  ///    - เลี่ยง composite index: query เฉพาะ riderid แล้วกรอง accepted ในแอป
  Future<void> _checkActiveDelivery() async {
    try {
      final qs = await _firestore
          .collection('delivery_assignment')
          .where('riderid', isEqualTo: widget.userId)
          .get();

      String? activeDeliveryId;

      for (final doc in qs.docs) {
        final data = doc.data();
        final accepted = (data['accepted'] == true);
        if (!accepted) continue;

        // deliveryid อาจเป็น int หรือ string
        final raw = data['deliveryid'];
        final did = (raw is int) ? raw.toString() : (raw?.toString() ?? '');
        if (did.isEmpty) continue;

        activeDeliveryId = did;

        // (ตัวเลือก) ตรวจสถานะใน delivery ให้ชัวร์ ถ้าอ่านได้
        try {
          final dSnap = await _firestore.collection('delivery').doc(did).get();
          if (dSnap.exists) {
            final status = DeliveryStatus.normalize(
              dSnap.data()?['status']?.toString(),
            );
            // มีงานค้างเฉพาะช่วงกำลังทำงาน
            if (status == DeliveryStatus.riderAccepted ||
                status == DeliveryStatus.riderPickedUp) {
              break; // ใช้ did นี้ได้เลย
            } else if (status == DeliveryStatus.delivered) {
              // ถ้า delivery ปิดแล้วแต่ accepted ยัง true (หลงเหลือ) ให้ข้าม
              activeDeliveryId = null;
            }
          }
        } catch (_) {
          // ถ้าอ่านไม่ได้ก็ยังคงนำทางด้วย did ที่พบ (กรณีข้อมูลไม่สมบูรณ์)
          break;
        }
      }

      if (activeDeliveryId != null && activeDeliveryId!.isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RiderActiveDeliveryMapPage(
              userId: widget.userId,
              deliveryId: activeDeliveryId!,
            ),
          ),
        );
        return;
      }
    } finally {
      if (mounted) setState(() => _checkingActive = false);
    }
  }

  /// ❗ ไม่เรียง (ตัด orderBy) เพื่อเลี่ยง index
  Stream<QuerySnapshot<Map<String, dynamic>>> get _jobsStream => _firestore
      .collection('delivery')
      .where('status', isEqualTo: DeliveryStatus.waitingForRider)
      .snapshots();

  void _openDetail(String deliveryId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RiderJobDetailPage(
          deliveryId: deliveryId,
          userId: widget.userId,
          lookup: _lookup,
        ),
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
                  colors: [Colors.transparent, Colors.black26],
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
                      bottom: BorderSide(color: Colors.black, width: 3),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: const _StrokeText(
                    'รายการงาน',
                    fillColor: Colors.white,
                    strokeColor: Colors.black,
                    strokeWidth: 4,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: Colors.black54, width: 2),
                          ),
                          child: _checkingActive
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: _brandRed,
                                  ),
                                )
                              : StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
                                  stream: _jobsStream,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          color: _brandRed,
                                        ),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            'เกิดข้อผิดพลาด: ${snapshot.error}',
                                          ),
                                        ),
                                      );
                                    }

                                    final records = (snapshot.data?.docs ?? [])
                                        .map((doc) => DeliveryRecord(doc))
                                        .toList();

                                    if (records.isEmpty) {
                                      return const Center(
                                        child: Text('ยังไม่มีงานรอรับ'),
                                      );
                                    }

                                    return ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        16,
                                        24,
                                      ),
                                      itemCount: records.length,
                                      itemBuilder: (context, index) {
                                        final record = records[index];
                                        return _RiderJobCard(
                                          record: record,
                                          lookup: _lookup,
                                          onTap: () => _openDetail(record.id),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: RiderFooterNavBar(
        currentIndex: 0,
        userId: widget.userId,
      ),
    );
  }
}

class _RiderJobCard extends StatelessWidget {
  const _RiderJobCard({
    required this.record,
    required this.lookup,
    required this.onTap,
  });

  final DeliveryRecord record;
  final DeliveryLookupCache lookup;
  final VoidCallback onTap;

  Future<_CardData> _load() async {
    final senderAddr = await lookup.getAddress(record.senderAddressId);
    final receiverAddr = await lookup.getAddress(record.receiverAddressId);
    return _CardData(
      pickup: senderAddr?.address ?? '-',
      dropoff: receiverAddr?.address ?? '-',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CardData>(
      future: _load(),
      builder: (context, snap) {
        final data = snap.data;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black54, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2A000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เลขรายการสินค้า ${record.id}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      _TwoLine(
                        label: 'ที่รับ',
                        value: data?.pickup ?? 'กำลังโหลด...',
                      ),
                      const SizedBox(height: 4),
                      _TwoLine(
                        label: 'ที่ส่ง',
                        value: data?.dropoff ?? 'กำลังโหลด...',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'จำนวนสินค้า ${record.amount ?? '-'} ชิ้น',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 28,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TwoLine extends StatelessWidget {
  const _TwoLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: '$label ',
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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

class _CardData {
  const _CardData({required this.pickup, required this.dropoff});
  final String pickup;
  final String dropoff;
}
