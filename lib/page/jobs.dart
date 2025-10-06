import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart';

class JobsPage extends StatefulWidget {
  final String userId; // ✅ รับ userId จาก login/footer
  const JobsPage({super.key, required this.userId});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  static const _brandRed = Color(0xFFE96356);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // พื้นหลัง
          Positioned.fill(
            child: Image.asset(
              'assets/images/พื้นหลังแอพ.png',
              fit: BoxFit.cover,
            ),
          ),
          // ไล่โทนให้อ่านง่าย
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
                // Header แดง
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
                    'รายการงาน',
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

                // การ์ดโปร่งใสสไตล์เดียวกับ send_product_page
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
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
                          child: Scrollbar(
                            thickness: 6,
                            radius: const Radius.circular(12),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                18,
                              ),
                              children: const [
                                _JobCard(
                                  title: 'เลขรายการสินค้า xxx',
                                  from:
                                      'ที่รับ 101/1 ตำบล กกกอก อำเภอ บนฟ้า จังหวัด ...',
                                  to: 'ที่ส่ง 65/2 ตำบล กกกอก อำเภอ บนฟ้า จังหวัด ...',
                                  qty: 'xx ชิ้น',
                                ),
                                _JobCard(
                                  title: 'เลขรายการสินค้า xxx',
                                  from:
                                      'ที่รับ 101/1 ตำบล กกกอก อำเภอ บนฟ้า จังหวัด ...',
                                  to: 'ที่ส่ง 56/4 ตำบล กกกอก อำเภอ บนฟ้า จังหวัด ...',
                                  qty: 'xx ชิ้น',
                                ),
                                _JobCard(
                                  title: 'เลขรายการสินค้า xxx',
                                  from:
                                      'ที่รับ 65/1 ตำบล กกกอก อำเภอ บนฟ้า จังหวัด ...',
                                  to: 'ที่ส่ง 101/1 ตำบล กกกอก อำเภอ บนฟ้า จังหวัด ...',
                                  qty: 'xx ชิ้น',
                                ),
                                SizedBox(height: 6),
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
      ),

      // ฟุตเตอร์ของไรเดอร์ (แท็บที่ 0 = ดูงาน)
      bottomNavigationBar: RiderFooterNavBar(
        currentIndex: 0,
        userId: widget.userId, // ✅ ส่ง userId ต่อไป
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.title,
    required this.from,
    required this.to,
    required this.qty,
  });

  final String title;
  final String from;
  final String to;
  final String qty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black54, width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ข้อความ
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
                  from,
                  style: const TextStyle(fontSize: 14.5, height: 1.35),
                ),
                const SizedBox(height: 2),
                Text(to, style: const TextStyle(fontSize: 14.5, height: 1.35)),
                const SizedBox(height: 6),
                Text(
                  'จำนวนสินค้า $qty',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // ปุ่ม >
          IconButton(
            onPressed: () {
              // TODO: ไปหน้ารายละเอียดงาน
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('เปิดรายละเอียดงาน (TODO)')),
              );
            },
            icon: const Icon(Icons.chevron_right, size: 26),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
