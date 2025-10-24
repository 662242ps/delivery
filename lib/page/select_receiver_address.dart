import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReceiverPickResult {
  final String receiverUserId;   // delivery.userid_receiver
  final String receiverPhone;    // delivery.phone_receiver
  final String receiverName;     // user.name
  final String addressId;        // user_address doc id
  final String address;          // user_address.address
  final double? lat;             // user_address.lat
  final double? lng;             // user_address.lng

  const ReceiverPickResult({
    required this.receiverUserId,
    required this.receiverPhone,
    required this.receiverName,
    required this.addressId,
    required this.address,
    required this.lat,
    required this.lng,
  });

  String get displayText => 'ชื่อ $receiverName | เบอร์ $receiverPhone\n$address';
}

/// แสดงทุกที่อยู่ของทุกผู้ใช้ (เลือกได้เลย)
/// - ส่ง excludeUserId เพื่อ “ตัดที่อยู่ของตัวเองออก” (ถ้าไม่ต้องการกรอง ให้ส่ง null)
class SelectReceiverAllAddressesPage extends StatefulWidget {
  const SelectReceiverAllAddressesPage({super.key, this.excludeUserId});

  final String? excludeUserId;

  @override
  State<SelectReceiverAllAddressesPage> createState() =>
      _SelectReceiverAllAddressesPageState();
}

