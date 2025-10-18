import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ใช้หน้าเลือกตำแหน่งที่คุณมีอยู่แล้ว
import 'package:flutter_application_4/page/pin_location.dart';

class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key, required this.userId});
  final String userId;

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  static const _brandRed = Color(0xFFE96356);

  final _formKey = GlobalKey<FormState>();

  final _hnoCtrl = TextEditingController();
  final _subCtrl = TextEditingController();
  final _distCtrl = TextEditingController();
  final _provCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();

  // พิกัดหมุด
  LatLng? _pin;

  @override
  void dispose() {
    _hnoCtrl.dispose();
    _subCtrl.dispose();
    _distCtrl.dispose();
    _provCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  String get _fullAddress =>
      '${_hnoCtrl.text.trim()}, ${_subCtrl.text.trim()}, ${_distCtrl.text.trim()}, ${_provCtrl.text.trim()}, ${_zipCtrl.text.trim()}';

  Future<void> _openPinLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PinLocationPage()),
    );
    if (result != null) {
      setState(() => _pin = result);
    }
  }

  void _clear() {
    _formKey.currentState?.reset();
    _hnoCtrl.clear();
    _subCtrl.clear();
    _distCtrl.clear();
    _provCtrl.clear();
    _zipCtrl.clear();
    setState(() => _pin = null);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรอกข้อมูลให้ครบถ้วน')));
      return;
    }
    if (_pin == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาปักหมุดที่อยู่')));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('user_address').add({
        'userid': widget.userId,
        'address': _fullAddress,
        'lat': _pin!.latitude,
        'lng': _pin!.longitude,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('เพิ่มที่อยู่เรียบร้อย ✅')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
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
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: _brandRed,
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 28,
                          color: Colors.black,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'เพิ่มที่อยู่ใหม่',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            shadows: [
                              Shadow(color: Colors.white, offset: Offset(0, 0)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // การ์ดใหญ่
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDEDED).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _GroupBox(
                                  title: 'ที่อยู่ของคุณ',
                                  child: Column(
                                    children: [
                                      _Field(
                                        label: 'บ้านเลขที่/ซอย',
                                        hint: 'ป้อนเลขที่และเลขหมู่บ้าน',
                                        controller: _hnoCtrl,
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? 'กรอกบ้านเลขที่/ซอย'
                                            : null,
                                      ),
                                      const SizedBox(height: 10),
                                      _Field(
                                        label: 'ตำบล/แขวง',
                                        hint: 'ป้อนชื่อตำบลหรือแขวงของคุณ',
                                        controller: _subCtrl,
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? 'กรอกตำบล/แขวง'
                                            : null,
                                      ),
                                      const SizedBox(height: 10),
                                      _Field(
                                        label: 'อำเภอ/เขต',
                                        hint: 'ป้อนชื่ออำเภอหรือเขตของคุณ',
                                        controller: _distCtrl,
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? 'กรอกอำเภอ/เขต'
                                            : null,
                                      ),
                                      const SizedBox(height: 10),
                                      _Field(
                                        label: 'จังหวัด',
                                        hint: 'ป้อนชื่อจังหวัดของคุณ',
                                        controller: _provCtrl,
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                            ? 'กรอกจังหวัด'
                                            : null,
                                      ),
                                      const SizedBox(height: 10),
                                      _Field(
                                        label: 'รหัสไปรษณีย์',
                                        hint: 'ป้อนรหัสไปรษณีย์ที่อยู่คุณ',
                                        controller: _zipCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          final t = (v ?? '').trim();
                                          if (t.isEmpty)
                                            return 'กรอกรหัสไปรษณีย์';
                                          if (!RegExp(
                                            r'^[0-9]{5}$',
                                          ).hasMatch(t))
                                            return 'ต้องเป็น 5 หลัก';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // หมุดที่อยู่ — คลิกเพื่อไปปักหมุด + แสดง preview
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
                                        border: Border.all(
                                          color: Colors.black54,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: _pin == null
                                          ? const Center(
                                              child: Text(
                                                'ยังไม่ได้เลือกตำแหน่ง\nกดหัวข้อหรือแตะที่บ็อกซ์เพื่อปักหมุด',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            )
                                          : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  IgnorePointer(
                                                    ignoring: true,
                                                    child: FlutterMap(
                                                      key: ValueKey(
                                                        '${_pin!.latitude.toStringAsFixed(6)},${_pin!.longitude.toStringAsFixed(6)}',
                                                      ),
                                                      options: MapOptions(
                                                        initialCenter: _pin!,
                                                        initialZoom: 16.0,
                                                        interactionOptions:
                                                            const InteractionOptions(
                                                              flags:
                                                                  InteractiveFlag
                                                                      .none,
                                                            ),
                                                      ),
                                                      children: [
                                                        // เปลี่ยนเป็น OSM ได้ถ้า api key thunderforest ใช้ไม่ได้
                                                        TileLayer(
                                                          urlTemplate:
                                                              'https://tile.thunderforest.com/cycle/{z}/{x}/{y}.png?apikey=2b365b3e7fb44e1dbf1b700f6327e98a',
                                                          subdomains: const [
                                                            'a',
                                                            'b',
                                                            'c',
                                                          ],
                                                          userAgentPackageName:
                                                              'com.example.app',
                                                        ),
                                                        MarkerLayer(
                                                          rotate: false,
                                                          markers: [
                                                            Marker(
                                                              point: _pin!,
                                                              width: 60,
                                                              height: 60,
                                                              alignment: Alignment
                                                                  .bottomCenter,
                                                              child: Transform.translate(
                                                                offset:
                                                                    const Offset(
                                                                      0,
                                                                      -45,
                                                                    ),
                                                                child: const Icon(
                                                                  Icons
                                                                      .location_on,
                                                                  size: 44,
                                                                  color: Colors
                                                                      .red,
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
                                const SizedBox(height: 20),

                                // ปุ่มล้าง/เพิ่ม
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _clear,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _brandRed,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
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
                                          elevation: 6,
                                          shadowColor: Colors.black45,
                                        ),
                                        child: const Text(
                                          'ล้างข้อมูล',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _brandRed,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
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
                                          elevation: 6,
                                          shadowColor: Colors.black45,
                                        ),
                                        child: const Text(
                                          'เพิ่มที่อยู่',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
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
          ],
        ),
      ),
    );
  }
}

/* -------------------- Widgets ย่อย -------------------- */

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
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black87, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onHeaderTap,
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.black,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: Colors.black54, width: 1.4),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(28)),
                borderSide: BorderSide(color: Colors.black, width: 1.6),
              ),
              errorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(28)),
                borderSide: BorderSide(color: Colors.red, width: 1.4),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(28)),
                borderSide: BorderSide(color: Colors.red, width: 1.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
