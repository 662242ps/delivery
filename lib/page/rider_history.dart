// rider_history_page.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// โมเดล/ยูทิลของโปรเจกต์คุณ (มีอยู่แล้ว)
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/utils/delivery_status.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/page/user_delivery_detail.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart';

class RiderHistoryPage extends StatefulWidget {
  final String userId;
  const RiderHistoryPage({super.key, required this.userId});

  @override
  State<RiderHistoryPage> createState() => _RiderHistoryPageState();
}

class _RiderHistoryPageState extends State<RiderHistoryPage> {
  static const _brandRed = Color(0xFFE96356);
  final _db = FirebaseFirestore.instance;
  final _lookup = DeliveryLookupCache();

  // cache ชื่อ/เบอร์ของผู้ส่ง (อ่านจาก collection 'user')
  final Map<String, String> _nameCache = {};
  final Map<String, String> _phoneCache = {};

  Future<String> _loadUserName(String userId) async {
    if (userId.isEmpty) return '-';
    if (_nameCache.containsKey(userId)) return _nameCache[userId]!;
    final snap = await _db.collection('user').doc(userId).get();
    final name = (snap.data()?['name'] ?? '-').toString();
    _nameCache[userId] = name;
    return name;
  }

  Future<String> _loadUserPhone(String userId) async {
    if (userId.isEmpty) return '-';
    if (_phoneCache.containsKey(userId)) return _phoneCache[userId]!;
    final snap = await _db.collection('user').doc(userId).get();
    final phone = (snap.data()?['phone'] ?? '-').toString();
    _phoneCache[userId] = phone;
    return phone;
  }

  // แปลง dynamic -> int ปลอดภัย (สำหรับ deliveryid, amount)
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// งานของไรเดอร์ (riderid = userId) ที่สถานะ "เสร็จแล้ว"
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _completedStream() {
    return _db
        .collection('delivery')
        .where('riderid', isEqualTo: widget.userId)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.where((doc) {
        final st = DeliveryStatus.normalize(doc.data()['status']?.toString());
        return DeliveryStatus.isCompleted(st); // เช่น 'ไรเดอร์นำส่งสินค้าแล้ว'
      }).toList();

      // เรียงตามหมายเลขงาน (deliveryid เป็น number) มาก -> น้อย
      docs.sort((a, b) {
        final ai = _toInt(a.data()['deliveryid']);
        final bi = _toInt(b.data()['deliveryid']);
        return bi.compareTo(ai);
      });

      return docs;
    });
  }

  void _openDetail(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final record = DeliveryRecord(doc);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDeliveryDetailPage(record: record, lookup: _lookup),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // พื้นหลังภาพ
          Positioned.fill(
            child: Image.asset('assets/images/พื้นหลังแอพ.png', fit: BoxFit.cover),
          ),
          // เกรเดียนท์ทับให้อ่านง่าย
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
                    border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
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
                        Shadow(blurRadius: 1.5, offset: Offset(0.8, 0.8), color: Colors.white),
                      ],
                    ),
                  ),
                ),

                // Panel รายการ
                Expanded(
                  child: Padding(
                    // ขยับพาเนลลงจากขอบให้เหมือนภาพตัวอย่าง
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                    child: Stack(
                      children: [
                        // ริ้วแดงมุมขวา (ตกแต่ง)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(painter: _DiagonalStripePainter()),
                          ),
                        ),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7).withOpacity(0.96),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.black87, width: 2),
                              ),
                              child: StreamBuilder<
                                  List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                                stream: _completedStream(),
                                builder: (context, snap) {
                                  if (snap.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  if (snap.hasError) {
                                    return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
                                  }

                                  final docs = snap.data ?? const [];
                                  if (docs.isEmpty) {
                                    return const Center(child: Text('ยังไม่มีประวัติที่เสร็จแล้ว'));
                                  }

                                  return ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                                    itemCount: docs.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                                    itemBuilder: (_, i) {
                                      final doc = docs[i];
                                      final d = doc.data();

                                      final deliveryNum = _toInt(d['deliveryid']);
                                      final senderUserId = (d['userid_sender'] ?? '').toString();
                                      final amount = _toInt(d['amount']);
                                      final statusText =
                                          'สถานะ : ${DeliveryStatus.normalize(d['status']?.toString())}';

                                      // โหลดชื่อ/เบอร์ผู้ส่งเพื่อโชว์
                                      return FutureBuilder<List<String>>(
                                        future: Future.wait([
                                          _loadUserName(senderUserId),
                                          _loadUserPhone(senderUserId),
                                        ]),
                                        builder: (context, uSnap) {
                                          String senderName = '...';
                                          String senderPhone = '...';
                                          if (uSnap.hasData &&
                                              uSnap.data != null &&
                                              uSnap.data!.length >= 2) {
                                            senderName = uSnap.data![0];
                                            senderPhone = uSnap.data![1];
                                          }

                                          return _HistoryCard(
                                            title: 'เลขรายการสินค้า $deliveryNum',
                                            sender:
                                                'ผู้ส่ง  ชื่อ $senderName  |  เบอร์ $senderPhone',
                                            qtyText: 'จำนวนสินค้า  $amount  ชิ้น',
                                            statusText: statusText,
                                            onTap: () => _openDetail(doc),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Footer เมนูไรเดอร์ (ตั้ง index ให้ตรงเมนูของคุณ)
      bottomNavigationBar: RiderFooterNavBar(currentIndex: 1, userId: widget.userId),
    );
  }
}

/* ---------- การ์ดแต่ละแถว ---------- */
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black54, width: 1.6),
          boxShadow: const [
            BoxShadow(color: Colors.black12, offset: Offset(2, 3), blurRadius: 5),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // เนื้อหาด้านซ้าย
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sender,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          qtyText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusText,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // 🔻 เปลี่ยนจากกล่องมีพื้นหลัง เป็นไอคอน/ปุ่มไอคอนล้วน ๆ (ไม่มีพื้นหลัง)
            // ตัวเลือก A: ไอคอนล้วน (พึ่งพา InkWell ของทั้งการ์ดในการคลิก)
            // const Icon(Icons.chevron_right, size: 22, color: Colors.black87),

            // ตัวเลือก B: ปุ่มไอคอน (เพิ่ม hit area แต่ยังไม่มีพื้นหลัง)
            IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.chevron_right, size: 22, color: Colors.black87),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              splashRadius: 22,
              tooltip: 'ดูรายละเอียด',
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- พื้นหลังริ้วแดงมุมขวา ---------- */
class _DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE96356).withOpacity(0.45)
      ..style = PaintingStyle.fill;

    final h = size.height;
    final w = size.width;

    Path stripe(Rect r) {
      final p = Path();
      p.moveTo(r.left, r.top);
      p.lineTo(r.right, r.top - 16);
      p.lineTo(r.right, r.bottom - 16);
      p.lineTo(r.left, r.bottom);
      p.close();
      return p;
    }

    // วางริ้วไปทางขวา และโปร่ง ไม่บังตัวหนังสือ
    final dx = w * 0.12;
    final r1 = Rect.fromLTWH(w * 0.68, h * 0.20, dx, h * 0.55);
    final r2 = Rect.fromLTWH(w * 0.82, h * 0.24, dx, h * 0.55);

    canvas.drawPath(stripe(r1), paint);
    canvas.drawPath(stripe(r2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
