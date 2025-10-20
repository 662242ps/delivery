import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RiderCapturePhotoPage extends StatefulWidget {
  const RiderCapturePhotoPage({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<RiderCapturePhotoPage> createState() => _RiderCapturePhotoPageState();
}

class _RiderCapturePhotoPageState extends State<RiderCapturePhotoPage> {
  final _picker = ImagePicker();
  XFile? _picked;
  bool _saving = false;

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

    final picked = await _picker.pickImage(source: src, imageQuality: 80);
    if (picked == null) return;
    setState(() => _picked = picked);
  }

  Future<void> _confirm() async {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาถ่ายภาพประกอบสถานะก่อน')), 
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!mounted) return;
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
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.black54, width: 1.6),
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                        child: Column(
                          children: [
                            Text(
                              widget.subtitle,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: GestureDetector(
                                onTap: _takePhoto,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.black45, width: 1.4),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _picked == null
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.camera_alt,
                                                size: 64, color: Colors.black45),
                                            SizedBox(height: 12),
                                            Text('แตะเพื่อถ่ายภาพหรือเลือกรูป'),
                                          ],
                                        )
                                      : Image.file(
                                          File(_picked!.path),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE96356),
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  textStyle: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: _saving ? null : _confirm,
                                child: _saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('ยืนยัน'),
                              ),
                            ),
                          ],
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
