// rider_capture_photo.dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// เสริมโหมดอัปโหลดเอง
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RiderCapturePhotoPage extends StatefulWidget {
  const RiderCapturePhotoPage({
    super.key,
    required this.title,
    required this.subtitle,

    // ▼ เหลือไว้ครบ (ไม่ตัดของเก่า)
    this.userId,
    this.deliveryId,
    this.kind, // '3' หรือ '4' (ไม่ใส่ = ดีฟอลต์ไปที่ 3)
    // ▼ โหมดเสริม (ค่าเริ่มต้น false เพื่อไม่กระทบโค้ดเดิม)
    this.uploadAndUpdateFirestore = false,
    this.supabaseBucket = 'avatars', // ตั้งชื่อบัคเก็ตที่คุณใช้จริง (Public)
  });

  final String title;
  final String subtitle;

  // คงไว้เพื่อความเข้ากันได้ย้อนหลัง
  final String? userId;
  final String? deliveryId;
  final dynamic kind;

  /// ถ้า true: หน้านี้จะอัปโหลด Supabase + อัปเดต Firestore เอง แล้ว pop เป็น String (URL)
  /// ถ้า false (ค่าเดิม): หน้านี้จะ pop เป็น File ให้หน้าที่เรียกไปจัดการต่อเอง
  final bool uploadAndUpdateFirestore;

  /// ชื่อบัคเก็ต Supabase
  final String supabaseBucket;

  @override
  State<RiderCapturePhotoPage> createState() => _RiderCapturePhotoPageState();
}

class _RiderCapturePhotoPageState extends State<RiderCapturePhotoPage> {
  static const _brandRed = Color(0xFFE96356);

  final _picker = ImagePicker();
  XFile? _picked;
  bool _saving = false;

