import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_4/widgets/user_footer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// เพิ่มบรรทัดนี้ด้านบน
import 'package:flutter_application_4/page/address_book.dart';

class ProfilePage extends StatefulWidget {
  final String userId; // ✅ รับ userId จาก Login/FooterNavBar
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _brandRed = Color(0xFFE96356);

  final _picker = ImagePicker();
  XFile? _avatar;

  void _openAddressBook() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddressBookPage(userId: widget.userId)),
    );
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Login()),
      (route) => false,
    );
  }

  /// ✅ ดึงข้อมูล user จาก Firestore โดยใช้ userId
  Future<Map<String, dynamic>?> _getUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('user')
        .doc(widget.userId)
        .get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("ไม่พบข้อมูลผู้ใช้"));
          }

          final user = snapshot.data!;
          final name = user['name'] ?? '-';
          final phone = user['phone'] ?? '-';
          final picture = user['picture']; // ถ้ามีเก็บ URL/base64

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
                        'โปรไฟล์คุณ',
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

                                    // สมุดที่อยู่
                                    _InfoRow(
                                      label: 'สมุดที่อยู่',
                                      valueWidget: TextButton.icon(
                                        onPressed: _openAddressBook,
                                        icon: const SizedBox(),
                                        label: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'เลือก',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            SizedBox(width: 2),
                                            Icon(
                                              Icons.chevron_right,
                                              size: 24,
                                              color: Colors.black,
                                            ),
                                          ],
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 36),

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
      // ✅ ส่ง userId ให้ Footer ด้วย
      bottomNavigationBar: FooterNavBar(currentIndex: 4, userId: widget.userId),
    );
  }
}

/// แถวข้อมูล (label + ค่า)
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
