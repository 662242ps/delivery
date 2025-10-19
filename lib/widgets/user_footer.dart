// widgets/app_footer.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/profile.dart';
import 'package:flutter_application_4/page/send_product.dart';
import 'package:flutter_application_4/page/user_delivery_history.dart';
import 'package:flutter_application_4/page/user_delivery_in_progress.dart';
import 'package:flutter_application_4/page/user_delivery_map.dart';

const Color kBrandRed = Color(0xFFE96356);

class UserFooterItem {
  const UserFooterItem(this.label, this.baseOddNumber);
  final String label;
  final int baseOddNumber;
}

const List<UserFooterItem> kDefaultUserFooterItems = [
  UserFooterItem('ส่งสินค้า', 1),
  UserFooterItem('กำลังจัดส่ง', 3),
  UserFooterItem('ดูตำแหน่ง', 5),
  UserFooterItem('ประวัติ', 7),
  UserFooterItem('โปรไฟล์', 9),
];

class FooterNavBar extends StatelessWidget {
  FooterNavBar({
    super.key,
    required this.userId, // ✅ ต้องส่ง userId
    this.items = kDefaultUserFooterItems,
    this.currentIndex = 0,
    this.onTap,
    List<WidgetBuilder>? pageBuilders,
    this.usePushReplacement = true,
  }) : pageBuilders = pageBuilders ?? _defaultPageBuilders(userId);

  final String userId; // ✅ เก็บ userId
  final List<UserFooterItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  /// ✅ ค่าเริ่มต้นของเพจปลายทาง (ทุกหน้าใช้ userId)
  static List<WidgetBuilder> _defaultPageBuilders(String userId) => [
        (ctx) => SendProductPage(userId: userId),
        (ctx) => UserDeliveryInProgressPage(userId: userId),
        (ctx) => UserDeliveryMapPage(userId: userId),
        (ctx) => UserDeliveryHistoryPage(userId: userId),
        (ctx) => ProfilePage(userId: userId),
      ];

  final List<WidgetBuilder> pageBuilders;
  final bool usePushReplacement;

  String _iconPath(UserFooterItem it, bool active) {
    final n = active ? it.baseOddNumber + 1 : it.baseOddNumber;
    return 'assets/Icons/$n.png';
  }

  void _handleTap(BuildContext context, int i) {
    onTap?.call(i);
    if (i >= 0 && i < pageBuilders.length) {
      final route = MaterialPageRoute(builder: pageBuilders[i]);
      if (usePushReplacement) {
        Navigator.of(context).pushReplacement(route);
      } else {
        Navigator.of(context).push(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex =
        (currentIndex < 0 || currentIndex >= items.length) ? 0 : currentIndex;

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
          children: List.generate(items.length, (i) {
            final it = items[i];
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
                        _iconPath(it, active),
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.black38,
                          size: 28,
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
