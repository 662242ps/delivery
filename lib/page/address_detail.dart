import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// หน้าเลือกตำแหน่งที่มีอยู่แล้ว
import 'package:flutter_application_4/page/pin_location.dart';

class AddressDetailPage extends StatefulWidget {
  const AddressDetailPage({
    super.key,
    required this.name,
    required this.phone,
    required this.fullAddress,
    this.lat,
    this.lng,
    this.addressDocId,
    this.fromAddressBook = false, // true = แก้ไขได้
  });

  final String name;
  final String phone;
  final String fullAddress;
  final double? lat;
  final double? lng;
  final String? addressDocId;
  final bool fromAddressBook;

  @override
  State<AddressDetailPage> createState() => _AddressDetailPageState();
}

class _AddressDetailPageState extends State<AddressDetailPage> {
  bool _isEditing = false;

  // ---- text controllers ----
  final _hno = TextEditingController();
  final _sub = TextEditingController();
  final _dist = TextEditingController();
  final _prov = TextEditingController();
  final _zip = TextEditingController();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  // ---- พิกัด ----
  LatLng? _addressPin;

  bool get _canEdit => widget.fromAddressBook == true;

  Map<String, String> _splitAddress(String s) {
    final p = s.split(',').map((e) => e.trim()).toList();
    return {
      'hno': p.isNotEmpty ? p[0] : '',
      'sub': p.length > 1 ? p[1] : '',
      'dist': p.length > 2 ? p[2] : '',
      'prov': p.length > 3 ? p[3] : '',
      'zip': p.length > 4 ? p[4] : '',
    };
  }

  String _composeAddress() =>
      '${_hno.text.trim()}, ${_sub.text.trim()}, ${_dist.text.trim()}, ${_prov.text.trim()}, ${_zip.text.trim()}';

  @override
  void initState() {
    super.initState();
    final a = _splitAddress(widget.fullAddress);
    _hno.text = a['hno']!;
    _sub.text = a['sub']!;
    _dist.text = a['dist']!;
    _prov.text = a['prov']!;
    _zip.text = a['zip']!;
    _nameCtrl = TextEditingController(text: widget.name);
    _phoneCtrl = TextEditingController(text: widget.phone);

    // ถ้าส่งพิกัดมาก็ใช้เลย
    if (widget.lat != null && widget.lng != null) {
      _addressPin = LatLng(widget.lat!, widget.lng!);
    }

    // ทางแก้ B: ถ้าไม่ส่งพิกัดมา ให้โหลดจาก Firestore ด้วย addressDocId
    _ensurePinFromFirestore();
  }

  /// โหลดพิกัดจาก Firestore หาก `_addressPin` ยังเป็น null และมี `addressDocId`
  Future<void> _ensurePinFromFirestore() async {
    if (_addressPin != null) return;
    if (widget.addressDocId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_address')
          .doc(widget.addressDocId)
          .get();
      final data = doc.data();
      final lat = (data?['lat'] as num?)?.toDouble();
      final lng = (data?['lng'] as num?)?.toDouble();
      if (lat != null && lng != null && mounted) {
        setState(() => _addressPin = LatLng(lat, lng));
      }
    } catch (_) {
      // ถ้าโหลดไม่ได้ ปล่อยเป็น null ให้ขึ้นปุ่ม + ตามเดิม
    }
  }

