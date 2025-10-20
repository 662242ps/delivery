import 'package:flutter/material.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/page/address_detail.dart';
// ถ้ามีหน้าโปรไฟล์ไรเดอร์อยู่แล้ว ปลดคอมเมนต์ตัว import ด้านล่าง
import 'package:flutter_application_4/page/profile_rider.dart';

class UserDeliveryDetailPage extends StatefulWidget {
  const UserDeliveryDetailPage({super.key, required this.record, this.lookup});

  final DeliveryRecord record;
  final DeliveryLookupCache? lookup;

  @override
  State<UserDeliveryDetailPage> createState() => _UserDeliveryDetailPageState();
}

class _UserDeliveryDetailPageState extends State<UserDeliveryDetailPage> {
  static const _brandRed = Color(0xFFE96356);
  static const double _photoLabelHeight = 20; // ให้ป้ายชื่อรูปสูงเท่ากัน

  late final Future<_DeliveryDetailBundle> _detailFuture;
  DeliveryLookupCache get _lookup => widget.lookup ?? DeliveryLookupCache();

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<_DeliveryDetailBundle> _loadDetail() async {
    final senderFuture = _lookup.getUser(widget.record.senderId);
    final receiverFuture = _lookup.getUser(widget.record.receiverId);
    final riderFuture = _lookup.getUser(widget.record.riderId);
    final senderAddrFuture = _lookup.getAddress(widget.record.senderAddressId);
    final receiverAddrFuture = _lookup.getAddress(
      widget.record.receiverAddressId,
    );

    final results = await Future.wait([
      senderFuture,
      receiverFuture,
      riderFuture,
      senderAddrFuture,
      receiverAddrFuture,
    ]);

    return _DeliveryDetailBundle(
      sender: results[0] as UserSummary?,
      receiver: results[1] as UserSummary?,
      rider: results[2] as UserSummary?,
      senderAddress: results[3] as AddressSummary?,
      receiverAddress: results[4] as AddressSummary?,
    );
  }

