// send_product_page.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Firestore
import 'package:cloud_firestore/cloud_firestore.dart';

// Supabase (อัปโหลดรูป)
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

// ของโปรเจ็กต์คุณ
import 'package:flutter_application_4/widgets/user_footer.dart';
import 'package:flutter_application_4/page/select_receiver_address.dart';
import 'package:flutter_application_4/page/select_sender_address.dart';
import 'package:flutter_application_4/utils/delivery_status.dart';

const kBucketDeliveries = 'avatars'; // ต้องมีใน Supabase และเปิด public

class SendProductPage extends StatefulWidget {
  final String userId;
  const SendProductPage({super.key, required this.userId});

  @override
  State<SendProductPage> createState() => _SendProductPageState();
}

class _SendProductPageState extends State<SendProductPage> {
  static const _brandRed = Color(0xFFE96356);

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();

  // แสดงผลใน UI (ข้อความเท่านั้น ไม่บันทึกลง Firestore)
  String? _senderAddressText = 'กรุณาเลือกที่อยู่ของคุณ';
  String? _receiverAddressText;

  // ค่าที่ต้องบันทึกจริง
  // ผู้ส่ง
  String? _sndUserId; // ปกติ = widget.userId
  String? _sndPhone;
  String? _sndName;
  String? _sndAddressId;

  // ผู้รับ
  String? _rcvUserId;
  String? _rcvPhone;
  String? _rcvName;
  String? _rcvAddressId;

  // รูปสินค้า
  final _picker = ImagePicker();
  File? _productSavedFile;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sndUserId = widget.userId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  /* ================= Utils: MIME + Upload to Supabase ================= */

