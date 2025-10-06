import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/jobs.dart';
import 'package:flutter_application_4/page/profile_rider.dart';

const Color kBrandRed = Color(0xFFE96356);

class RiderFooterItem {
  const RiderFooterItem(this.label, this.baseNumber);
  final String label;
  final int baseNumber;
}

class RiderFooterNavBar extends StatelessWidget {
  final String userId; // ✅ เก็บ userId
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<WidgetBuilder> pageBuilders;

  const RiderFooterNavBar._internal({
    super.key,
    required this.userId,
    this.currentIndex = 0,
    this.onTap,
    required this.pageBuilders,
  });

  /// ✅ Factory Constructor ใช้เพื่อคำนวณ pageBuilders หลังจากได้ userId แล้ว
  factory RiderFooterNavBar({
    Key? key,
    required String userId,
    int currentIndex = 0,
    ValueChanged<int>? onTap,
    List<WidgetBuilder>? pageBuilders,
  }) {
    return RiderFooterNavBar._internal(
      key: key,
      userId: userId,
      currentIndex: currentIndex,
      onTap: onTap,
      pageBuilders: pageBuilders ?? _defaultPageBuilders(userId),
    );
  }

  static const _items = <RiderFooterItem>[
    RiderFooterItem('ดูงาน', 12),
    RiderFooterItem('ประวัติ', 7),
    RiderFooterItem('ยานพาหนะ', 14),
    RiderFooterItem('โปรไฟล์', 9),
  ];

  /// ✅ ฟังก์ชันสร้างเพจ พร้อมส่ง userId
  static List<WidgetBuilder> _defaultPageBuilders(String userId) => [
        (ctx) => JobsPage(userId: userId),        // ✅ ส่ง userId
        (ctx) => JobsPage(userId: userId),        // TODO: HistoryPage
        (ctx) => JobsPage(userId: userId),        // TODO: VehiclePage
        (ctx) => ProfileRiderPage(userId: userId) // ✅ ส่ง userId
      ];

  String _iconPath(int base, bool active) =>
      'assets/Icons/${active ? base + 1 : base}.png';

  void _handleTap(BuildContext context, int index) {
    if (index >= 0 && index < pageBuilders.length) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: pageBuilders[index]),
      );
    }
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
