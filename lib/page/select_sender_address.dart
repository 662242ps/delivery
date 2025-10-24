import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SenderPickResult {
  final String senderUserId; // delivery.userid_sender
  final String senderPhone;  // user.phone
  final String senderName;   // user.name
  final String addressId;    // user_address (doc id)
  final String address;      // user_address.address
  final double? lat;         // user_address.lat
  final double? lng;         // user_address.lng

  const SenderPickResult({
    required this.senderUserId,
    required this.senderPhone,
    required this.senderName,
    required this.addressId,
    required this.address,
    required this.lat,
    required this.lng,
  });

  String get displayText => 'ชื่อ $senderName | เบอร์ $senderPhone\n$address';
}

class SelectSenderAddressPage extends StatefulWidget {
  final String userId; // ผู้ส่ง = ผู้ใช้ที่ล็อกอิน
  const SelectSenderAddressPage({super.key, required this.userId});

  @override
  State<SelectSenderAddressPage> createState() => _SelectSenderAddressPageState();
}

class _SelectSenderAddressPageState extends State<SelectSenderAddressPage> {
  static const _brandRed = Color(0xFFE96356);
  static const _panelOpacity = 0.90;

  static const USERS = 'user';
  static const USER_ADDR = 'user_address';

  bool _loading = true;
  String? _name;
  String? _phone;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _addrDocs = [];

  @override
  void initState() {
    super.initState();
    _loadAllAddresses();
  }

  Future<void> _loadAllAddresses() async {
    setState(() => _loading = true);
    try {
      // 1) โปรไฟล์ผู้ส่ง
      final userDoc =
          await FirebaseFirestore.instance.collection(USERS).doc(widget.userId).get();
      _name = (userDoc.data()?['name'] ?? 'ผู้ใช้').toString();
      _phone = (userDoc.data()?['phone'] ?? '').toString();

      // 2) ที่อยู่ทั้งหมดของผู้ส่ง
      final addrSnap = await FirebaseFirestore.instance
          .collection(USER_ADDR)
          .where('userid', isEqualTo: widget.userId)
          .get();
      _addrDocs = addrSnap.docs;

      if (_addrDocs.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยังไม่มีที่อยู่ของคุณ กรุณาเพิ่มที่อยู่ก่อน')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final address = (d['address'] ?? '').toString();
    final lat = (d['lat'] is num) ? (d['lat'] as num).toDouble() : null;
    final lng = (d['lng'] is num) ? (d['lng'] as num).toDouble() : null;

    Navigator.pop(
      context,
      SenderPickResult(
        senderUserId: widget.userId,
        senderPhone: _phone ?? '',
        senderName: _name ?? 'ผู้ใช้',
        addressId: doc.id,
        address: address,
        lat: lat,
        lng: lng,
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
            child: Image.asset(
              'assets/images/พื้นหลังแอพ.png',
              fit: BoxFit.cover,
            ),
          ),
          // เกรเดียนท์ทับให้ตัวหนังสืออ่านง่ายขึ้น
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
                // Header (แถบแดง)
                Container(
                  decoration: const BoxDecoration(
                    color: _brandRed,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'เลือกที่อยู่ของคุณ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            shadows: [
                              Shadow(blurRadius: 2, offset: Offset(1, 1), color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // แผงรายการแบบ glassmorphism
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(_panelOpacity),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black45, width: 1.5),
                          ),
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _addrDocs.isEmpty
                                  ? const Center(child: Text('ยังไม่มีที่อยู่ของคุณ'))
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                      itemCount: _addrDocs.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (ctx, i) {
                                        final d = _addrDocs[i].data();
                                        final addr = (d['address'] ?? '').toString();
                                        final lat = d['lat'];
                                        final lng = d['lng'];

                                        return InkWell(
                                          onTap: () => _pick(_addrDocs[i]),
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.95),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.black26, width: 1.2),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  offset: Offset(2, 3),
                                                  blurRadius: 6,
                                                )
                                              ],
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const CircleAvatar(
                                                  radius: 18,
                                                  child: Icon(Icons.home),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // บรรทัดบน: ชื่อ | เบอร์
                                                      RichText(
                                                        text: TextSpan(
                                                          style: const TextStyle(
                                                            color: Colors.black,
                                                            height: 1.35,
                                                          ),
                                                          children: [
                                                            const TextSpan(
                                                              text: 'ชื่อ ',
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.w900,
                                                              ),
                                                            ),
                                                            TextSpan(text: _name ?? '-'),
                                                            const TextSpan(text: '  |  '),
                                                            const TextSpan(
                                                              text: 'เบอร์ ',
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.w900,
                                                              ),
                                                            ),
                                                            TextSpan(text: _phone ?? '-'),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      // บรรทัดล่าง: ที่อยู่เต็ม
                                                      Text(addr, style: const TextStyle(fontSize: 14.5)),
                                                      const SizedBox(height: 2),
                                                      if (lat is num && lng is num)
                                                        Text(
                                                          '(${(lat as num).toDouble().toStringAsFixed(5)}, ${(lng as num).toDouble().toStringAsFixed(5)})',
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.black54,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(Icons.chevron_right),
                                              ],
                                            ),
                                          ),
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
    );
  }
}
