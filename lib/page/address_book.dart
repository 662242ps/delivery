import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/address_detail.dart';
import 'package:flutter_application_4/page/add_address.dart';

class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key, required this.userId});
  final String userId;

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  final _searchCtrl = TextEditingController();
  final _fs = FirebaseFirestore.instance;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // ✅ พื้นหลังเป็นรูป
            Positioned.fill(
              child: Image.asset(
                'assets/images/พื้นหลังแอพ.png',
                fit: BoxFit.cover,
              ),
            ),
            // ✅ ไล่เฉดทับให้ตัวหนังสืออ่านง่าย
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

            // เนื้อหา
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE96356),
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 28,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'ที่อยู่ของคุณ',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            shadows: [
                              Shadow(
                                color: Colors.white,
                                offset: Offset(0, 0),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final added = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddAddressPage(userId: widget.userId),
                            ),
                          );

                          // ถ้าหน้า AddAddressPage ส่ง true กลับมา แสดงว่าบันทึกเสร็จ
                          if (added == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('เพิ่มที่อยู่เรียบร้อย'),
                              ),
                            );
                            // ถ้าใช้ StreamBuilder รายการจะอัปเดตเอง ไม่ต้อง setState ก็ได้
                            // แต่ถ้าเป็น FutureBuilder ให้เรียก setState(() {}) เพื่อยิง future ใหม่
                            // setState(() {}); // ใช้เฉพาะกรณี FutureBuilder
                          }
                        },
                        child: const Text(
                          'เพิ่มที่อยู่ใหม่',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // กล่องเนื้อหาด้านใน
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFe9e9e9).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Column(
                      children: [
                        // ช่องค้นหา
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'ค้นหารายการด้วยเบอร์',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide(
                                color: Colors.black.withOpacity(0.6),
                                width: 2,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(28),
                              ),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // รายการสมุดที่อยู่
                        Expanded(
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _fs
                                .collection('user_address')
                                .where('userid', isEqualTo: widget.userId)
                                .snapshots(),
                            builder: (context, snapAddr) {
                              if (snapAddr.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapAddr.hasError) {
                                return Center(
                                  child: Text(
                                    'เกิดข้อผิดพลาด: ${snapAddr.error}',
                                  ),
                                );
                              }
                              final addrDocs = snapAddr.data?.docs ?? [];
                              if (addrDocs.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'ยังไม่มีที่อยู่\nกด “เพิ่มที่อยู่ใหม่” ได้เลย',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                );
                              }

                              // โหลดข้อมูล user ปัจจุบัน (ชื่อ/เบอร์) เพื่อแสดงบนการ์ด
                              return FutureBuilder<Map<String, dynamic>?>(
                                future: _fs
                                    .collection('user')
                                    .doc(widget.userId)
                                    .get()
                                    .then((d) => d.data()),
                                builder: (context, snapUser) {
                                  if (snapUser.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final user = snapUser.data ?? {};
                                  final name = (user['name'] ?? '') as String;
                                  final phone = (user['phone'] ?? '') as String;

                                  // ฟิลเตอร์เบอร์โทร (ฝั่ง client)
                                  final q = _searchCtrl.text.trim();
                                  final show =
                                      q.isEmpty ||
                                      phone.replaceAll(' ', '').contains(q);

                                  if (!show) {
                                    return const Center(
                                      child: Text(
                                        'ไม่พบเบอร์ที่ค้นหา',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    itemCount: addrDocs.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 14),
                                    itemBuilder: (context, i) {
                                      final a = addrDocs[i].data();
                                      final address =
                                          (a['address'] ?? '') as String;
                                      // ที่ ListView itemBuilder ใน AddressBookPage
                                      return _AddressCard(
                                        title: 'ที่อยู่ของคุณ',
                                        name: name.isEmpty ? '-' : name,
                                        phone: phone.isEmpty ? '-' : phone,
                                        address: address,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => AddressDetailPage(
                                                name: name,
                                                phone: phone,
                                                fullAddress: address,
                                                lat: (a['lat'] as num?)
                                                    ?.toDouble(),
                                                lng: (a['lng'] as num?)
                                                    ?.toDouble(),
                                                addressDocId: addrDocs[i].id,
                          
                                                fromAddressBook:
                                                    true, // ✅ จะมีปุ่มแก้ไข

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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.title,
    required this.name,
    required this.phone,
    required this.address,
    this.onTap,
  });

  final String title;
  final String name;
  final String phone;
  final String address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F1F1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black54, width: 1.6),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // เนื้อหาซ้าย
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                          children: [
                            const TextSpan(text: 'ชื่อ '),
                            TextSpan(
                              text: name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const TextSpan(text: '  |  เบอร์ '),
                            TextSpan(
                              text: phone,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        address,
                        style: const TextStyle(
                          color: Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right,
                    size: 28,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