class _SelectReceiverAllAddressesPageState
    extends State<SelectReceiverAllAddressesPage> {
  static const _brandRed = Color(0xFFE96356);
  static const _panelOpacity = 0.90;

  static const USERS = 'user';
  static const USER_ADDR = 'user_address';

  bool _loading = true;

  // เอกสารที่อยู่ทั้งหมด (หลังโหลด/กรอง owner ออก และ sort แล้ว)
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _addrDocs = [];

  // แผนที่ userId -> (name, phone)
  final Map<String, ({String name, String phone})> _userMap = {};

  // ค้นหา
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _digits(String x) => x.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // 1) ดึงทุกที่อยู่
      final addrSnap =
          await FirebaseFirestore.instance.collection(USER_ADDR).get();

      var docs = addrSnap.docs;

      // 2) กรองออก (ตัดของตัวเองทิ้ง ถ้าระบุ excludeUserId)
      if ((widget.excludeUserId ?? '').isNotEmpty) {
        docs = docs
            .where((d) =>
                (d.data()['userid']?.toString() ?? '') != widget.excludeUserId)
            .toList();
      }

      // 3) รวบรวม userIds ที่ต้องใช้
      final userIds = <String>{};
      for (final d in docs) {
        final uid = d.data()['userid']?.toString();
        if (uid != null && uid.isNotEmpty) userIds.add(uid);
      }

      // 4) ดึงข้อมูลผู้ใช้เฉพาะที่จำเป็น แล้วใส่ลง _userMap
      await Future.wait(userIds.map((uid) async {
        final snap =
            await FirebaseFirestore.instance.collection(USERS).doc(uid).get();
        final data = snap.data() ?? {};
        _userMap[uid] = (
          name: (data['name'] ?? 'ผู้ใช้').toString(),
          phone: (data['phone'] ?? '').toString(),
        );
      }));

      // 5) เรียงผลลัพธ์: ตาม phone -> name -> address
      docs.sort((a, b) {
        final da = a.data();
        final db = b.data();
        final ua = _userMap[da['userid']?.toString()] ?? (name: '-', phone: '');
        final ub = _userMap[db['userid']?.toString()] ?? (name: '-', phone: '');
        final pa = ua.phone;
        final pb = ub.phone;
        final na = ua.name;
        final nb = ub.name;
        final aa = (da['address'] ?? '').toString();
        final ab = (db['address'] ?? '').toString();

        final p = pa.compareTo(pb);
        if (p != 0) return p;
        final n = na.compareTo(nb);
        if (n != 0) return n;
        return aa.compareTo(ab);
      });

      setState(() => _addrDocs = docs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // รายการหลังกรองด้วยข้อความค้นหา (ค้นหาเฉพาะ "เบอร์")
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filteredDocs {
    if (_query.isEmpty) return _addrDocs;
    final q = _digits(_query);
    return _addrDocs.where((doc) {
      final uid = (doc.data()['userid'] ?? '').toString();
      final phone = _userMap[uid]?.phone ?? '';
      return _digits(phone).contains(q);
    }).toList();
  }

  void _pick(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final userId = (d['userid'] ?? '').toString();
    final u = _userMap[userId] ?? (name: 'ผู้ใช้', phone: '');
    final address = (d['address'] ?? '').toString();
    final lat = (d['lat'] is num) ? (d['lat'] as num).toDouble() : null;
    final lng = (d['lng'] is num) ? (d['lng'] as num).toDouble() : null;

    Navigator.pop(
      context,
      ReceiverPickResult(
        receiverUserId: userId,
        receiverPhone: u.phone,
        receiverName: u.name,
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
            child:
                Image.asset('assets/images/พื้นหลังแอพ.png', fit: BoxFit.cover),
          ),
          // เกรเดียนท์ทับให้อ่านง่าย
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
                // Header
                Container(
                  decoration: const BoxDecoration(
                    color: _brandRed,
                    border:
                        Border(bottom: BorderSide(color: Colors.black, width: 2)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'เลือกที่อยู่ผู้รับ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            shadows: [
                              Shadow(
                                  blurRadius: 2,
                                  offset: Offset(1, 1),
                                  color: Colors.white)
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // กล่องค้นหาเบอร์
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.black45, width: 1.2),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: TextField(
                          controller: _searchCtrl,
                          keyboardType: TextInputType.phone,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'ค้นหาด้วยเบอร์ผู้รับ',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(40),
                              borderSide:
                                  BorderSide(color: Colors.black.withOpacity(0.25)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(40),
                              borderSide:
                                  BorderSide(color: Colors.black.withOpacity(0.25)),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(40)),
                              borderSide:
                                  BorderSide(color: Colors.black87, width: 1.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // แผงรายการทั้งหมด
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                              : _filteredDocs.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'กรุณาป้อนเบอร์ผู้รับหรือยังไม่มีรายการ',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 12, 12, 12),
                                      itemCount: _filteredDocs.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (ctx, i) {
                                        final doc = _filteredDocs[i];
                                        final d = doc.data();
                                        final uid =
                                            (d['userid'] ?? '').toString();
                                        final u = _userMap[uid] ??
                                            (name: '-', phone: '');
                                        final addr =
                                            (d['address'] ?? '').toString();
                                        final lat = d['lat'];
                                        final lng = d['lng'];

                                        // แทรกหัวข้อเมื่อ "เบอร์" เปลี่ยน
                                        final prevPhone = (i > 0)
                                            ? (_userMap[_filteredDocs[i - 1]
                                                            .data()['userid']
                                                            ?.toString()]
                                                    ?.phone ??
                                                '')
                                            : '';
                                        final showHeader = u.phone != prevPhone;

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (showHeader)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 4, bottom: 6, top: 2),
                                                child: Text(
                                                  'เบอร์: ${u.phone.isEmpty ? "-" : u.phone}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            InkWell(
                                              onTap: () => _pick(doc),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        12, 12, 10, 12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.95),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                      color: Colors.black26,
                                                      width: 1.2),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                        color: Colors.black12,
                                                        offset: Offset(2, 3),
                                                        blurRadius: 6),
                                                  ],
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const CircleAvatar(
                                                        radius: 18,
                                                        child: Icon(Icons.home)),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          RichText(
                                                            text: TextSpan(
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .black,
                                                                  height: 1.35),
                                                              children: [
                                                                const TextSpan(
                                                                  text: 'ชื่อ ',
                                                                  style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900),
                                                                ),
                                                                TextSpan(
                                                                    text:
                                                                        u.name),
                                                                const TextSpan(
                                                                    text:
                                                                        '  |  '),
                                                                const TextSpan(
                                                                  text: 'เบอร์ ',
                                                                  style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900),
                                                                ),
                                                                TextSpan(
                                                                    text: u.phone
                                                                            .isEmpty
                                                                        ? '-'
                                                                        : u.phone),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(addr,
                                                              style: const TextStyle(
                                                                  fontSize:
                                                                      14.5)),
                                                          const SizedBox(
                                                              height: 2),
                                                          if (lat is num &&
                                                              lng is num)
                                                            Text(
                                                              '(${(lat as num).toDouble().toStringAsFixed(5)}, ${(lng as num).toDouble().toStringAsFixed(5)})',
                                                              style: const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .black54),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    const Icon(
                                                        Icons.chevron_right),
                                                  ],
                                                ),
                                              ),
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
            ),
          ),
        ],
      ),
    );
  }
}
