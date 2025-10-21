// history_page.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart';
// ถ้ามีหน้า detail ให้ uncomment บรรทัดล่างนี้
// import 'package:flutter_application_4/page/delivery_detail_page.dart';

class RiderHistoryPage extends StatefulWidget {
  final String userId;
  const RiderHistoryPage({super.key, required this.userId});

  @override
  State<RiderHistoryPage> createState() => _RiderHistoryPageState();
}

class _RiderHistoryPageState extends State<RiderHistoryPage> {
  static const _brandRed = Color(0xFFE96356);
  final _db = FirebaseFirestore.instance;

  /// สถานะที่จะแสดงในหน้าประวัติ
  static const List<String> _doneStatuses = <String>[
    'ส่งสินค้าสำเร็จ',
    'ไรเดอร์นำส่งสินค้าแล้ว',
    'จัดส่งสำเร็จ',
    'ส่งสินค้าเสร็จสิ้น',
    // ถ้าอยากให้โชว์งานที่ยังไม่จบด้วย ก็เพิ่มไว้ได้:
    'รอไรเดอร์มารับสินค้า',
    'กำลังไปรับสินค้า',
  ];

  // แคชชื่อ/เบอร์
  final Map<String, String> _nameCache = {};
  final Map<String, String> _phoneCache = {};

  Future<String> _loadUserName(String userId) async {
    if (userId.isEmpty) return '-';
    if (_nameCache.containsKey(userId)) return _nameCache[userId]!;
    final snap = await _db.collection('user').doc(userId).get();
    final data = snap.data();
    final name = (data?['name'] ?? '-').toString();
    _nameCache[userId] = name;
    return name;
  }

  Future<String> _loadUserPhone(String userId) async {
    if (userId.isEmpty) return '-';
    if (_phoneCache.containsKey(userId)) return _phoneCache[userId]!;
    final snap = await _db.collection('user').doc(userId).get();
    final data = snap.data();
    final phone = (data?['phone'] ?? '-').toString();
    _phoneCache[userId] = phone;
    return phone;
  }

  /// ดึงงานทั้งหมดของไรเดอร์ แล้วไปกรอง/เรียงในแอป (เลี่ยงทำดัชนีเพิ่ม)
  Stream<QuerySnapshot<Map<String, dynamic>>> _historyStream() {
    return _db
        .collection('delivery')
        .where('riderid', isEqualTo: widget.userId)
        .snapshots();
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
                // Header
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
                    'ประวัติการส่งสินค้า',
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

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.black, width: 1.8),
                          ),
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _historyStream(),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snap.hasError) {
                                return Center(
                                  child: Text('เกิดข้อผิดพลาด: ${snap.error}'),
                                );
                              }

                              // กรองเฉพาะสถานะที่อยากแสดง
                              final allDocs = snap.data?.docs ?? [];
                              final filtered = allDocs.where((e) {
                                final st = (e.data()['status'] ?? '')
                                    .toString();
                                return _doneStatuses.contains(st);
                              }).toList();

                              // เรียงใหม่ตาม updated_at (ใหม่ -> เก่า) ฝั่งแอป
                              filtered.sort((a, b) {
                                final aTs =
                                    (a.data()['updated_at'] as Timestamp?)
                                        ?.millisecondsSinceEpoch ??
                                    0;
                                final bTs =
                                    (b.data()['updated_at'] as Timestamp?)
                                        ?.millisecondsSinceEpoch ??
                                    0;
                                return bTs.compareTo(aTs);
                              });

                              if (filtered.isEmpty) {
                                return const Center(
                                  child: Text('ยังไม่มีประวัติการส่งสินค้า'),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  18,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final doc = filtered[i];
                                  final d = doc.data();
                                  final deliveryId = (d['deliveryid'] ?? doc.id)
                                      .toString();
                                  final senderUserId =
                                      (d['userid_sender'] ?? '').toString();
                                  final amount = d['amount'] is int
                                      ? d['amount'] as int
                                      : int.tryParse('${d['amount']}') ?? 0;
                                  final status = (d['status'] ?? '').toString();

                                  return FutureBuilder<List<String>>(
                                    future: Future.wait([
                                      _loadUserName(senderUserId),
                                      _loadUserPhone(senderUserId),
                                    ]),
                                    builder: (context, userSnap) {
                                      final senderName =
                                          userSnap.data?.elementAtOrNull(0) ??
                                          '...';
                                      final senderPhone =
                                          userSnap.data?.elementAtOrNull(1) ??
                                          '...';

                                      return _HistoryCard(
                                        title: 'เลขรายการสินค้า $deliveryId',
                                        sender:
                                            'ผู้ส่ง  ชื่อ $senderName  |  เบอร์ $senderPhone',
                                        qtyText: 'จำนวนสินค้า  $amount  ชิ้น',
                                        statusText: 'สถานะ : $status',
                                        onTap: () {
                                          // ถ้ามีหน้า DeliveryDetailPage ให้ใช้โค้ดด้านล่าง
                                          // Navigator.push(
                                          //   context,
                                          //   MaterialPageRoute(
                                          //     builder: (_) => DeliveryDetailPage(
                                          //       userId: widget.userId,
                                          //       deliveryDocId: doc.id,
                                          //     ),
                                          //   ),
                                          // );

                                          // ชั่วคราว: ถ้ายังไม่มีหน้า detail
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'เปิดรายละเอียดงาน: $deliveryId',
                                              ),
                                            ),
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
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Footer: แท็บประวัติ = index 1
      bottomNavigationBar: RiderFooterNavBar(
        currentIndex: 1,
        userId: widget.userId,
      ),
    );
  }
}

/* ---------- Card UI ---------- */
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.title,
    required this.sender,
    required this.qtyText,
    required this.statusText,
    required this.onTap,
  });

  final String title;
  final String sender;
  final String qtyText;
  final String statusText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2).withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black54, width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sender,
                  style: const TextStyle(fontSize: 14.5, height: 1.35),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        qtyText,
                        style: const TextStyle(fontSize: 14.5, height: 1.35),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusText,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 14.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.chevron_right, size: 26),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
