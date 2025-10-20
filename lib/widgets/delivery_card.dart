import 'package:flutter/material.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';

class DeliveryCard extends StatelessWidget {
  const DeliveryCard({
    super.key,
    required this.record,
    required this.primaryLabel,
    required this.primaryValue,
    required this.statusLabel,
    this.onTap,
    this.trailing,
  });

  final DeliveryRecord record;
  final String primaryLabel;
  final String primaryValue;
  final String statusLabel;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black54, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เลขรายการสินค้า ${record.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$primaryLabel $primaryValue',
                    style: const TextStyle(fontSize: 15, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'จำนวนสินค้า ${record.amount} ชิ้น',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'สถานะ $statusLabel',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, size: 26),
          ],
        ),
      ),
    );
  }
}
