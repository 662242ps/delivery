import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/jobs.dart';
import 'package:flutter_application_4/page/profile.dart';

const Color kBrandRed = Color(0xFFE96356);

class RiderFooterItem {
  const RiderFooterItem(this.label, this.baseNumber);
  final String label;
  final int baseNumber;
}

class RiderFooterNavBar extends StatelessWidget {
  const RiderFooterNavBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
    this.pageBuilders,
  });

  /// แท็บที่ active อยู่ (0=ดูงาน, 1=ประวัติ, 2=ยานพาหนะ, 3=โปรไฟล์)
  final int currentIndex;

  /// callback ถ้าอยากจัดการ state เอง (จะไม่ถูกเรียกเมื่อมีการนำทางด้วย pageBuilders)
  final ValueChanged<int>? onTap;

  /// ถ้า null จะใช้ชุดดีฟอลต์ด้านล่างนี้ให้อัตโนมัติ
  final List<WidgetBuilder>? pageBuilders;

  static const _items = <RiderFooterItem>[
    RiderFooterItem('ดูงาน', 12),
    RiderFooterItem('ประวัติ', 7),
    RiderFooterItem('ยานพาหนะ', 14),
    RiderFooterItem('โปรไฟล์', 9),
  ];

  /// ดีฟอลต์: ไปยัง 4 หน้าตามที่ระบุ
  static final List<WidgetBuilder> _defaultPageBuilders = <WidgetBuilder>[
    (ctx) => const JobsPage(), // ดูงาน
    (ctx) => const JobsPage(),
    (ctx) => const JobsPage(),
    (ctx) => const ProfilePage(),
    // (ctx) => const RiderHistoryPage(), // ประวัติ
    // (ctx) => const VehiclePage(), // ยานพาหนะ
    // (ctx) => const ProfilePage(), // โปรไฟล์
  ];

  String _iconPath(int base, bool active) =>
      'assets/Icons/${active ? base + 1 : base}.png';

  void _handleTap(BuildContext context, int index) {
    final builders = pageBuilders ?? _defaultPageBuilders;
    // ถ้ามีครบ 4 ตัว: นำทางด้วย Navigator (แทนการเรียก onTap)
    if (builders.length == _items.length) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: builders[index]));
      return;
    }
    // ไม่ได้ให้ builders ครบ → ส่ง index กลับไปให้หน้าปัจจุบันจัดการเอง
    onTap?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = (currentIndex < 0 || currentIndex >= _items.length)
        ? 0
        : currentIndex;

    return SafeArea(
      top: false,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: kBrandRed, width: 4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: List.generate(_items.length, (i) {
            final it = _items[i];
            final active = i == safeIndex;

            return Expanded(
              child: InkWell(
                onTap: () => _handleTap(context, i),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      it.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active ? kBrandRed : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: active ? kBrandRed : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        _iconPath(it.baseNumber, active),
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.black38,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
