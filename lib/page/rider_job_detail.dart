// lib/page/rider_job_detail.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_status.dart';

// หน้าที่จะเรียกต่อ
import 'package:flutter_application_4/page/rider_active_delivery_map.dart';
import 'package:flutter_application_4/page/rider_capture_photo.dart';
import 'package:flutter_application_4/page/jobs.dart';
// ✅ เพิ่ม import หน้าแสดงรายละเอียดที่อยู่
import 'package:flutter_application_4/page/address_detail.dart';

class RiderJobDetailPage extends StatefulWidget {
  const RiderJobDetailPage({
    super.key,
    required this.deliveryId,
    required this.userId,
    required this.lookup,
  });

  final String deliveryId;
  final String userId;
  final DeliveryLookupCache lookup;

  @override
  State<RiderJobDetailPage> createState() => _RiderJobDetailPageState();
}

class _RiderJobDetailPageState extends State<RiderJobDetailPage> {
  static const _brandRed = Color(0xFFE96356);
  final _db = FirebaseFirestore.instance;
  bool _busy = false;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _stream =>
      _db.collection('delivery').doc(widget.deliveryId).snapshots();

  // ============ ACTIONS ============
  Future<void> _acceptJobLockOnly() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ref = _db.collection('delivery').doc(widget.deliveryId);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('ไม่พบนำสั่ง');
        final d = snap.data() as Map<String, dynamic>;
        final status = DeliveryStatus.normalize(d['status']?.toString());
        final riderId = (d['riderid'] as String?)?.trim();

        if (status != DeliveryStatus.waitingForRider) {
          throw Exception('งานนี้ไม่อยู่ในสถานะรอรับงานแล้ว');
        }
        if (riderId != null && riderId.isNotEmpty && riderId != widget.userId) {
          throw Exception('งานนี้ถูกจองโดยไรเดอร์คนอื่นแล้ว');
        }
        // ล็อกงานให้เรา แต่ยังคงสถานะ waitingForRider
        tx.update(ref, {
          'riderid': widget.userId,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RiderActiveDeliveryMapPage(
            userId: widget.userId,
            deliveryId: widget.deliveryId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goPickupMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RiderActiveDeliveryMapPage(
          userId: widget.userId,
          deliveryId: widget.deliveryId,
        ),
      ),
    );
  }

