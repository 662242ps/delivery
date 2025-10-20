import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/utils/delivery_status.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart';

class RiderHistoryPage extends StatefulWidget {
  const RiderHistoryPage({super.key, required this.userId});

  final String userId;

  @override
  State<RiderHistoryPage> createState() => _RiderHistoryPageState();
}

class _RiderHistoryPageState extends State<RiderHistoryPage> {
  final _lookup = DeliveryLookupCache();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _historyStream =>
      FirebaseFirestore.instance
          .collection('delivery')
          .where('riderid', isEqualTo: widget.userId)
          .where('status', isEqualTo: DeliveryStatus.delivered)
          .orderBy('updated_at', descending: true)
          .snapshots();

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
                    color: Color(0xFFE96356),
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: const Text(
                    'ประวัติการจัดส่ง',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.black54, width: 1.6),
                          ),
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _historyStream,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                                );
                              }
                              final records = (snapshot.data?.docs ?? [])
                                  .map((doc) => DeliveryRecord(doc))
                                  .toList();
                              if (records.isEmpty) {
                                return const Center(
                                  child: Text('ยังไม่มีประวัติการจัดส่ง'),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                itemCount: records.length,
                                itemBuilder: (context, index) {
                                  final record = records[index];
                                  return _RiderHistoryCard(
                                    record: record,
                                    lookup: _lookup,
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
        currentIndex: 1,
        userId: widget.userId,
      ),
    );
  }
}

class _RiderHistoryCard extends StatelessWidget {
  const _RiderHistoryCard({required this.record, required this.lookup});

  final DeliveryRecord record;
  final DeliveryLookupCache lookup;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserSummary?>(
      future: lookup.getUser(record.senderId),
      builder: (context, snapshot) {
        final sender = snapshot.data;
        final senderName = record.senderName?.isNotEmpty == true
            ? record.senderName!
            : sender?.name ?? '-';
        final senderPhone = record.senderPhone?.isNotEmpty == true
            ? record.senderPhone!
            : sender?.phone ?? '-';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black45, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
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
              Text(
                'ผู้ส่ง $senderName | เบอร์ $senderPhone',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'จำนวนสินค้า ${record.amount} ชิ้น',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'สถานะ ${DeliveryStatus.normalize(record.status)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
