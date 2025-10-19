import 'package:flutter/material.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';

class UserDeliveryDetailPage extends StatefulWidget {
  const UserDeliveryDetailPage({
    super.key,
    required this.record,
    this.lookup,
  });

  final DeliveryRecord record;
  final DeliveryLookupCache? lookup;

  @override
  State<UserDeliveryDetailPage> createState() => _UserDeliveryDetailPageState();
}

class _UserDeliveryDetailPageState extends State<UserDeliveryDetailPage> {
  static const _brandRed = Color(0xFFE96356);

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
    final receiverAddrFuture =
        _lookup.getAddress(widget.record.receiverAddressId);

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
                  colors: [Colors.transparent, Colors.black38],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: _brandRed,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'รายละเอียดสินค้า',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            shadows: [
                              Shadow(
                                blurRadius: 1.5,
                                offset: Offset(0.8, 0.8),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<_DeliveryDetailBundle>(
                    future: _detailFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'ไม่สามารถโหลดรายละเอียดได้\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }

                      final bundle = snapshot.data ?? const _DeliveryDetailBundle();
                      final pictures = [
                        if ((record.pictureStatus1 ?? '').isNotEmpty)
                          record.pictureStatus1!,
                      ];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailCard(
                              title: 'สถานะสินค้า',
                              child: Text(
                                record.status,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _DetailCard(
                              title: 'ที่อยู่ของผู้ส่ง',
                              child: _AddressSection(
                                name: bundle.sender?.name ??
                                    record.senderName ??
                                    '-',
                                phone: bundle.sender?.phone ??
                                    record.senderPhone ??
                                    '-',
                                address: bundle.senderAddress?.address,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _DetailCard(
                              title: 'ที่อยู่ของผู้รับ',
                              child: _AddressSection(
                                name: bundle.receiver?.name ??
                                    record.receiverName ??
                                    '-',
                                phone: bundle.receiver?.phone ??
                                    record.receiverPhone ??
                                    '-',
                                address: bundle.receiverAddress?.address,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _DetailCard(
                              title: 'จำนวนสินค้า',
                              child: Text(
                                '${record.amount} ชิ้น',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if ((record.detail ?? '').isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _DetailCard(
                                title: 'รายละเอียดสินค้า',
                                child: Text(
                                  record.detail!,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                            if (bundle.rider != null) ...[
                              const SizedBox(height: 14),
                              _DetailCard(
                                title: 'ไรเดอร์ที่ส่งสินค้า',
                                child: Text(
                                  bundle.rider!.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            _DetailCard(
                              title: 'รูปสินค้า',
                              child: pictures.isNotEmpty
                                  ? Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: pictures
                                          .map(
                                            (url) => ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: AspectRatio(
                                                aspectRatio: 1,
                                                child: Image.network(
                                                  url,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress == null) {
                                                      return child;
                                                    }
                                                    return Container(
                                                      color: Colors.grey.shade200,
                                                      child: const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) {
                                                    return Container(
                                                      color: Colors.grey.shade200,
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.broken_image_outlined,
                                                          size: 36,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    )
                                  : Container(
                                      height: 100,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text('ไม่มีรูปสินค้า'),
                                    ),
                            ),
                          ],
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(3, 3),
            blurRadius: 4,
          ),
        ],
      ),
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
          child,
        ],
      ),
    );
  }
}

class _AddressSection extends StatelessWidget {
  const _AddressSection({
    required this.name,
    required this.phone,
    this.address,
  });

  final String name;
  final String phone;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final addressText = address?.isNotEmpty == true ? address! : '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ชื่อ $name | เบอร์ $phone',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          addressText,
          style: const TextStyle(fontSize: 15),
        ),
      ],
    );
  }
}