  void _goDropoffMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RiderActiveDeliveryMapPage(
          userId: widget.userId,
          deliveryId: widget.deliveryId,
        ),
      ),
    );
  }

  void _goCapturePickup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RiderCapturePhotoPage(
          title: 'ถ่ายภาพหลักฐาน',
          subtitle: 'รูปรับสินค้า',
        ),
      ),
    );
  }

  void _goCaptureDropoff() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RiderCapturePhotoPage(
          title: 'ถ่ายภาพหลักฐาน',
          subtitle: 'รูปส่งสินค้า',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snap) {
              if (!snap.hasData || !snap.data!.exists) {
                return const SizedBox.shrink();
              }
              final d = snap.data!.data()!;
              final status = DeliveryStatus.normalize(d['status']?.toString());
              final riderId = (d['riderid'] as String?)?.trim();
              final isMine = riderId == widget.userId;

              String? label;
              VoidCallback? onPressed;

              if (status == DeliveryStatus.waitingForRider &&
                  (riderId == null || riderId.isEmpty)) {
                label = 'รับงานนี้';
                onPressed = _busy ? null : _acceptJobLockOnly;
              } else if (status == DeliveryStatus.waitingForRider && isMine) {
                label = 'ไปรับสินค้า';
                onPressed = _goPickupMap;
              } else if (status == DeliveryStatus.riderAccepted && isMine) {
                label = 'ถ่ายภาพรับสินค้า';
                onPressed = _goCapturePickup;
              } else if (status == DeliveryStatus.riderPickedUp && isMine) {
                label = 'ถ่ายภาพส่งสินค้า';
                onPressed = _goCaptureDropoff;
              } else {
                label = null;
              }

              if (label == null) return const SizedBox.shrink();

              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandRed,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.black, width: 2),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: onPressed,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(label),
                    ),
                  ),
                ),
              );
            },
          ),
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
                  colors: [Colors.transparent, Colors.black38],
                ),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || !snap.data!.exists) {
                  return const Center(child: Text('ไม่พบงานนี้แล้ว'));
                }

                final d = snap.data!.data()!;
                final status = DeliveryStatus.normalize(
                  d['status']?.toString(),
                );
                final amount = d['amount'];
                final detail = (d['detail']?.toString() ?? '').trim();
                final pictureUrl = (d['picture_status1']?.toString() ?? '')
                    .trim(); // ✅ รูปสินค้า

                return Column(
                  children: [
                    // Header
                    Container(
                      decoration: const BoxDecoration(
                        color: _brandRed,
                        border: Border(
                          bottom: BorderSide(color: Colors.black, width: 3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                            ),
                          ),
                          const Expanded(
                            child: _StrokeText(
                              'รายละเอียดงาน',
                              fillColor: Colors.white,
                              strokeColor: Colors.black,
                              strokeWidth: 4,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),

                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.88),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.black54,
                                  width: 1.6,
                                ),
                              ),
                              child: FutureBuilder<_DetailData>(
                                future: _loadDetail(d),
                                builder: (context, info) {
                                  final dd = info.data;

                                  // ชื่อ/เบอร์/ที่อยู่สำหรับส่งต่อไปหน้า AddressDetail
                                  final senderName =
                                      dd?.senderName ?? d['sender_name'] ?? '-';
                                  final senderPhone =
                                      dd?.senderPhone ??
                                      d['phone_sender'] ??
                                      '-';
                                  final pickupAddr = dd?.pickup ?? '-';

                                  final receiverName =
                                      dd?.receiverName ??
                                      d['receiver_name'] ??
                                      '-';
                                  final receiverPhone =
                                      dd?.receiverPhone ??
                                      d['phone_receiver'] ??
                                      '-';
                                  final dropoffAddr = dd?.dropoff ?? '-';

                                  return CustomScrollView(
                                    slivers: [
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                          18,
                                          18,
                                          18,
                                          20,
                                        ),
                                        sliver: SliverList(
                                          delegate: SliverChildListDelegate.fixed([
                                            _OutlineBox(
                                              child: Text(
                                                'สถานะสินค้า : $status',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),

                                            // ===== การ์ดผู้ส่ง (กดดูรายละเอียดที่อยู่) =====
                                            _CardWithArrow(
                                              title: 'ที่อยู่ของผู้ส่ง',
                                              lines: [
                                                'ชื่อ $senderName | เบอร์ $senderPhone',
                                                pickupAddr,
                                              ],
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        AddressDetailPage(
                                                          name: senderName,
                                                          phone: senderPhone,
                                                          fullAddress:
                                                              pickupAddr,
                                                          lat: null,
                                                          lng: null,
                                                          addressDocId:
                                                              d['addressid_sender']
                                                                  ?.toString(),
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 14),

                                            // ===== การ์ดผู้รับ (กดดูรายละเอียดที่อยู่) =====
                                            _CardWithArrow(
                                              title: 'ที่อยู่ของผู้รับ',
                                              lines: [
                                                'ชื่อ $receiverName | เบอร์ $receiverPhone',
                                                dropoffAddr,
                                              ],
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        AddressDetailPage(
                                                          name: receiverName,
                                                          phone: receiverPhone,
                                                          fullAddress:
                                                              dropoffAddr,
                                                          lat: null,
                                                          lng: null,
                                                          addressDocId:
                                                              d['addressid_receiver']
                                                                  ?.toString(),
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 14),

                                            _OutlineBox(
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'จำนวนสินค้า : ${amount ?? '-'}',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  const Text(
                                                    'ชิ้น',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 14),

                                            const _OutlineLabel(
                                              'รายละเอียดสินค้า',
                                            ),
                                            const SizedBox(height: 8),
                                            _OutlineBox(
                                              height: 96,
                                              child: Align(
                                                alignment: Alignment.topLeft,
                                                child: Text(
                                                  detail.isEmpty
                                                      ? 'รายละเอียดสินค้า'
                                                      : detail,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(height: 14),

                                            // ✅ รูปสินค้า (picture_status1)
                                            const _OutlineLabel('รูปสินค้า'),
                                            const SizedBox(height: 8),
                                            _OutlineBox(
                                              child: AspectRatio(
                                                aspectRatio: 4 / 3,
                                                child: _PhotoBox(
                                                  url: pictureUrl,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(
                                              height: 120,
                                            ), // กันชนเหนือปุ่มล่าง
                                          ]),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<_DetailData> _loadDetail(Map<String, dynamic> d) async {
    final sender = await widget.lookup.getUser(d['userid_sender']?.toString());
    final receiver = await widget.lookup.getUser(
      d['userid_receiver']?.toString(),
    );
    final sAddr = await widget.lookup.getAddress(
      d['addressid_sender']?.toString(),
    );
    final rAddr = await widget.lookup.getAddress(
      d['addressid_receiver']?.toString(),
    );

    return _DetailData(
      senderName: (sender?.name ?? d['sender_name'] ?? '-').toString(),
      senderPhone: (sender?.phone ?? d['phone_sender'] ?? '-').toString(),
      receiverName: (receiver?.name ?? d['receiver_name'] ?? '-').toString(),
      receiverPhone: (receiver?.phone ?? d['phone_receiver'] ?? '-').toString(),
      pickup: sAddr?.address ?? '-',
      dropoff: rAddr?.address ?? '-',
    );
  }
}

// ===== UI helpers =====

class _StrokeText extends StatelessWidget {
  const _StrokeText(
    this.text, {
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.style,
  });
  final String text;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        Text(text, style: style.copyWith(color: fillColor)),
      ],
    );
  }
}

class _OutlineBox extends StatelessWidget {
  const _OutlineBox({required this.child, this.height});
  final Widget child;
  final double? height;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black45, width: 1.2),
      ),
      child: child,
    );
  }
}

class _OutlineLabel extends StatelessWidget {
  const _OutlineLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return _OutlineBox(
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

// ✅ เพิ่ม onTap & trailingChevron
class _CardWithArrow extends StatelessWidget {
  const _CardWithArrow({
    required this.title,
    required this.lines,
    this.onTap,
    this.trailingChevron = true,
  });

  final String title;
  final List<String> lines;
  final VoidCallback? onTap;
  final bool trailingChevron;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black45, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...lines.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      e,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (trailingChevron)
            const Icon(Icons.chevron_right, color: Colors.black87),
        ],
      ),
    );

    return onTap == null
        ? card
        : InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: card,
          );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: Colors.black45,
          size: 36,
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, p) =>
          p == null ? child : const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, e, s) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, size: 32),
      ),
    );
  }
}

class _DetailData {
  const _DetailData({
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
    required this.pickup,
    required this.dropoff,
  });
  final String senderName,
      senderPhone,
      receiverName,
      receiverPhone,
      pickup,
      dropoff;
}