  @override
  void dispose() {
    _hno.dispose();
    _sub.dispose();
    _dist.dispose();
    _prov.dispose();
    _zip.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // เปิดหน้าเลือกพิกัด (เฉพาะตอนแก้ไข)
  Future<void> _openPinLocation() async {
    if (!_isEditing) return;
    final LatLng? newPin = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PinLocationPage()),
    );
    if (newPin != null) {
      setState(() => _addressPin = newPin);
    }
  }

  // บันทึก
  Future<void> _save() async {
    final addr = _composeAddress();
    try {
      if (widget.addressDocId != null) {
        final data = <String, dynamic>{'address': addr};
        if (_addressPin != null) {
          data['lat'] = _addressPin!.latitude;
          data['lng'] = _addressPin!.longitude;
        }
        await FirebaseFirestore.instance
            .collection('user_address')
            .doc(widget.addressDocId)
            .update(data);
      }
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกที่อยู่เรียบร้อย')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const headlineSize = 26.0;

    return Scaffold(
      body: SafeArea(
        child: Stack(
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
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE96356),
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
                          'รายละเอียดที่อยู่',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: headlineSize,
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

                // Card
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                14,
                                14,
                                80,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFEDEDED,
                                ).withOpacity(0.92),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _GroupBox(
                                    title: 'ที่อยู่ของคุณ',
                                    child: Column(
                                      children: [
                                        _Field(
                                          label: 'บ้านเลขที่/ซอย :',
                                          controller: _hno,
                                          readOnly: !_isEditing,
                                        ),
                                        const SizedBox(height: 10),
                                        _Field(
                                          label: 'ตำบล/แขวง :',
                                          controller: _sub,
                                          readOnly: !_isEditing,
                                        ),
                                        const SizedBox(height: 10),
                                        _Field(
                                          label: 'อำเภอ/เขต :',
                                          controller: _dist,
                                          readOnly: !_isEditing,
                                        ),
                                        const SizedBox(height: 10),
                                        _Field(
                                          label: 'จังหวัด :',
                                          controller: _prov,
                                          readOnly: !_isEditing,
                                        ),
                                        const SizedBox(height: 10),
                                        _Field(
                                          label: 'รหัสไปรษณีย์ :',
                                          controller: _zip,
                                          keyboardType: TextInputType.number,
                                          readOnly: !_isEditing,
                                        ),
                                        const SizedBox(height: 10),
                                        _Field(
                                          label: 'ชื่อ-เบอร์ :',
                                          controller: TextEditingController(
                                            text:
                                                '${_nameCtrl.text} | ${_phoneCtrl.text}',
                                          ),
                                          readOnly: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // หมุดที่อยู่
                                  _GroupBox(
                                    title: 'หมุดที่อยู่',
                                    trailing: _isEditing
                                        ? const Icon(Icons.chevron_right)
                                        : null,
                                    onHeaderTap: _isEditing
                                        ? _openPinLocation
                                        : null,
                                    child: GestureDetector(
                                      onTap: _isEditing
                                          ? _openPinLocation
                                          : null,
                                      child: Container(
                                        height: 180,
                                        margin: const EdgeInsets.only(top: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.black54,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: _addressPin == null
                                            ? const Center(
                                                child: Icon(
                                                  Icons.add,
                                                  size: 80,
                                                  color: Colors.black45,
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
                                                          '${_addressPin!.latitude.toStringAsFixed(6)},${_addressPin!.longitude.toStringAsFixed(6)}',
                                                        ),
                                                        options: MapOptions(
                                                          initialCenter:
                                                              _addressPin!,
                                                          initialZoom: 16.0,
                                                          interactionOptions:
                                                              const InteractionOptions(
                                                                flags:
                                                                    InteractiveFlag
                                                                        .none,
                                                              ),
                                                        ),
                                                        children: [
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
                                                                point:
                                                                    _addressPin!,
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
                                ],
                              ),
                            ),

                            // ปุ่มแก้ไข/บันทึก — แสดงเฉพาะมาจาก address_book
                            if (_canEdit)
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: _isEditing
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: _save,
                                            icon: const Icon(Icons.save),
                                            label: const Text('บันทึก'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFE96356,
                                              ),
                                              foregroundColor: Colors.black,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                side: BorderSide(
                                                  color: Colors.black
                                                      .withOpacity(0.35),
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              final a = _splitAddress(
                                                widget.fullAddress,
                                              );
                                              _hno.text = a['hno']!;
                                              _sub.text = a['sub']!;
                                              _dist.text = a['dist']!;
                                              _prov.text = a['prov']!;
                                              _zip.text = a['zip']!;
                                              // คืนพิกัดเดิมจาก widget
                                              if (widget.lat != null &&
                                                  widget.lng != null) {
                                                _addressPin = LatLng(
                                                  widget.lat!,
                                                  widget.lng!,
                                                );
                                              } else {
                                                _addressPin = null;
                                              }
                                              setState(
                                                () => _isEditing = false,
                                              );
                                            },
                                            icon: const Icon(Icons.close),
                                            label: const Text('ยกเลิก'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.black,
                                              side: const BorderSide(
                                                color: Colors.black,
                                                width: 1.2,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : FloatingActionButton.extended(
                                        onPressed: () =>
                                            setState(() => _isEditing = true),
                                        icon: const Icon(Icons.edit),
                                        label: const Text('แก้ไข'),
                                        backgroundColor: const Color(
                                          0xFFE96356,
                                        ),
                                        foregroundColor: Colors.black,
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
          ],
        ),
      ),
    );
  }
}

/* ---------- Widgets ย่อย ---------- */

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
    required this.controller,
    this.readOnly = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black54, width: 1.6),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: Colors.black, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}
