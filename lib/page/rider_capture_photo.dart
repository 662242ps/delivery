import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RiderCapturePhotoPage extends StatefulWidget {
  const RiderCapturePhotoPage({
    super.key,
    required this.title,
    required this.subtitle,

    // ✅ รับแบบเก่าด้วย (ไม่บังคับ)
    this.userId,
    this.deliveryId,
    this.kind, // ใช้ dynamic ไปเลย ไม่ผูกกับ enum ใด ๆ
  });

  final String title;
  final String subtitle;

  // ✅ optional เพื่อให้โค้ดเก่าที่ยังส่งมาอยู่คอมไพล์ผ่าน
  final String? userId;
  final String? deliveryId;
  final dynamic kind;

  @override
  State<RiderCapturePhotoPage> createState() => _RiderCapturePhotoPageState();
}

class _RiderCapturePhotoPageState extends State<RiderCapturePhotoPage> {
  static const _brandRed = Color(0xFFE96356);

  final _picker = ImagePicker();
  XFile? _picked;
  bool _saving = false;

  Future<void> _takePhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: false,
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
      if (!mounted) return;
      // ส่งไฟล์กลับไปให้หน้าก่อนหน้า
      Navigator.of(context).pop(File(_picked!.path));
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

// ===== Helpers =====

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
