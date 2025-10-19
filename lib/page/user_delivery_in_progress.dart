import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/widgets/delivery_stream_list.dart';
import 'package:flutter_application_4/widgets/user_footer.dart';

class UserDeliveryInProgressPage extends StatefulWidget {
  const UserDeliveryInProgressPage({super.key, required this.userId});

  final String userId;

  @override
  State<UserDeliveryInProgressPage> createState() =>
      _UserDeliveryInProgressPageState();
}

class _UserDeliveryInProgressPageState extends State<UserDeliveryInProgressPage>
    with SingleTickerProviderStateMixin {
  static const _brandRed = Color(0xFFE96356);

  late final TabController _tabController;
  final _searchCtrl = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _lookup = DeliveryLookupCache();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamForTab(bool isSender) {
    final field = isSender ? 'userid_sender' : 'userid_receiver';
    return _firestore
        .collection('delivery')
        .where(field, isEqualTo: widget.userId)
        .snapshots();
  }

  String get _searchPlaceholder => _tabController.index == 0
      ? 'ค้นหารายการด้วยเบอร์ผู้รับ'
      : 'ค้นหารายการด้วยเบอร์ผู้ส่ง';

  void _openDetail(DeliveryRecord record, bool isSenderList) async {
    final otherUserFuture = _lookup.getUser(
      isSenderList ? record.receiverId : record.senderId,
    );
    final senderAddressFuture = _lookup.getAddress(record.senderAddressId);
    final receiverAddressFuture = _lookup.getAddress(record.receiverAddressId);

    final otherUser = await otherUserFuture;
    final senderAddr = await senderAddressFuture;
    final receiverAddr = await receiverAddressFuture;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รายละเอียดคำสั่ง #${record.id}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'สถานะ',
                  value: record.status,
                ),
                const SizedBox(height: 6),
                _DetailRow(
                  label: isSenderList ? 'ข้อมูลผู้รับ' : 'ข้อมูลผู้ส่ง',
                  value:
                      '${otherUser?.name ?? '-'} | ${otherUser?.phone ?? (isSenderList ? record.receiverPhone ?? '-' : record.senderPhone ?? '-')}',
                ),
                const SizedBox(height: 6),
                _DetailRow(
                  label: 'จำนวน',
                  value: '${record.amount} ชิ้น',
                ),
                const SizedBox(height: 6),
                if ((record.detail ?? '').isNotEmpty)
                  _DetailRow(label: 'รายละเอียด', value: record.detail!),
                const SizedBox(height: 12),
                const Text(
                  'ที่อยู่ผู้ส่ง',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Text(senderAddr?.address ?? '-'),
                if (senderAddr?.lat != null && senderAddr?.lng != null)
                  Text('(${senderAddr!.lat}, ${senderAddr.lng})'),
                const SizedBox(height: 10),
                const Text(
                  'ที่อยู่ผู้รับ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                Text(receiverAddr?.address ?? '-'),
                if (receiverAddr?.lat != null && receiverAddr?.lng != null)
                  Text('(${receiverAddr!.lat}, ${receiverAddr.lng})'),
                const SizedBox(height: 20),
                if (record.pictureStatus1 != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(
                              record.pictureStatus1!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return SizedBox(
                                  height: 220,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 220,
                                child: Center(child: Text('ไม่สามารถโหลดรูปได้')),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('ดูรูปประกอบสถานะ'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  child: const Text(
                    'รายการกำลังจัดส่ง',
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
                Container(
                  color: Colors.black,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: _brandRed,
                    labelColor: _brandRed,
                    unselectedLabelColor: Colors.white,
                    tabs: const [
                      Tab(text: 'รายการที่ส่ง'),
                      Tab(text: 'รายการที่รับ'),
                    ],
                  ),
                ),
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
                            border: Border.all(color: Colors.black54, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: _searchPlaceholder,
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: BorderSide(
                                        color: Colors.black.withOpacity(0.6),
                                        width: 2,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(28),
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.black,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    DeliveryStreamList(
                                      stream: _streamForTab(true),
                                      lookup: _lookup,
                                      searchText: _searchCtrl.text,
                                      isSender: true,
                                      onTap: (record) =>
                                          _openDetail(record, true),
                                      filter: (record) => record.isActive,
                                      emptyMessage:
                                          'ยังไม่มีรายการที่กำลังรอจัดส่ง',
                                    ),
                                    DeliveryStreamList(
                                      stream: _streamForTab(false),
                                      lookup: _lookup,
                                      searchText: _searchCtrl.text,
                                      isSender: false,
                                      onTap: (record) =>
                                          _openDetail(record, false),
                                      filter: (record) => record.isActive,
                                      emptyMessage:
                                          'ยังไม่มีสินค้าที่กำลังจัดส่งให้คุณ',
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      bottomNavigationBar:
          FooterNavBar(currentIndex: 1, userId: widget.userId),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label : ',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(height: 1.35),
          ),
        ),
      ],
    );
  }
}
