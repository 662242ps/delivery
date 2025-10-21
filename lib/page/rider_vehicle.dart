import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_4/widgets/rider_footer.dart';
import 'package:flutter_application_4/page/add_rider_car.dart';

class RiderVehiclesPage extends StatefulWidget {
  final String userId;
  const RiderVehiclesPage({super.key, required this.userId});

  @override
  State<RiderVehiclesPage> createState() => _RiderVehiclesPageState();
}

class _RiderVehiclesPageState extends State<RiderVehiclesPage> {
  static const _brandRed = Color(0xFFE96356);
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _vehicleStream() {
    return _db
        .collection('rider_car')
        .where('userid', isEqualTo: widget.userId)
        .snapshots();
  }

  Future<void> _deleteVehicle(DocumentReference ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบยานพาหนะ'),
        content: const Text('ต้องการลบรายการนี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลบสำเร็จ')));
    }
  }

  Future<void> _goAddVehicle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddRiderCarPage(userId: widget.userId)),
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
                // ===== Header: Title กลาง, ปุ่มเพิ่มชิดขวา =====
                Container(
                  decoration: const BoxDecoration(
                    color: _brandRed,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(
                          child: Text(
                            'ยานพาหนะ',
                            style: TextStyle(
                              fontSize: 24,
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
                        Positioned(
                          right: 0,
                          child: TextButton(
                            onPressed: _goAddVehicle,
                            child: const Text(
                              'เพิ่มยานพาหนะ',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ===== กล่องโปร่งใส + รายการรถ =====
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.78),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.black, width: 1.8),
                          ),
                          child:
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: _vehicleStream(),
                                builder: (context, snap) {
                                  if (snap.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snap.hasError) {
                                    return Center(
                                      child: Text(
                                        'เกิดข้อผิดพลาด: ${snap.error}',
                                      ),
                                    );
                                  }

                                  final docs = (snap.data?.docs ?? []).toList()
                                    ..sort((a, b) {
                                      final aTs =
                                          (a.data()['created_at'] as Timestamp?)
                                              ?.millisecondsSinceEpoch ??
                                          0;
                                      final bTs =
                                          (b.data()['created_at'] as Timestamp?)
                                              ?.millisecondsSinceEpoch ??
                                          0;
                                      return bTs.compareTo(aTs);
                                    });

                                  if (docs.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('ยังไม่มีข้อมูลยานพาหนะ'),
                                          const SizedBox(height: 10),
                                          FilledButton(
                                            onPressed: _goAddVehicle,
                                            child: const Text('เพิ่มยานพาหนะ'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      12,
                                      16,
                                    ),
                                    itemCount: docs.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, i) {
                                      final doc = docs[i];
                                      final d = doc.data();
                                      final imageUrl = (d['image_car'] ?? '')
                                          .toString();
                                      final carType = (d['car_type'] ?? '-')
                                          .toString();
                                      final plate = (d['plate_number'] ?? '-')
                                          .toString();

                                      return _VehicleCard(
                                        imageUrl: imageUrl,
                                        title: 'ประเภท  $carType',
                                        subtitle: 'ป้ายทะเบียน  $plate',
                                        onDelete: () =>
                                            _deleteVehicle(doc.reference),
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
        userId: widget.userId,
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onDelete,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black54, width: 1.2),
        boxShadow: const [BoxShadow(blurRadius: 0.5, color: Colors.black12)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 70,
              height: 52,
              color: Colors.white,
              child: imageUrl.isEmpty
                  ? const Icon(Icons.directions_bike)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.25),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'ลบยานพาหนะ',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