  String _guessMime(String ext) {
    final e = ext.toLowerCase();
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'png') return 'image/png';
    if (e == 'webp') return 'image/webp';
    if (e == 'gif') return 'image/gif';
    return 'application/octet-stream';
  }

  Future<String?> _uploadToSupabaseAndGetUrl({
    required File? file,
    required String bucket,
    required String path, // ex: deliveries/<deliveryId>/picture_status1.jpg
  }) async {
    if (file == null) return null;
    try {
      final client = Supabase.instance.client;
      final storage = client.storage;
      final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
      final ext = cleanPath.split('.').last;
      final mime = _guessMime(ext);

      // อัปแบบ binary
      try {
        final bytes = await file.readAsBytes();
        await storage
            .from(bucket)
            .uploadBinary(
              cleanPath,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                cacheControl: '3600',
                contentType: mime,
              ),
            );
      } on StorageException {
        // สำรอง: อัปด้วย File
        await storage
            .from(bucket)
            .upload(
              cleanPath,
              file,
              fileOptions: FileOptions(
                upsert: true,
                cacheControl: '3600',
                contentType: mime,
              ),
            );
      }

      return storage.from(bucket).getPublicUrl(cleanPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')));
      }
      return null;
    }
  }

  // หา docId ตัวเลขที่มากที่สุดในคอลเลกชัน (ข้ามเอกสารที่ id ไม่ใช่ตัวเลข)
  Future<int> _getMaxNumericDocId(String collectionPath) async {
    final fs = FirebaseFirestore.instance;
    final snap = await fs.collection(collectionPath).get(); // ไม่ต้องมี index
    var maxId = 0;
    for (final d in snap.docs) {
      final v = int.tryParse(d.id) ?? 0;
      if (v > maxId) maxId = v;
    }
    return maxId;
  }

  // จองเลขถัดไปแบบกันชนกัน (สร้างเอกสารเปล่า ๆ ไว้ก่อนเพื่อ "กันเลข")
  // คืนค่าเป็นเลขที่จองได้ เช่น 1,2,3,...
  Future<int> _allocateNextDeliveryId() async {
    final fs = FirebaseFirestore.instance;
    final col = fs.collection('delivery');

    final baseline = await _getMaxNumericDocId('delivery');

    return await fs.runTransaction<int>((tx) async {
      var candidate = baseline + 1;
      while (true) {
        final ref = col.doc(candidate.toString());
        final snap = await tx.get(ref);
        if (!snap.exists) {
          // กันเลขไว้ก่อนด้วยฟิลด์เล็ก ๆ (จะถูกเขียนทับทีหลัง)
          tx.set(ref, {'deliveryid': candidate});
          return candidate;
        }
        candidate++;
      }
    });
  }

  /* ================= เลือกรูป + เซฟลงโฟลเดอร์แอป ================= */
  Future<void> _pickProductImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกรูปจากแกลลอรี่'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('ถ่ายรูปด้วยกล้อง'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (src == null) return;

    final picked = await _picker.pickImage(source: src, imageQuality: 85);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'delivery_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
    final dest = File('${dir.path}/$fileName');
    await picked.saveTo(dest.path);
    setState(() => _productSavedFile = dest);
  }

  void _clear() {
    setState(() {
      _amountCtrl.clear();
      _detailCtrl.clear();
      _productSavedFile = null;
    });
  }

  /* ================= Payload (ตาม ERD ที่เหลืออยู่) ================= */
  Map<String, dynamic> _buildPayload({
    required int deliveryId,
    required String? pictureUrl,
  }) {
    return {
      'deliveryid': deliveryId, // int ตาม ER
      'userid_sender': _sndUserId ?? widget.userId,
      'userid_receiver': _rcvUserId,
      'phone_receiver': _rcvPhone, // มีใน ER
      'addressid_sender': _sndAddressId,
      'addressid_receiver': _rcvAddressId,
      'picture_status1': pictureUrl, // ของ delivery เท่านั้น
      'status': DeliveryStatus.waitingForRider, // เริ่มต้นรอไรเดอร์
      'amount': int.tryParse(_amountCtrl.text.trim()) ?? 1,
      'detail': _detailCtrl.text.trim(),
    };
  }

  /* ================= Submit ================= */
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_sndAddressId == null || _rcvAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกที่อยู่ผู้ส่งและผู้รับ')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final db = FirebaseFirestore.instance;

      // 1) จองเลขไอดีถัดไปของ collection 'delivery'
      final seq = await _allocateNextDeliveryId(); // → 1,2,3,...

      // 2) อัปโหลดรูป (ถ้ามี) โดยใช้ seq ที่จองได้
      String? pictureUrl;
      if (_productSavedFile != null) {
        final ext = _productSavedFile!.path.split('.').last.toLowerCase();
        final safeExt = (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext))
            ? ext
            : 'jpg';
        final path = 'deliveries/$seq/picture_status1_$seq.$safeExt';

        pictureUrl = await _uploadToSupabaseAndGetUrl(
          file: _productSavedFile,
          bucket: kBucketDeliveries,
          path: path,
        );
      }

      // 3) เขียนข้อมูลจริง (ทับเอกสารที่กันเลขไว้)
      final docRef = db.collection('delivery').doc(seq.toString());
      await docRef.set(
        _buildPayload(deliveryId: seq, pictureUrl: pictureUrl),
        SetOptions(merge: true), // merge: true เผื่อกันเลขไว้ก่อนหน้านี้
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('สร้างคำสั่งส่งสินค้าเรียบร้อย (#$seq)')),
      );
      _clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกล้มเหลว: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /* ================= UI ================= */
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
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: _brandRed,
                    border: const Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  child: const Text(
                    'ส่งสินค้า',
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

                // Card form
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.black, width: 1.8),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Scrollbar(
                              thickness: 6,
                              radius: const Radius.circular(12),
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  18,
                                ),
                                children: [
                                  // ผู้ส่ง
                                  _AddressBox(
                                    title: 'ที่อยู่ของคุณ',
                                    value:
                                        _senderAddressText ??
                                        'กรุณาเลือกที่อยู่ของคุณ',
                                    onTap: () async {
                                      final res =
                                          await Navigator.push<
                                            SenderPickResult
                                          >(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  SelectSenderAddressPage(
                                                    userId: widget.userId,
                                                  ),
                                            ),
                                          );
                                      if (res != null && mounted) {
                                        setState(() {
                                          _senderAddressText = res.displayText;
                                          _sndUserId = res.senderUserId;
                                          _sndPhone = res.senderPhone;
                                          _sndName = res.senderName;
                                          _sndAddressId = res.addressId;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // ผู้รับ
                                  _AddressBox(
                                    title: 'ที่อยู่ผู้รับสินค้า',
                                    value:
                                        _receiverAddressText ??
                                        'กรุณาเลือกที่อยู่ผู้รับสินค้า',
                                    isPlaceholder: _receiverAddressText == null,
                                    onTap: () async {
                                      final res =
                                          await Navigator.push<
                                            ReceiverPickResult
                                          >(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const SelectReceiverAddressPage(),
                                            ),
                                          );
                                      if (res != null && mounted) {
                                        setState(() {
                                          _receiverAddressText =
                                              res.displayText;
                                          _rcvUserId = res.receiverUserId;
                                          _rcvPhone = res.receiverPhone;
                                          _rcvName = res.receiverName;
                                          _rcvAddressId = res.addressId;
                                        });
                                      }
                                    },
                                  ),

                                  const SizedBox(height: 14),

                                  // จำนวน (amount)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'จำนวนสินค้า : ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Expanded(
                                        child: _CapsuleField(
                                          controller: _amountCtrl,
                                          hint: 'ป้อนจำนวนสินค้า',
                                          keyboardType: TextInputType.number,
                                          validator: (v) {
                                            final t = (v ?? '').trim();
                                            if (t.isEmpty) return 'กรอกจำนวน';
                                            if (int.tryParse(t) == null) {
                                              return 'ตัวเลขเท่านั้น';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'ชิ้น',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // รายละเอียด
                                  const Text(
                                    'รายละเอียดสินค้า',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _RoundedArea(
                                    child: TextFormField(
                                      controller: _detailCtrl,
                                      maxLines: 6,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'โปรดระบุรายละเอียดเพิ่มเติม(ถ้ามี)',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 14.5),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // รูปสินค้า
                                  const Text(
                                    'รูปสินค้าที่ต้องส่ง',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _pickProductImage,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                            color: Colors.black54,
                                            width: 1.3,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        height: 240,
                                        alignment: Alignment.center,
                                        child: _productSavedFile == null
                                            ? const Icon(
                                                Icons.inventory_2_outlined,
                                                size: 88,
                                                color: Colors.black38,
                                              )
                                            : Image.file(
                                                _productSavedFile!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RedButton(
                                          text: 'ล้างข้อมูล',
                                          onPressed: _saving ? null : _clear,
                                          background: _brandRed.withOpacity(
                                            0.9,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _RedButton(
                                          text: _saving
                                              ? 'กำลังส่ง...'
                                              : 'ส่งสินค้า',
                                          onPressed: _saving ? null : _submit,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
      bottomNavigationBar: FooterNavBar(currentIndex: 0, userId: widget.userId),
    );
  }
}

/* ---------------- widgets ย่อย ---------------- */

class _AddressBox extends StatelessWidget {
  const _AddressBox({
    required this.title,
    required this.value,
    required this.onTap,
    this.isPlaceholder = false,
  });

  final String title;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RoundedArea(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: isPlaceholder ? Colors.black45 : Colors.black87,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.chevron_right, size: 26),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _CapsuleField extends StatelessWidget {
  const _CapsuleField({
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14.5),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide(
            color: Colors.black.withOpacity(0.25),
            width: 1.3,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: const BorderSide(color: Colors.black87, width: 1.6),
        ),
      ),
    );
  }
}

class _RoundedArea extends StatelessWidget {
  const _RoundedArea({
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black54, width: 1.3),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _RedButton extends StatelessWidget {
  const _RedButton({
    required this.text,
    required this.onPressed,
    this.background = const Color(0xFFE96356),
  });

  final String text;
  final VoidCallback? onPressed;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: disabled ? Colors.grey.shade400 : background,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.black.withOpacity(0.35), width: 1),
        ),
        elevation: 6,
        shadowColor: Colors.black45,
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}
