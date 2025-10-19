import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ผลลัพธ์ที่ส่งกลับไปหน้าเดิม (ใช้เก็บลง delivery ตาม ER)
class ReceiverPickResult {
  final String receiverUserId; // delivery.userid_receiver
  final String receiverPhone; // delivery.phone_receiver
  final String receiverName; // user.name
  final String
  addressId; // delivery.addressid_receiver (doc id ของ user_address)
  final String address; // user_address.address (ข้อความที่อยู่เต็ม)
  final double? lat; // user_address.lat
  final double? lng; // user_address.lng

  const ReceiverPickResult({
    required this.receiverUserId,
    required this.receiverPhone,
    required this.receiverName,
    required this.addressId,
    required this.address,
    required this.lat,
    required this.lng,
  });

  /// ข้อความโชว์แบบภาพตัวอย่าง
  String get displayText =>
      'ชื่อ $receiverName | เบอร์ $receiverPhone\n$address';
}

class SelectReceiverAddressPage extends StatefulWidget {
  const SelectReceiverAddressPage({super.key});

  @override
  State<SelectReceiverAddressPage> createState() =>
      _SelectReceiverAddressPageState();
}

class _SelectReceiverAddressPageState extends State<SelectReceiverAddressPage> {
  // ===== ตรงกับโครงสร้างในภาพของคุณ =====
  static const String USERS = 'user'; // <<-- เปลี่ยนเป็น 'user' (เอกพจน์)
  static const String USER_ADDR = 'user_address';
  static const String FIELD_USER_NAME = 'name';
  static const String FIELD_USER_PHONE = 'phone';

  // ถ้าเก็บเบอร์เป็นตัวเลขล้วนอยู่แล้ว (เช่น "0987654321" ตามภาพ) ให้เป็น false ก็ได้
  static const bool USE_NORMALIZED = false;

  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _searching = false;

  // state หลังค้นหาผู้ใช้สำเร็จ
  String? _foundUserId;
  String? _foundPhone;
  String? _foundName;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _addrDocs = [];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _searchByPhone() async {
    if (!_formKey.currentState!.validate()) return;

    final input = USE_NORMALIZED
        ? _normalizePhone(_phoneCtrl.text)
        : _phoneCtrl.text.trim();

    setState(() {
      _searching = true;
      _foundUserId = null;
      _foundPhone = null;
      _foundName = null;
      _addrDocs = [];
    });

    try {
      // 1) หา user จากเบอร์  (คอลเลกชัน 'user' ตามภาพ)
      final userSnap = await FirebaseFirestore.instance
          .collection(USERS) // <<-- แก้จาก .collection(user)
          .where(FIELD_USER_PHONE, isEqualTo: input)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบผู้ใช้ที่มีเบอร์นี้')),
          );
        }
        return;
      }

      final userDoc = userSnap.docs.first;
      _foundUserId = userDoc.id;
      _foundPhone = (userDoc.data()[FIELD_USER_PHONE] ?? '').toString();
      _foundName = (userDoc.data()[FIELD_USER_NAME] ?? 'ผู้ใช้').toString();

      // 2) ดึงที่อยู่ทั้งหมดของผู้ใช้นี้จาก 'user_address'
      final addrSnap = await FirebaseFirestore.instance
          .collection(USER_ADDR)
          .where('userid', isEqualTo: _foundUserId)
          .get();

      setState(() => _addrDocs = addrSnap.docs);

      if (addrSnap.docs.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบที่อยู่ของผู้ใช้นี้')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ค้นหาไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pickAddr(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    if (_foundUserId == null || _foundPhone == null || _foundName == null)
      return;

    final d = doc.data();
    final address = (d['address'] ?? '').toString();
    final lat = (d['lat'] is num) ? (d['lat'] as num).toDouble() : null;
    final lng = (d['lng'] is num) ? (d['lng'] as num).toDouble() : null;

    Navigator.pop(
      context,
      ReceiverPickResult(
        receiverUserId: _foundUserId!,
        receiverPhone: _foundPhone!,
        receiverName: _foundName!,
        addressId: doc.id,
        address: address,
        lat: lat,
        lng: lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFE96356);
    const panelBg = Color(0xFFF2F2F2);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black87,
                    Colors.black54,
                    brandRed,
                    Colors.black,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.25, 0.65, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ---------- Header ----------
                Container(
                  decoration: const BoxDecoration(
                    color: brandRed,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.black,
                        ),
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
                                blurRadius: 1.2,
                                offset: Offset(0.8, 0.8),
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // ---------- กล่องค้นหา ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Form(
                    key: _formKey,
                    child: Container(
                      decoration: BoxDecoration(
                        color: panelBg.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black54, width: 1.3),
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: 'ค้นหารายการด้วยเบอร์',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(40),
                                  borderSide: BorderSide(
                                    color: Colors.black.withOpacity(0.25),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(40),
                                  borderSide: BorderSide(
                                    color: Colors.black.withOpacity(0.25),
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(40),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.black87,
                                    width: 1.6,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                final t = USE_NORMALIZED
                                    ? _normalizePhone(v ?? '')
                                    : (v ?? '').trim();
                                if (t.isEmpty)
                                  return 'กรุณาป้อนเบอร์ผู้รับก่อน';
                                if (t.length < 9)
                                  return 'รูปแบบเบอร์ไม่ถูกต้อง';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _searching ? null : _searchByPhone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandRed,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              elevation: 6,
                              shadowColor: Colors.black45,
                            ),
                            child: Text(_searching ? 'กำลังค้นหา...' : 'ค้นหา'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ---------- พาเนลผลลัพธ์ ----------
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    decoration: BoxDecoration(
                      color: panelBg.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black87, width: 1.6),
                    ),
                    child: _addrDocs.isEmpty
                        ? const Center(
                            child: Text(
                              'กรุณาป้อน\nเบอร์ผู้รับก่อน',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(10),
                            itemCount: _addrDocs.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 14),
                            itemBuilder: (ctx, i) {
                              final d = _addrDocs[i].data();
                              final addr = (d['address'] ?? '').toString();
                              final lat = d['lat'];
                              final lng = d['lng'];

                              return InkWell(
                                onTap: () => _pickAddr(_addrDocs[i]),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.black26),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    8,
                                    10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CircleAvatar(
                                        radius: 18,
                                        child: Icon(Icons.home),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
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
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: _foundName ?? '-',
                                                  ),
                                                  const TextSpan(text: '  |  '),
                                                  const TextSpan(
                                                    text: 'เบอร์ ',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: _foundPhone ?? '-',
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              addr,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                              ),
                                            ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
