import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileRiderPage extends StatefulWidget {
  final String userId; // ✅ id ของไรเดอร์
  final bool hideChrome; // ✅ true = ซ่อนปุ่มออกจากระบบ + footer

  const ProfileRiderPage({
    super.key,
    required this.userId,
    this.hideChrome = false,
  });

  @override
  State<ProfileRiderPage> createState() => _ProfileRiderPageState();
}

class _ProfileRiderPageState extends State<ProfileRiderPage> {
  static const _brandRed = Color(0xFFE96356);

  final _picker = ImagePicker();
  XFile? _avatar;

  late Future<Map<String, dynamic>?> _futureRider;

  @override
  void initState() {
    super.initState();
    _futureRider = _getRiderData();
  }

  Future<Map<String, dynamic>?> _getRiderData() async {
    final doc = await FirebaseFirestore.instance
        .collection('user') // ถ้าคุณแยก collection rider ให้แก้ชื่อนี้
        .doc(widget.userId)
        .get();
    return doc.data();
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
          final name = (rider['name'] ?? '-') as String;
          final phone = (rider['phone'] ?? '-') as String;
          final picture = rider['picture']; // URL

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
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 6,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'โปรไฟล์ไรเดอร์',
                              textAlign: TextAlign.center,
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
                          const SizedBox(width: 48),
                        ],
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

                                    _InfoRow(label: 'เบอร์โทร :', value: phone),
                                    const SizedBox(height: 18),
                                    _InfoRow(
                                      label: 'ชื่อ - นามสกุล :',
                                      value: name,
                                    ),
                                    const SizedBox(height: 18),

                                    // ปุ่มออกจากระบบ — แสดงเฉพาะเมื่อไม่ซ่อน chrome
                                    if (!widget.hideChrome)
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
                                              borderRadius:
                                                  BorderRadius.circular(14),
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

      // footer — แสดงเฉพาะเมื่อไม่ซ่อน chrome
      bottomNavigationBar: widget.hideChrome
          ? null
          : RiderFooterNavBar(currentIndex: 3, userId: widget.userId),
    );
  }
}

/// แถวข้อมูล
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.valueWidget})
    : assert(value != null || valueWidget != null);

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
