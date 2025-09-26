import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/register.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width.clamp(360, 560).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      // ทำให้พื้นหลัง "ไม่ขยับ" เมื่อคีย์บอร์ดขึ้น
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // BG image
          Positioned.fill(
            child: Image.asset(
              'assets/images/พื้นหลังสมัค.png',
              fit: BoxFit.cover,
            ),
          ),
          // gradient ทับให้อ่านง่าย
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

          // เนื้อหา
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                // ยกเฉพาะการ์ดขึ้นตามคีย์บอร์ด (พื้นหลังไม่ขยับ)
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
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
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 22,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'เข้าสู่ระบบ',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),

                              // เบอร์โทร
                              _CapsuleField(
                                controller: _phoneCtrl,
                                label: 'เบอร์โทร',
                                hint: 'ป้อนหมายเลขโทรศัพท์ของคุณ',
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                prefixIcon: const Icon(Icons.phone_iphone),
                                validator: (v) {
                                  final t = (v ?? '').trim();
                                  if (t.isEmpty) return 'กรอกเบอร์โทรก่อนนะ';
                                  if (!RegExp(r'^[0-9]{9,10}$').hasMatch(t)) {
                                    return 'รูปแบบเบอร์โทรไม่ถูกต้อง';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // รหัสผ่าน
                              _CapsuleField(
                                controller: _passCtrl,
                                label: 'รหัสผ่าน',
                                hint: 'ป้อนรหัสผ่านของคุณ',
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                                validator: (v) {
                                  final t = (v ?? '').trim();
                                  if (t.isEmpty) return 'กรอกรหัสผ่านก่อนนะ';
                                  if (t.length < 6)
                                    return 'รหัสผ่านอย่างน้อย 6 ตัวอักษร';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),

                              // ปุ่ม
                              Row(
                                children: [
                                  Expanded(
                                    child: _RedButton(
                                      text: 'สมัครสมาชิก',
                                      onPressed: () {
                                        FocusScope.of(
                                          context,
                                        ).unfocus(); // เก็บคีย์บอร์ด (ถ้ามี)
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const Register(), // ไปหน้าสมัครสมาชิก
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _RedButton(
                                      text: 'เข้าสู่ระบบ',
                                      onPressed: () {
                                        FocusScope.of(context).unfocus();
                                        // ตรวจฟอร์ม — ถ้าไม่ผ่านจะแสดง error ทันที
                                        if (_formKey.currentState!.validate()) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Login ด้วย ${_phoneCtrl.text} / ${'*' * _passCtrl.text.length}',
                                              ),
                                            ),
                                          );
                                          // TODO: call API ที่นี่
                                        } else {
                                          // แจ้งเตือนรวมอีกชั้น (เสริม)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'กรอกข้อมูลให้ครบถ้วนก่อนเข้าสู่ระบบ',
                                              ),
                                            ),
                                          );
                                        }
                                      },
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
          ),
        ],
      ),
    );
  }
}

/// TextField ทรงแคปซูลพร้อม label + validator
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: const BorderSide(color: Colors.black87, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: const BorderSide(color: Colors.red, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _RedButton extends StatelessWidget {
  const _RedButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE96356),
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
