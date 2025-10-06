import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ✅ ใช้ฟุตเตอร์จากหน้า app_footer
import 'package:flutter_application_4/widgets/user_footer.dart';

class SendProductPage extends StatefulWidget {
  final String userId; // ✅ รับ userId จาก Login/FooterNavBar
  const SendProductPage({super.key, required this.userId});

  @override
  State<SendProductPage> createState() => _SendProductPageState();
}

class _SendProductPageState extends State<SendProductPage> {
  static const _brandRed = Color(0xFFE96356);

  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _senderAddress =
      'ชื่อ xxxxx xxxxx | เบอร์ xxxxxxxxxx\nบ้านเลขที่ xx, ซอย xxx, ถนน xxxx, ตำบล xxxxx,\nอำเภอ xxxxx, จังหวัด xxxx, รหัสไปรษณีย์ xxxxx';
  String? _receiverAddress;

  final _picker = ImagePicker();
  XFile? _productXFile;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

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
    setState(() => _productXFile = picked);
  }

  void _clear() {
    setState(() {
      _qtyCtrl.clear();
      _descCtrl.clear();
      _productXFile = null;
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_senderAddress == null || _receiverAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกที่อยู่ผู้ส่ง/ผู้รับให้ครบ')),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งคำสั่ง “ส่งสินค้า” สำเร็จ โดย userId: ${widget.userId}'),
        ),
      );
      // TODO: call API พร้อมส่ง widget.userId
    }
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
                // Header
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

                // Card ฟอร์ม
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
                                padding:
                                    const EdgeInsets.fromLTRB(14, 12, 14, 18),
                                children: [
                                  // ที่อยู่ผู้ส่ง
                                  _AddressBox(
                                    title: 'ที่อยู่ของคุณ',
                                    value: _senderAddress ??
                                        'กรุณาเลือกที่อยู่ของคุณ',
                                    onTap: () {
                                      // TODO: ไปหน้าเลือกที่อยู่ โดยใช้ widget.userId
                                    },
                                  ),
                                  const SizedBox(height: 12),

                                  // ที่อยู่ผู้รับ
                                  _AddressBox(
                                    title: 'ที่อยู่ผู้รับสินค้า',
                                    value: _receiverAddress ??
                                        'กรุณาเลือกที่อยู่ผู้รับสินค้า',
                                    isPlaceholder: _receiverAddress == null,
                                    onTap: () async {
                                      setState(
                                        () => _receiverAddress =
                                            'ชื่อ yyyyy yyyyy | เบอร์ 09xxxxxxxx\nบ้านเลขที่ 99/xx, ซอย yy, ถนน zzz, ตำบล abc,\nอำเภอ def, จังหวัด ghi, รหัสไปรษณีย์ 12345',
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 14),

                                  // จำนวนสินค้า
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
                                          controller: _qtyCtrl,
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
                                      controller: _descCtrl,
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
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        height: 240,
                                        alignment: Alignment.center,
                                        child: _productXFile == null
                                            ? const Icon(
                                                Icons.inventory_2_outlined,
                                                size: 88,
                                                color: Colors.black38,
                                              )
                                            : Image.file(
                                                File(_productXFile!.path),
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
                                          onPressed: _clear,
                                          background:
                                              _brandRed.withOpacity(0.9),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _RedButton(
                                          text: 'ส่งสินค้า',
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
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FooterNavBar(
        currentIndex: 0,
        userId: widget.userId, // ✅ ส่ง userId ต่อไป
      ),
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
  final VoidCallback onPressed;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
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
