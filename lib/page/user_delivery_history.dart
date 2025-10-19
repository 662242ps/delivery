import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/user_delivery_detail.dart';
import 'package:flutter_application_4/utils/delivery_lookup.dart';
import 'package:flutter_application_4/utils/delivery_models.dart';
import 'package:flutter_application_4/widgets/delivery_stream_list.dart';
import 'package:flutter_application_4/widgets/user_footer.dart';

class UserDeliveryHistoryPage extends StatefulWidget {
  const UserDeliveryHistoryPage({super.key, required this.userId});

  final String userId;

  @override
  State<UserDeliveryHistoryPage> createState() =>
      _UserDeliveryHistoryPageState();
}

class _UserDeliveryHistoryPageState extends State<UserDeliveryHistoryPage>
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
      ? 'ค้นหาประวัติด้วยเบอร์ผู้รับ'
      : 'ค้นหาประวัติด้วยเบอร์ผู้ส่ง';

  void _openDetail(DeliveryRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserDeliveryDetailPage(
          record: record,
          lookup: _lookup,
        ),
      ),
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
                    'ประวัติการจัดส่ง',
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
                      Tab(text: 'ประวัติรายการที่ส่ง'),
                      Tab(text: 'ประวัติรายการที่รับ'),
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
                            border: Border.all(
                              color: Colors.black54,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  16,
                                  10,
                                ),
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
                                      onTap: _openDetail,
                                      filter: (record) => record.isCompleted,
                                      emptyMessage:
                                          'ยังไม่มีประวัติการจัดส่งของคุณ',
                                    ),
                                    DeliveryStreamList(
                                      stream: _streamForTab(false),
                                      lookup: _lookup,
                                      searchText: _searchCtrl.text,
                                      isSender: false,
                                      onTap: _openDetail,
                                      filter: (record) => record.isCompleted,
                                      emptyMessage:
                                          'ยังไม่มีประวัติการจัดส่งที่ส่งถึงคุณ',
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
      bottomNavigationBar: FooterNavBar(currentIndex: 3, userId: widget.userId),
    );
  }
}

