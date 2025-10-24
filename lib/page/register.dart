// register.dart — อัปโหลดรูปไป Supabase Storage แล้วเก็บ public URL ไว้ใน Firestore
// เวอร์ชันไม่ใช้ sequences/unique ใน Firestore
// - สร้าง doc id เป็นเลขรันนิ่ง 1,2,3,... ด้วยทรานแซกชันที่เอกสารปลายทาง
// - บล็อกสมัครเฉพาะกรณี (phone,password) ตรงกันทั้งคู่
// - user_address และ rider_car ใช้ docId = เลขเดียวกับ user

import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/pin_location.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ========= ชื่อบัคเก็ตที่ใช้งาน =========
// ต้องมีอยู่จริงใน Supabase Storage และเปิด Public + มี RLS policy ที่ให้ anon SELECT/INSERT
const kBucketProfile = 'avatars';
const kBucketVehicle = 'avatars';

enum RegisterRole { user, rider }

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();

  RegisterRole role = RegisterRole.user;

  // ผู้ใช้ทั่วไป
  final phoneCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final addrNoCtrl = TextEditingController();
  final subdistrictCtrl = TextEditingController();
  final districtCtrl = TextEditingController();
  final provinceCtrl = TextEditingController();
  final zipcodeCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  // ไรเดอร์
  final riderPhoneCtrl = TextEditingController();
  final riderNameCtrl = TextEditingController();
  final plateCtrl = TextEditingController();
  final riderPasswordCtrl = TextEditingController();
  String? vehicleType;

  // รูปโปรไฟล์
  final ImagePicker _picker = ImagePicker();
  XFile? _profileXFile;
  File? _profileSavedFile;

  // รูปยานพาหนะ
  XFile? _vehicleXFile;
  File? _vehicleSavedFile;

  // หมุดที่อยู่
  LatLng? _addressPin;

  @override
  void dispose() {
    phoneCtrl.dispose();
    nameCtrl.dispose();
    addrNoCtrl.dispose();
    subdistrictCtrl.dispose();
    districtCtrl.dispose();
    provinceCtrl.dispose();
    zipcodeCtrl.dispose();
    passwordCtrl.dispose();

    riderPhoneCtrl.dispose();
    riderNameCtrl.dispose();
    plateCtrl.dispose();
    riderPasswordCtrl.dispose();

    _scrollCtrl.dispose();
    super.dispose();
  }

  /* -------------------- Helpers: ลำดับรันนิ่ง (ไม่ใช้ sequences) -------------------- */

  // อ่าน seq สูงสุด แล้ว "วนจองเลข" ด้วยทรานแซกชันที่เอกสารปลายทางเอง
  Future<String> _allocateNextNumericId() async {
    final db = FirebaseFirestore.instance;

    // 1) อ่าน seq สูงสุดนอกทรานแซกชัน (เร็ว)
    final top = await db
        .collection('user')
        .orderBy('seq', descending: true)
        .limit(1)
        .get();

    int candidate = 1;
    if (top.docs.isNotEmpty) {
      final v = top.docs.first.data()['seq'];
      candidate = (v is num ? v.toInt() : 0) + 1;
    }

    // 2) วนจองเลข โดยให้ทรานแซกชัน "อ่าน" doc เป้าก่อนทุกครั้ง
    while (true) {
      final ref = db.collection('user').doc(candidate.toString());
      try {
        await db.runTransaction((txn) async {
          final snap = await txn.get(ref); // ต้องอ่านเพื่อให้เกิดการตรวจชน
          if (snap.exists) {
            throw 'taken'; // มีคนจองไปแล้ว ลองเลขถัดไป
          }
          // จองด้วยการสร้างเอกสารพร้อม seq ไปก่อน (กันชน)
          txn.set(ref, {'seq': candidate});
        });
        debugPrint('[seq] reserved id=$candidate');
        return candidate.toString(); // จองสำเร็จ
      } catch (e) {
        candidate += 1; // มีชน ลองเลขถัดไป
      }
    }
  }

  /* -------------------- Helpers: กันซ้ำเฉพาะคู่ (phone,password) -------------------- */

  Future<void> _ensurePhonePasswordPairNotExists({
    required String phone,
    required String password,
  }) async {
    final dup = await FirebaseFirestore.instance
        .collection('user')
        .where('phone', isEqualTo: phone)
        .where('password', isEqualTo: password)
        .limit(1)
        .get();

    if (dup.docs.isNotEmpty) {
      throw 'มีผู้ใช้ที่ใช้เบอร์และรหัสผ่านชุดนี้อยู่แล้ว';
    }
  }

  /* -------------------- Helpers: รูปภาพ -------------------- */

  String _extFromXFileOrDefault(XFile? xf, [String def = 'jpg']) {
    final n = xf?.name.toLowerCase();
    if (n != null && n.contains('.')) return n.split('.').last;
    return def;
  }

  String _guessMimeByExt(String ext) {
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
    required String path, // เช่น 'user_profile/1.jpg'
  }) async {
    if (file == null) return null;

    try {
      final storage = Supabase.instance.client.storage;

      // ทำ path ให้สะอาด + เดา MIME
      final cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
      final ext = cleanPath.split('.').last.toLowerCase();
      final mime = _guessMimeByExt(ext);

      // ⛳️ ใช้ INSERT เท่านั้น (ไม่ UPDATE)
      // - ไม่ใช้ update()
      // - ไม่ใช้ upsert:true (กันเงื่อนไข UPDATE)
      try {
        final bytes = await file.readAsBytes();
        await storage
            .from(bucket)
            .uploadBinary(
              cleanPath,
              bytes,
              fileOptions: FileOptions(
                upsert: false, // ❌ ไม่ upsert เพื่อไม่ไปโดน UPDATE policy
                cacheControl: '3600',
                contentType: mime,
              ),
            );
      } on StorageException {
        await storage
            .from(bucket)
            .upload(
              cleanPath,
              file,
              fileOptions: FileOptions(
                upsert: false, // ❌
                cacheControl: '3600',
                contentType: mime,
              ),
            );
      }

      // บัคเก็ตคุณตั้ง Public → คืน public URL ได้เลย
      return storage.from(bucket).getPublicUrl(cleanPath);
    } on StorageException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: ${e.message}')),
      );
      return null;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')));
      return null;
    }
  }

  /* -------------------- โปรไฟล์: เลือกกล้อง/แกลฯ -------------------- */
  Future<void> _chooseProfileSource() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากแกลลอรี่'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('ถ่ายด้วยกล้อง'),
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

    _profileXFile = picked;

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
    final dest = File('${dir.path}/$fileName');
    await picked.saveTo(dest.path);
    _profileSavedFile = dest;

    if (mounted) setState(() {});
  }

  /* -------------------- ยานพาหนะ: เลือกกล้อง/แกลฯ -------------------- */
  Future<void> _chooseVehicleSource() async {
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

    _vehicleXFile = picked;

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'vehicle_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
    final dest = File('${dir.path}/$fileName');
    await picked.saveTo(dest.path);
    _vehicleSavedFile = dest;

    if (mounted) setState(() {});
  }

  /* -------------------- เปิดหน้าแผนที่เพื่อปักหมุด -------------------- */
  Future<void> _openPinLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PinLocationPage()),
    );
    if (result != null) {
      setState(() => _addressPin = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width.clamp(360, 640).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
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
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: cardWidth,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 22,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _SegmentButton(
                                      text: 'ผู้ใช้งาน',
                                      selected: role == RegisterRole.user,
                                      onTap: () => setState(
                                        () => role = RegisterRole.user,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SegmentButton(
                                      text: 'ไรเดอร์',
                                      selected: role == RegisterRole.rider,
                                      onTap: () => setState(
                                        () => role = RegisterRole.rider,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 6,
                              ),
                              child: Text(
                                role == RegisterRole.user
                                    ? 'สมัครสมาชิก\nเป็นผู้ใช้งานส่ง/รับ'
                                    : 'สมัครสมาชิก\nเป็นไรเดอร์',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                    ),
                              ),
                            ),
                            SizedBox(
                              height: size.height * 0.72,
                              child: Scrollbar(
                                controller: _scrollCtrl,
                                thumbVisibility: true,
                                thickness: 6,
                                radius: const Radius.circular(12),
                                scrollbarOrientation:
                                    ScrollbarOrientation.right,
                                child: Form(
                                  key: _formKey,
                                  child: ListView(
                                    controller: _scrollCtrl,
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      8,
                                      22,
                                      22,
                                    ),
                                    children: [
                                      _ProfileAvatar(
                                        label: 'รูปโปรไฟล์',
                                        imageFile:
                                            _profileSavedFile ??
                                            (_profileXFile != null
                                                ? File(_profileXFile!.path)
                                                : null),
                                        onTap: _chooseProfileSource,
                                      ),
                                      const SizedBox(height: 8),
                                      if (role == RegisterRole.user)
                                        ..._userFields(context)
                                      else
                                        ..._riderFields(context),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _RedButton(
                                              text: role == RegisterRole.user
                                                  ? 'กลับ'
                                                  : 'ยกเลิก',
                                              background: const Color(
                                                0xFFE96356,
                                              ).withOpacity(0.9),
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).maybePop(),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _RedButton(
                                              text: 'สมัครสมาชิก',
                                              onPressed: _submit,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
    );
  }

  List<Widget> _userFields(BuildContext context) {
    return [
      _CapsuleField(
        controller: phoneCtrl,
        label: 'เบอร์โทร',
        hint: 'ป้อนหมายเลขโทรศัพท์ของคุณ',
        keyboardType: TextInputType.phone,
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return 'กรอกเบอร์โทร';
          if (!RegExp(r'^[0-9]{9,10}$').hasMatch(t))
            return 'รูปแบบเบอร์ไม่ถูกต้อง';
          return null;
        },
      ),
      const SizedBox(height: 12),
      _CapsuleField(
        controller: nameCtrl,
        label: 'ชื่อ - นามสกุล',
        hint: 'ป้อนชื่อ-นามสกุลของคุณ',
        validator: (v) => (v ?? '').trim().isEmpty ? 'กรอกชื่อ-นามสกุล' : null,
      ),
      const SizedBox(height: 14),
      _GroupBox(
        title: 'ที่อยู่ของคุณ',
        child: Column(
          children: [
            _CapsuleField(
              controller: addrNoCtrl,
              label: 'บ้านเลขที่/หมู่',
              hint: 'ป้อนเลขที่และเลขหมู่บ้าน',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'กรอกบ้านเลขที่/หมู่' : null,
            ),
            const SizedBox(height: 12),
            _CapsuleField(
              controller: subdistrictCtrl,
              label: 'ตำบล/แขวง',
              hint: 'ป้อนชื่อตำบลหรือแขวงของคุณ',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'กรอกตำบล/แขวง' : null,
            ),
            const SizedBox(height: 12),
            _CapsuleField(
              controller: districtCtrl,
              label: 'อำเภอ/เขต',
              hint: 'ป้อนชื่ออำเภอหรือเขตของคุณ',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'กรอกอำเภอ/เขต' : null,
            ),
            const SizedBox(height: 12),
            _CapsuleField(
              controller: provinceCtrl,
              label: 'จังหวัด',
              hint: 'ป้อนชื่อจังหวัดของคุณ',
              validator: (v) => (v ?? '').trim().isEmpty ? 'กรอกจังหวัด' : null,
            ),
            const SizedBox(height: 12),
            _CapsuleField(
              controller: zipcodeCtrl,
              label: 'รหัสไปรษณีย์',
              hint: 'ป้อนรหัสไปรษณีย์ที่อยู่คุณ',
              keyboardType: TextInputType.number,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'กรอกรหัสไปรษณีย์';
                if (!RegExp(r'^[0-9]{5}$').hasMatch(t))
                  return 'ต้องเป็น 5 หลัก';
                return null;
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _GroupBox(
        title: 'หมุดที่อยู่',
        trailing: const Icon(Icons.chevron_right),
        onHeaderTap: _openPinLocation,
        child: GestureDetector(
          onTap: _openPinLocation,
          child: Container(
            height: 180,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black54, width: 1.2),
            ),
            child: _addressPin == null
                ? const Center(
                    child: Icon(Icons.add, size: 80, color: Colors.black45),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          ignoring: true,
                          child: FlutterMap(
                            key: ValueKey(
                              '${_addressPin!.latitude.toStringAsFixed(6)},${_addressPin!.longitude.toStringAsFixed(6)}',
                            ),
                            options: MapOptions(
                              initialCenter: _addressPin!,
                              initialZoom: 16.0,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png?apikey=2b365b3e7fb44e1dbf1b700f6327e98a',
                                subdomains: const ['a', 'b', 'c'],
                                userAgentPackageName: 'com.example.app',
                              ),
                              MarkerLayer(
                                rotate: false,
                                markers: [
                                  Marker(
                                    point: _addressPin!,
                                    width: 60,
                                    height: 60,
                                    alignment: Alignment.bottomCenter,
                                    child: Transform.translate(
                                      offset: const Offset(0, -45),
                                      child: const Icon(
                                        Icons.location_on,
                                        size: 44,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
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
      const SizedBox(height: 16),
      _CapsuleField(
        controller: passwordCtrl,
        label: 'รหัสผ่าน',
        hint: 'ป้อนรหัสผ่านของคุณ',
        obscureText: true,
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return 'กรอกรหัสผ่าน';
          if (t.length < 6) return 'อย่างน้อย 6 ตัวอักษร';
          return null;
        },
      ),
    ];
  }

  List<Widget> _riderFields(BuildContext context) {
    return [
      _CapsuleField(
        controller: riderPhoneCtrl,
        label: 'เบอร์โทร',
        hint: 'ป้อนหมายเลขโทรศัพท์ของคุณ',
        keyboardType: TextInputType.phone,
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return 'กรอกเบอร์โทร';
          if (!RegExp(r'^[0-9]{9,10}$').hasMatch(t))
            return 'รูปแบบเบอร์ไม่ถูกต้อง';
          return null;
        },
      ),
      const SizedBox(height: 12),
      _CapsuleField(
        controller: riderNameCtrl,
        label: 'ชื่อ - นามสกุล',
        hint: 'ป้อนชื่อ-นามสกุลของคุณ',
        validator: (v) => (v ?? '').trim().isEmpty ? 'กรอกชื่อ-นามสกุล' : null,
      ),
      const SizedBox(height: 14),
      Text(
        'รูปยานพาหนะ',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      _VehicleImageCard(
        imageFile:
            _vehicleSavedFile ??
            (_vehicleXFile != null ? File(_vehicleXFile!.path) : null),
        onTap: _chooseVehicleSource,
      ),
      const SizedBox(height: 14),
      _CapsuleField(
        controller: plateCtrl,
        label: 'ทะเบียนรถ',
        hint: 'ปักหมุดที่อยู่ของคุณบนแผนที่',
        validator: (v) => (v ?? '').trim().isEmpty ? 'กรอกทะเบียนรถ' : null,
      ),
      const SizedBox(height: 12),
      _DropdownCapsule<String>(
        label: 'ประเภทยานพาหนะ',
        hint: 'กดเพื่อเลือกประเภทยานพาหนะ',
        value: vehicleType,
        items: const ['มอเตอร์ไซค์', 'รถยนต์', 'จักรยานสามล้อ'],
        onChanged: (v) => setState(() => vehicleType = v),
        validator: (v) => v == null ? 'เลือกประเภทยานพาหนะ' : null,
      ),
      const SizedBox(height: 12),
      _CapsuleField(
        controller: riderPasswordCtrl,
        label: 'รหัสผ่าน',
        hint: 'ป้อนรหัสผ่านของคุณ',
        obscureText: true,
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return 'กรอกรหัสผ่าน';
          if (t.length < 6) return 'อย่างน้อย 6 ตัวอักษร';
          return null;
        },
      ),
    ];
  }

  Future<int> _getGlobalLastNo() async {
    final fs = FirebaseFirestore.instance;
    final col = fs.collection('user_address');

    final snap = await col.get(); // ไม่ใช้ orderBy/FieldPath → ไม่มี index
    var maxId = 0;
    for (final d in snap.docs) {
      final v =
          int.tryParse(d.id) ??
          0; // เอกสาร auto-ID เก่าๆ จะกลายเป็น 0 → ถูกข้าม
      if (v > maxId) maxId = v;
    }
    return maxId;
  }

  Future<void> insertWithNextNumericDocId({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) async {
    final fs = FirebaseFirestore.instance;
    final col = fs.collection(collectionPath);

    final all = await col.get();
    var maxId = 0;
    for (final d in all.docs) {
      final v = int.tryParse(d.id) ?? 0;
      if (v > maxId) maxId = v;
    }

    await fs.runTransaction((tx) async {
      var candidate = maxId + 1;
      while (true) {
        final ref = col.doc(candidate.toString());
        final snap = await tx.get(ref);
        if (!snap.exists) {
          tx.set(ref, data);
          break;
        }
        candidate++;
      }
    });
  }

  //----------------Register----------------------------
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรอกข้อมูลให้ครบถ้วนก่อนสมัครสมาชิก")),
      );
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      if (role == RegisterRole.user) {
        // =============== USER ===============
        final phone = phoneCtrl.text.trim();
        final pass = passwordCtrl.text.trim();

        // 1) บล็อกเฉพาะกรณีที่ (phone,password) ตรงกันทั้งคู่
        await _ensurePhonePasswordPairNotExists(phone: phone, password: pass);

        // 2) จองเลข (doc id) แบบรันนิ่ง 1,2,3,...
        final String newId = await _allocateNextNumericId();
        final userRef = firestore.collection('user').doc(newId);

        // 3) อัปโหลดรูปโดยใช้ชื่อไฟล์ตามเลขที่จอง
        final File? profileFile =
            _profileSavedFile ??
            (_profileXFile != null ? File(_profileXFile!.path) : null);
        final String extProfile = _extFromXFileOrDefault(_profileXFile, 'jpg');

        final profileUrl = await _uploadToSupabaseAndGetUrl(
          file: profileFile,
          bucket: kBucketProfile,
          path: 'user_profile/$newId.$extProfile',
          // bucketIsPublic: true, // หรือ false ถ้าเป็น private
        );

        // 4) เขียนข้อมูล user (merge ทับค่า seq เดิมได้เหมือนเดิม)
        await userRef.set({
          "name": nameCtrl.text.trim(),
          "phone": phone,
          "password": pass,
          "role": "user",
          "picture": profileUrl ?? "",
        }, SetOptions(merge: true));

        // 5) user_address ใช้ doc id = เลขเดียวกับ user
        final fs = FirebaseFirestore.instance;
        final col = fs.collection('user_address');

        final payload = {
          "userid": newId,
          "address":
              "${addrNoCtrl.text}, ${subdistrictCtrl.text}, "
              "${districtCtrl.text}, ${provinceCtrl.text}, ${zipcodeCtrl.text}",
          "lat": _addressPin?.latitude,
          "lng": _addressPin?.longitude,
        };

        await fs.runTransaction((tx) async {
          // เริ่มจากเลขล่าสุด + 1
          var candidate = (await _getGlobalLastNo()) + 1;

          while (true) {
            final ref = col.doc(candidate.toString()); // "1","2","3",...
            final snap = await tx.get(ref);
            if (!snap.exists) {
              tx.set(ref, payload); // จองและเขียนในจังหวะเดียว
              break;
            }
            candidate++; // ถ้าชน ขยับเลขถัดไป
          }
        });
      } else {
        // =============== RIDER ===============
        final phone = riderPhoneCtrl.text.trim();
        final pass = riderPasswordCtrl.text.trim();

        await _ensurePhonePasswordPairNotExists(phone: phone, password: pass);

        final String newId = await _allocateNextNumericId();
        final riderRef = firestore.collection('user').doc(newId);

        final File? profileFile =
            _profileSavedFile ??
            (_profileXFile != null ? File(_profileXFile!.path) : null);
        final String extRiderProfile = _extFromXFileOrDefault(
          _profileXFile,
          'jpg',
        );

        final profileUrl = await _uploadToSupabaseAndGetUrl(
          file: profileFile,
          bucket: kBucketProfile,
          path: 'user_profile/$newId.$extRiderProfile',
        );

        await riderRef.set({
          "name": riderNameCtrl.text.trim(),
          "phone": phone,
          "password": pass,
          "role": "rider",
          "picture": profileUrl ?? "",
        }, SetOptions(merge: true));

        final File? vehicleFile =
            _vehicleSavedFile ??
            (_vehicleXFile != null ? File(_vehicleXFile!.path) : null);
        final String extVehicle = _extFromXFileOrDefault(_vehicleXFile, 'jpg');

        final vehicleUrl = await _uploadToSupabaseAndGetUrl(
          file: vehicleFile,
          bucket: kBucketVehicle,
          path: 'rider_vehicle/$newId.$extVehicle',
        );

        // rider_car ใช้ docId = เลขเดียวกับ user
        await insertWithNextNumericDocId(
          collectionPath: 'rider_car',
          data: {
            "userid": newId,
            "plate_number": plateCtrl.text.trim(),
            "car_type": vehicleType,
            "image_car": vehicleUrl ?? "",
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "สมัครสมาชิกสำเร็จ (${role == RegisterRole.user ? "ผู้ใช้งาน" : "ไรเดอร์"}) ✅",
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
    }
  }
}

/* -------------------- Widgets ย่อย -------------------- */

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFE96356) : Colors.white;
    final fg = selected ? Colors.black : Colors.black87;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.black.withOpacity(0.7), width: 1.2),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.label, this.onTap, this.imageFile});
  final String label;
  final VoidCallback? onTap;
  final File? imageFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: CircleAvatar(
            radius: 44,
            backgroundColor: Colors.grey[300],
            backgroundImage: (imageFile != null) ? FileImage(imageFile!) : null,
            child: (imageFile == null)
                ? const Icon(
                    Icons.account_circle,
                    size: 84,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GroupBox extends StatelessWidget {
  const _GroupBox({
    required this.title,
    required this.child,
    this.trailing,
    this.onHeaderTap,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onHeaderTap,
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CapsuleField extends StatelessWidget {
  const _CapsuleField({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: BorderSide(
                color: Colors.black.withOpacity(0.20),
                width: 1.2,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(40)),
              borderSide: BorderSide(color: Colors.black87, width: 1.5),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(40)),
              borderSide: BorderSide(color: Colors.red, width: 1.2),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(40)),
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownCapsule<T> extends FormField<T> {
  _DropdownCapsule({
    required String label,
    required String hint,
    required List<T> items,
    T? value,
    FormFieldSetter<T>? onSaved,
    FormFieldValidator<T>? validator,
    ValueChanged<T?>? onChanged,
  }) : super(
         onSaved: onSaved,
         validator: validator,
         initialValue: value,
         builder: (state) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 label,
                 style: const TextStyle(
                   fontWeight: FontWeight.w700,
                   fontSize: 16,
                 ),
               ),
               const SizedBox(height: 8),
               InputDecorator(
                 decoration: InputDecoration(
                   filled: true,
                   fillColor: Colors.white,
                   contentPadding: const EdgeInsets.symmetric(
                     horizontal: 20,
                     vertical: 2,
                   ),
                   enabledBorder: OutlineInputBorder(
                     borderRadius: BorderRadius.circular(40),
                     borderSide: BorderSide(
                       color: Colors.black.withOpacity(0.20),
                       width: 1.2,
                     ),
                   ),
                   focusedBorder: const OutlineInputBorder(
                     borderRadius: BorderRadius.all(Radius.circular(40)),
                     borderSide: BorderSide(color: Colors.black87, width: 1.5),
                   ),
                   errorBorder: const OutlineInputBorder(
                     borderRadius: BorderRadius.all(Radius.circular(40)),
                     borderSide: BorderSide(color: Colors.red, width: 1.2),
                   ),
                   focusedErrorBorder: const OutlineInputBorder(
                     borderRadius: BorderRadius.all(Radius.circular(40)),
                     borderSide: BorderSide(color: Colors.red, width: 1.5),
                   ),
                   errorText: state.errorText,
                 ),
                 child: DropdownButtonHideUnderline(
                   child: DropdownButton<T>(
                     isExpanded: true,
                     value: state.value,
                     hint: Text(hint),
                     onChanged: (v) {
                       state.didChange(v);
                       if (onChanged != null) onChanged(v);
                     },
                     items: items
                         .map(
                           (e) =>
                               DropdownMenuItem<T>(value: e, child: Text('$e')),
                         )
                         .toList(),
                     icon: const Icon(Icons.expand_more),
                   ),
                 ),
               ),
             ],
           );
         },
       );
}

class _RedButton extends StatelessWidget {
  const _RedButton({
    required this.text,
    required this.onPressed,
    this.background = const Color(0xFFE96356),
  });
  final String text;
  final VoidCallback onPressed;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.black,
        shadowColor: Colors.black54,
        elevation: 6,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.black.withOpacity(0.35), width: 1),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}

/* -------- ยานพาหนะ: การ์ดรูป -------- */
class _VehicleImageCard extends StatelessWidget {
  const _VehicleImageCard({this.imageFile, this.onTap});
  final File? imageFile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black54, width: 1),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageFile != null) Image.file(imageFile!, fit: BoxFit.cover),
              if (imageFile == null)
                const Center(
                  child: Icon(
                    Icons.two_wheeler,
                    size: 96,
                    color: Colors.black38,
                  ),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: const Icon(Icons.camera_alt, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
