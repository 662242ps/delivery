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

  Future<void> _checkActiveDelivery() async {
    try {
      final snapshot = await _firestore
          .collection('delivery')
          .where('riderid', isEqualTo: widget.userId)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = DeliveryStatus.normalize(data['status']?.toString());
        if (DeliveryStatus.isMapRelated(status) &&
            status != DeliveryStatus.waitingForRider) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RiderActiveDeliveryMapPage(
                userId: widget.userId,
                deliveryId: doc.id,
              ),
            ),
          );
          return;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _checkingActive = false);
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _jobsStream => _firestore
      .collection('delivery')
      .where('status', isEqualTo: DeliveryStatus.waitingForRider)
      .orderBy('created_at', descending: true)
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: const Text(
                    'รายการงาน',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.82),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.black54, width: 1.6),
                          ),
                          child: _checkingActive
                              ? const Center(child: CircularProgressIndicator())
                              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                  stream: _jobsStream,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                            'เกิดข้อผิดพลาด: ${snapshot.error}'),
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
                                        18,
                                        16,
                                        18,
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
    final senderAddress = await lookup.getAddress(record.senderAddressId);
    final receiverAddress = await lookup.getAddress(record.receiverAddressId);
    final sender = await lookup.getUser(record.senderId);
    final receiver = await lookup.getUser(record.receiverId);
    return _CardData(
      senderText:
          '${sender?.name ?? record.senderName ?? '-'} | ${sender?.phone ?? record.senderPhone ?? '-'}',
      receiverText:
          '${receiver?.name ?? record.receiverName ?? '-'} | ${receiver?.phone ?? record.receiverPhone ?? '-'}',
      pickup: senderAddress?.address ?? '-',
      dropoff: receiverAddress?.address ?? '-',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CardData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black45, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เลขรายการสินค้า ${record.id}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text('ผู้ส่ง: ${data?.senderText ?? 'กำลังโหลด...'}'),
                const SizedBox(height: 4),
                Text('ผู้รับ: ${data?.receiverText ?? 'กำลังโหลด...'}'),
                const SizedBox(height: 6),
                Text('จุดรับ: ${data?.pickup ?? 'กำลังโหลด...'}'),
                const SizedBox(height: 4),
                Text('จุดส่ง: ${data?.dropoff ?? 'กำลังโหลด...'}'),
                const SizedBox(height: 6),
                Text('จำนวนสินค้า: ${record.amount} ชิ้น'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Icon(Icons.chevron_right, color: Colors.black),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardData {
  const _CardData({
    required this.senderText,
    required this.receiverText,
    required this.pickup,
    required this.dropoff,
  });

  final String senderText;
  final String receiverText;
  final String pickup;
  final String dropoff;
}