  void _openRiderDetail(UserSummary rider) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'รายละเอียดไรเดอร์',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'ชื่อ : ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Expanded(child: Text(rider.name)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'เบอร์ : ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Expanded(child: Text(rider.phone ?? '-')),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandRed,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // ✅ ส่งด้วยชื่อพารามิเตอร์ที่ถูกต้อง และซ่อนปุ่ม/ฟุตเตอร์
                        builder: (_) => ProfileRiderPage(
                          userId: rider.id,
                          hideChrome: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('ดูโปรไฟล์ไรเดอร์'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;

    return Scaffold(
      body: Stack(
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
                  colors: [Colors.transparent, Colors.black26],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ===== Top Bar =====
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
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                      ),
                      const Expanded(
                        child: Text(
                          'รายละเอียดสินค้า',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            shadows: [
                              Shadow(
                                blurRadius: 3,
                                offset: Offset(1.2, 1.2),
                                color: Colors.white,
                              ),
                              Shadow(blurRadius: 1.5, offset: Offset(0.8, 0.8)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // ===== Content =====
                Expanded(
                  child: FutureBuilder<_DeliveryDetailBundle>(
                    future: _detailFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'ไม่สามารถโหลดรายละเอียดได้',
                            style: TextStyle(fontSize: 13),
                          ),
                        );
                      }

                      final b = snapshot.data ?? const _DeliveryDetailBundle();

                      final photoSlots = <_PhotoSlot>[
                        _PhotoSlot(
                          label: 'รูปสินค้า',
                          url: record.pictureStatus1,
                        ),
                        const _PhotoSlot(label: 'รูปรับสินค้า'),
                        const _PhotoSlot(label: 'รูปส่งสินค้าแล้ว'),
                      ];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                        child: _BigCard(
                          opacity: 0.88,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StatusTile(
                                statusText: 'สถานะสินค้า : ${record.status}',
                              ),
                              const SizedBox(height: 10),

                              // === ผู้ส่ง ===
                              _SectionCard(
                                title: 'ที่อยู่ของผู้ส่ง',
                                trailingChevron: true,
                                onTap: () {
                                  final name =
                                      b.sender?.name ??
                                      record.senderName ??
                                      '-';
                                  final phone =
                                      b.sender?.phone ??
                                      record.senderPhone ??
                                      '-';
                                  final address =
                                      b.senderAddress?.address ?? '-';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddressDetailPage(
                                        name: name,
                                        phone: phone,
                                        fullAddress: address,
                                        lat: null,
                                        lng: null,
                                        addressDocId: record.senderAddressId,
                                      ),
                                    ),
                                  );
                                },
                                child: _AddressLines(
                                  name:
                                      b.sender?.name ??
                                      record.senderName ??
                                      '-',
                                  phone:
                                      b.sender?.phone ??
                                      record.senderPhone ??
                                      '-',
                                  address: b.senderAddress?.address,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // === ผู้รับ ===
                              _SectionCard(
                                title: 'ที่อยู่ของผู้รับ',
                                trailingChevron: true,
                                onTap: () {
                                  final name =
                                      b.receiver?.name ??
                                      record.receiverName ??
                                      '-';
                                  final phone =
                                      b.receiver?.phone ??
                                      record.receiverPhone ??
                                      '-';
                                  final address =
                                      b.receiverAddress?.address ?? '-';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddressDetailPage(
                                        name: name,
                                        phone: phone,
                                        fullAddress: address,
                                        lat: null,
                                        lng: null,
                                        addressDocId: record.receiverAddressId,
                                      ),
                                    ),
                                  );
                                },
                                child: _AddressLines(
                                  name:
                                      b.receiver?.name ??
                                      record.receiverName ??
                                      '-',
                                  phone:
                                      b.receiver?.phone ??
                                      record.receiverPhone ??
                                      '-',
                                  address: b.receiverAddress?.address,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // === จำนวนสินค้า ===
                              _SectionCard(
                                child: _QuantityRow(amount: record.amount),
                              ),
                              const SizedBox(height: 10),

                              // === รายละเอียดสินค้า ===
                              if ((record.detail ?? '').isNotEmpty) ...[
                                _SectionCard(
                                  title: 'รายละเอียดสินค้า',
                                  child: Text(
                                    record.detail!,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // === ไรเดอร์ที่ส่งสินค้า (กดดูรายละเอียดได้) ===
                              _SectionCard(
                                title: 'ไรเดอร์ที่ส่งสินค้า',
                                trailingChevron: b.rider != null,
                                onTap: b.rider == null
                                    ? null
                                    : () => _openRiderDetail(b.rider!),
                                child: Text(
                                  b.rider?.name ?? '-',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // === รูปภาพ ===
                              _SectionCard(
                                child: _PhotoTriplet(
                                  slots: photoSlots,
                                  labelHeight: _photoLabelHeight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

// ===== Bundle =====
class _DeliveryDetailBundle {
  const _DeliveryDetailBundle({
    this.sender,
    this.receiver,
    this.rider,
    this.senderAddress,
    this.receiverAddress,
  });

  final UserSummary? sender;
  final UserSummary? receiver;
  final UserSummary? rider;
  final AddressSummary? senderAddress;
  final AddressSummary? receiverAddress;
}

// ===== Decorations =====
BoxDecoration _boxDecoration({double opacity = 0.92}) {
  return BoxDecoration(
    color: Colors.white.withOpacity(opacity),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.black, width: 2),
    boxShadow: const [
      BoxShadow(color: Colors.black12, offset: Offset(3, 3), blurRadius: 4),
    ],
  );
}

class _BigCard extends StatelessWidget {
  const _BigCard({required this.child, this.opacity = 0.88});
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(4, 5), blurRadius: 8),
        ],
      ),
      child: child,
    );
  }
}

// ===== Widgets =====
class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.statusText});
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: _boxDecoration(),
      child: Text(
        statusText,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.title,
    this.trailingChevron = false,
    required this.child,
    this.onTap,
  });

  final String? title;
  final bool trailingChevron;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailingChevron)
                  const Icon(
                    Icons.chevron_right,
                    size: 24,
                    color: Colors.black,
                  ),
              ],
            ),
          if (title != null) const SizedBox(height: 6),
          child,
        ],
      ),
    );

    return onTap == null
        ? content
        : InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: content,
          );
  }
}

class _AddressLines extends StatelessWidget {
  const _AddressLines({required this.name, required this.phone, this.address});

  final String name;
  final String phone;
  final String? address;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ชื่อ $name | เบอร์ $phone',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(
          (address?.isNotEmpty ?? false) ? address! : '-',
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'จำนวนสินค้า : $amount',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'ชิ้น',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _PhotoSlot {
  const _PhotoSlot({required this.label, this.url});
  final String label;
  final String? url;
}

class _PhotoTriplet extends StatelessWidget {
  const _PhotoTriplet({required this.slots, required this.labelHeight});
  final List<_PhotoSlot> slots;
  final double labelHeight;

  @override
  Widget build(BuildContext context) {
    final three = (slots.length >= 3)
        ? slots.sublist(0, 3)
        : [
            ...slots,
            ...List.generate(
              3 - slots.length,
              (_) => const _PhotoSlot(label: ''),
            ),
          ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < three.length; i++) ...[
          Expanded(
            child: _PhotoItem(slot: three[i], labelHeight: labelHeight),
          ),
          if (i < three.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _PhotoItem extends StatelessWidget {
  const _PhotoItem({required this.slot, required this.labelHeight});
  final _PhotoSlot slot;
  final double labelHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: labelHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              slot.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _PhotoBox(url: slot.url),
          ),
        ),
      ],
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if ((url ?? '').isEmpty) {
      return Container(
        alignment: Alignment.center,
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.image_outlined,
          size: 28,
          color: Colors.black54,
        ),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, p) {
        if (p == null) return child;
        return Container(
          alignment: Alignment.center,
          color: Colors.grey.shade200,
          child: const CircularProgressIndicator(),
        );
      },
      errorBuilder: (context, e, s) => Container(
        alignment: Alignment.center,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined, size: 28),
      ),
    );
  }
}

// --- row แสดงข้อมูลใน bottom sheet ---
class _RiderRow extends StatelessWidget {
  const _RiderRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Text('$label : ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
