import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart'; // ✅ ใช้ lowercase
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileRiderPage extends StatefulWidget {
  final String userId; // ✅ รับ userId จาก Login
  const ProfileRiderPage({super.key, required this.userId});

  @override
  State<ProfileRiderPage> createState() => _ProfileRiderPageState();
}

class _ProfileRiderPageState extends State<ProfileRiderPage> {
  static const _brandRed = Color(0xFFE96356);

  final _picker = ImagePicker();
  XFile? _avatar;

  late Future<Map<String, dynamic>?> _futureRider; // ✅ เก็บ future

  @override
  void initState() {
    super.initState();
    _futureRider = _getRiderData();
  }

  /// ✅ ดึงข้อมูล Rider จาก Firestore
  Future<Map<String, dynamic>?> _getRiderData() async {
    final doc = await FirebaseFirestore.instance
        .collection('user') // ถ้า rider แยก collection ต้องแก้ตรงนี้
        .doc(widget.userId)
        .get();

    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  void _openAddressBook() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ไปสมุดที่อยู่ (TODO)')));
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Login()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _futureRider,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("ไม่พบข้อมูลไรเดอร์"));
          }

          final rider = snapshot.data!;
          final name = rider['name'] ?? '-';
          final phone = rider['phone'] ?? '-';
          final picture = rider['picture']; // ✅ URL จาก Firestore

          return Stack(
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
                        'โปรไฟล์ไรเดอร์',
                        style: TextStyle(
                          fontSize: 28,
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

                    // การ์ดข้อมูล
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.black54,
                                  width: 1.5,
                                ),
                              ),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  20,
                                  18,
                                  20,
                                ),
                                child: Column(
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      radius: 64,
                                      backgroundColor: const Color(0xFF0F5CA6),
                                      backgroundImage:
                                          (picture != null && picture != "")
                                          ? NetworkImage(picture)
                                                as ImageProvider
                                          : null,
                                      child: (picture == null || picture == "")
                                          ? const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 72,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'รูปโปรไฟล์',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 22),

                                    // เบอร์โทร
                                    _InfoRow(label: 'เบอร์โทร :', value: phone),
                                    const SizedBox(height: 18),

                                    // ชื่อ - นามสกุล
                                    _InfoRow(
                                      label: 'ชื่อ - นามสกุล :',
                                      value: name,
                                    ),
                                    const SizedBox(height: 18),

                                    // Logout button
                                    SizedBox(
                                      width: 220,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _brandRed,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: Colors.black.withOpacity(
                                                0.35,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          elevation: 6,
                                          shadowColor: Colors.black45,
                                        ),
                                        onPressed: _logout,
                                        child: const Text(
                                          'ออกจากระบบ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
          );
        },
      ),
      // ✅ ส่ง userId ให้ RiderFooterNavBar ด้วย
      bottomNavigationBar: RiderFooterNavBar(
        currentIndex: 3,
        userId: widget.userId,
      ),
    );
  }
}

/// แถวข้อมูลกรอบโค้ง
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.valueWidget})
    : assert(
        value != null || valueWidget != null,
        'ต้องใส่ value หรือ valueWidget อย่างน้อยหนึ่งตัว',
      );

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black54, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          valueWidget ??
              Text(
                value!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
        ],
      ),
    );
  }
}
