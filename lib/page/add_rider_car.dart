// add_rider_car.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddRiderCarPage extends StatefulWidget {
  final String userId;
  const AddRiderCarPage({super.key, required this.userId});

  @override
  State<AddRiderCarPage> createState() => _AddRiderCarPageState();
}

class _AddRiderCarPageState extends State<AddRiderCarPage> {
  static const _brandRed = Color(0xFFE96356);
  static const _bucket = 'avatars'; // ใช้บัคเก็ต avatars

  final _form = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  final _plateCtrl = TextEditingController();
  String? _vehicleType;

  final _picker = ImagePicker();
  XFile? _picked;
  File? _savedFile;

  bool _saving = false;

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  /* ---------- เลือกรูป: กล้อง/แกลเลอรี + เซฟลง sandbox แอป ---------- */
  Future<void> _pickImage() async {
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

    _picked = picked;
    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'vehicle_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
    final dest = File('${dir.path}/$filename');
    await picked.saveTo(dest.path);
    _savedFile = dest;
    if (mounted) setState(() {});
  }

  /* ---------- เดา MIME จากนามสกุล ---------- */
  String _guessMime(String ext) {
    final e = ext.toLowerCase();
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'png') return 'image/png';
    if (e == 'webp') return 'image/webp';
    if (e == 'gif') return 'image/gif';
    return 'application/octet-stream';
  }

  /* ---------- อัปโหลดรูปขึ้น Supabase แล้วคืน public URL ---------- */
  Future<String?> _uploadVehicleAndGetUrl({
    required File file,
    required String docId,
  }) async {
    final client = Supabase.instance.client;
    final storage = client.storage;

    final path = 'rider_vehicle/$docId.jpg'; // เก็บเป็น .jpg
    final ext = path.split('.').last;
    final mime = _guessMime(ext);

    try {
      final bytes = await file.readAsBytes();
      await storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              cacheControl: '3600',
              contentType: mime,
            ),
          );
    } on StorageException {
      await storage
          .from(_bucket)
          .upload(
            path,
            file,
            fileOptions: FileOptions(
              upsert: true,
              cacheControl: '3600',
              contentType: mime,
            ),
          );
    }

    return storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> _reset() async {
    _plateCtrl.clear();
    _vehicleType = null;
    _picked = null;
    _savedFile = null;
    setState(() {});
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (_savedFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เลือกรูปยานพาหนะก่อน')));
      return;
    }
    setState(() => _saving = true);

    try {
      // 1) สร้าง doc เปล่าเพื่อเอา id มาก่อน
      final docRef = _db.collection('rider_car').doc();

      // 2) อัปโหลดรูป -> URL
      final url = await _uploadVehicleAndGetUrl(
        file: _savedFile!,
        docId: docRef.id,
      );
      if (url == null) throw 'อัปโหลดรูปไม่สำเร็จ';

      // 3) บันทึกข้อมูล
      await docRef.set({
        'userid': widget.userId,
        'plate_number': _plateCtrl.text.trim(),
        'car_type': _vehicleType,
        'image_car': url,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เพิ่มยานพาหนะแล้ว')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
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
              'assets/images/พื้นหลังสมัค.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black45],
                ),
              ),
            ),
          ),

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'เพิ่มยานพาหนะใหม่',
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
                      ),
                      const SizedBox(width: 48), // balance ปุ่ม back
                    ],
                  ),
                ),

                // เนื้อหา
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.90),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.black54,
                              width: 1.6,
                            ),
                          ),
                          child: Form(
                            key: _form,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                18,
                              ),
                              children: [
                                // รูปยานพาหนะ
                                const Text(
                                  'รูปยานพาหนะ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _saving ? null : _pickImage,
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.black54,
                                          width: 1.4,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            blurRadius: 1.5,
                                            color: Colors.black12,
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (_savedFile != null)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              child: Image.file(
                                                _savedFile!,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          else
                                            const Center(
                                              child: Icon(
                                                Icons.two_wheeler,
                                                size: 96,
                                                color: Colors.black26,
                                              ),
                                            ),
                                          Positioned(
                                            right: 10,
                                            bottom: 10,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.95,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.black26,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.camera_alt,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // ทะเบียนรถ
                                const Text(
                                  'ทะเบียนรถ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _plateCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'ป้อนทะเบียนรถ',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(40),
                                      borderSide: BorderSide(
                                        color: Colors.black.withOpacity(0.20),
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(40),
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.black87,
                                        width: 1.5,
                                      ),
                                    ),
                                    errorBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(40),
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.red,
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedErrorBorder:
                                        const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(40),
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 1.5,
                                          ),
                                        ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'กรอกทะเบียนรถ'
                                      : null,
                                ),
                                const SizedBox(height: 16),

                                // ประเภทยานพาหนะ
                                const Text(
                                  'ประเภทยานพาหนะ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _vehicleType,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'มอเตอร์ไซค์',
                                      child: Text('มอเตอร์ไซค์'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'รถยนต์',
                                      child: Text('รถยนต์'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'จักรยานสามล้อ',
                                      child: Text('จักรยานสามล้อ'),
                                    ),
                                  ],
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(() => _vehicleType = v),
                                  decoration: InputDecoration(
                                    hintText: 'กดเพื่อเลือกประเภทยานพาหนะ',
                                    filled: true,
                                    fillColor: Colors.white,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 6,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(40),
                                      borderSide: BorderSide(
                                        color: Colors.black.withOpacity(0.20),
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(40),
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.black87,
                                        width: 1.5,
                                      ),
                                    ),
                                    errorBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(40),
                                      ),
                                      borderSide: BorderSide(
                                        color: Colors.red,
                                        width: 1.2,
                                      ),
                                    ),
                                    focusedErrorBorder:
                                        const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(40),
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 1.5,
                                          ),
                                        ),
                                  ),
                                  validator: (v) =>
                                      v == null ? 'เลือกประเภทยานพาหนะ' : null,
                                ),
                                const SizedBox(height: 20),

                                // ปุ่มล่าง
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _saving ? null : _reset,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          side: const BorderSide(
                                            color: Colors.black54,
                                          ),
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: Colors.black.withOpacity(
                                                0.35,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'ล้างข้อมูล',
                                          style: TextStyle(color: Colors.black),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _saving ? null : _save,
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          backgroundColor: _brandRed,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            side: BorderSide(
                                              color: Colors.black.withOpacity(
                                                0.35,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: _saving
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Text('เพิ่ม'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
