import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart';

class RiderVehiclePage extends StatelessWidget {
  const RiderVehiclePage({super.key, required this.userId});

  final String userId;

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
                    color: Color(0xFFE96356),
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: const Text(
                    'ยานพาหนะ',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.black54, width: 1.6),
                          ),
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('rider_car')
                                .where('userid', isEqualTo: userId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                                );
                              }
                              final docs = snapshot.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return const Center(
                                  child: Text('ยังไม่ได้ลงทะเบียนยานพาหนะ'),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final data = docs[index].data();
                                  final plate = data['plate_number']?.toString() ?? '-';
                                  final type = data['car_type']?.toString() ?? '-';
                                  final imageUrl = data['image_car']?.toString();
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.black45, width: 1.2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(18),
                                              bottomLeft: Radius.circular(18),
                                            ),
                                            image: imageUrl != null && imageUrl.isNotEmpty
                                                ? DecorationImage(
                                                    image: NetworkImage(imageUrl),
                                                    fit: BoxFit.cover,
                                                  )
                                                : const DecorationImage(
                                                    image: AssetImage('assets/images/พื้นหลังสมัค.png'),
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'ประเภท $type',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'ทะเบียน $plate',
                                                  style: const TextStyle(fontSize: 16),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
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
      bottomNavigationBar: RiderFooterNavBar(
        currentIndex: 2,
        userId: userId,
      ),
    );
  }
}