  // ——— utils เดิม + เสริม ———
  String _guessMime(String ext) {
    final e = ext.toLowerCase();
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'png') return 'image/png';
    if (e == 'webp') return 'image/webp';
    if (e == 'gif') return 'image/gif';
    return 'application/octet-stream';
  }

  String _resolveFieldName() {
    final k = widget.kind?.toString().toLowerCase() ?? '';
    if (k.contains('4')) return 'picture_status4';
    return 'picture_status3';
  }

  Future<String?> _uploadToSupabaseAndGetUrl({
    required String deliveryId,
    required XFile picked,
    required String fieldName,
  }) async {
    final client = Supabase.instance.client;
    final storage = client.storage;

    final rawExt = picked.path.split('.').last.toLowerCase();
    final ext = (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(rawExt))
        ? rawExt
        : 'jpg';
    final mime = _guessMime(ext);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final objectPath = 'deliveries/$deliveryId/${fieldName}_$ts.$ext';

    final bytes = await picked.readAsBytes();
    await storage
        .from(widget.supabaseBucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            cacheControl: '3600',
            contentType: mime,
          ),
        );
    return storage.from(widget.supabaseBucket).getPublicUrl(objectPath);
  }

  Future<void> _takePhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('ถ่ายภาพด้วยกล้อง'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกรูปจากแกลลอรี่'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (src == null) return;

    final picked = await _picker.pickImage(source: src, imageQuality: 85);
    if (picked == null) return;
    setState(() => _picked = picked);
  }

  // ✅ ฟังก์ชันเดิม: กดยืนยันแล้วส่ง File กลับ (คงไว้)
  Future<void> _returnFile() async {
    Navigator.of(context).pop<File>(File(_picked!.path));
  }

  // ✅ ฟังก์ชันเสริม: กดยืนยันแล้วอัปโหลดเอง + อัปเดต Firestore + ส่ง URL กลับ
  Future<void> _selfUploadAndUpdate() async {
    // 1) หาค่า deliveryId ให้ได้ก่อน (ใช้สิ่งที่ส่งมา, หรือ route args)
    String? deliveryId = widget.deliveryId;
    if (deliveryId == null || deliveryId.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        deliveryId = args;
      } else if (args is Map && args['deliveryId'] is String) {
        final s = (args['deliveryId'] as String).trim();
        if (s.isNotEmpty) deliveryId = s;
      }
    }

    // 2) ถ้าหาไม่ได้จริง ๆ -> ไม่ error แต่ fallback ส่ง File กลับ (โหมดเดิม)
    if (deliveryId == null || deliveryId.isEmpty) {
      // บอกผู้ใช้เบา ๆ แล้วคืน File (ไม่พัง flow)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่พบ deliveryId - จะส่งไฟล์กลับให้หน้าก่อนจัดการต่อ',
            ),
          ),
        );
      }
      await _returnFile();
      return;
    }

    // 3) อัปโหลด Supabase + อัปเดต Firestore
    final fieldName = _resolveFieldName();
    final url = await _uploadToSupabaseAndGetUrl(
      deliveryId: deliveryId,
      picked: _picked!,
      fieldName: fieldName,
    );

    if (url == null) {
      // อัปโหลดไม่สำเร็จ -> ส่งไฟล์กลับแทน
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'อัปโหลดไม่สำเร็จ - จะส่งไฟล์กลับให้หน้าก่อนจัดการต่อ',
            ),
          ),
        );
      }
      await _returnFile();
      return;
    }

    // อัปเดต Firestore
    try {
      await FirebaseFirestore.instance
          .collection('delivery')
          .doc(deliveryId)
          .update({fieldName: url, 'updated_at': FieldValue.serverTimestamp()});
    } catch (_) {
      // ถ้าอัปเดตไม่ได้ ก็ยังคงส่ง URL ให้คนเรียกไปจัดการเอง
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('อัปเดตรูป $fieldName สำเร็จ')));

    // ส่ง URL กลับ
    Navigator.of(context).pop<String>(url);
  }

  Future<void> _confirm() async {
    if (_picked == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาถ่าย/เลือกรูปก่อน')));
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);
    try {
      if (widget.uploadAndUpdateFirestore) {
        await _selfUploadAndUpdate(); // โหมดใหม่ (จะ fallback เป็นไฟล์ถ้าจำเป็น)
      } else {
        await _returnFile(); // โหมดเดิม (เข้ากับ RiderActiveDeliveryMapPage ของคุณ)
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // พื้นหลัง
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

          // เนื้อหา
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  decoration: const BoxDecoration(
                    color: _brandRed,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: _StrokeText(
                    widget.title,
                    fillColor: Colors.white,
                    strokeColor: Colors.black,
                    strokeWidth: 4,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                // กล่องโปร่ง + กันล้น
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                              width: 1.6,
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                          child: LayoutBuilder(
                            builder: (context, c) {
                              return SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: c.maxHeight - 0.01,
                                  ),
                                  child: IntrinsicHeight(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _OutlineBox(
                                          child: Text(
                                            widget.subtitle,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),

                                        Expanded(
                                          child: GestureDetector(
                                            onTap: _takePhoto,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: Colors.black,
                                                  width: 2,
                                                ),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: _picked == null
                                                  ? const _EmptyPhoto()
                                                  : Image.file(
                                                      File(_picked!.path),
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: SizedBox(
                                            width: 150,
                                            height: 54,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _brandRed,
                                                foregroundColor: Colors.black,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  side: const BorderSide(
                                                    color: Colors.black,
                                                    width: 2,
                                                  ),
                                                ),
                                                textStyle: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              onPressed: _saving
                                                  ? null
                                                  : _confirm,
                                              child: _saving
                                                  ? const SizedBox(
                                                      height: 22,
                                                      width: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Text('ยืนยัน'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
    );
  }
}

// ===== Helpers UI =====

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.camera_alt, size: 72, color: Colors.black38),
          SizedBox(height: 10),
          Text(
            'แตะเพื่อถ่ายภาพหรือเลือกรูป',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
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
